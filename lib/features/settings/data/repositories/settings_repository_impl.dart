import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/models/settings_models.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../../../core/database/database.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final AppDatabase db;

  SettingsRepositoryImpl(this.db);

  Stream<void> _watchMulti(List<Box> boxes) async* {
    yield null; // Initial trigger
    final controller = StreamController<void>();
    final subs = <StreamSubscription>[];
    for (final box in boxes) {
      subs.add(box.watch().listen((_) {
        if (!controller.isClosed) controller.add(null);
      }));
    }
    controller.onCancel = () {
      for (final s in subs) {
        s.cancel();
      }
      controller.close();
    };
    yield* controller.stream;
  }

  @override
  Stream<List<ScheduleItem>> watchSchedulesForDate(String dateStr) {
    return db.schedulesBox.watch().map((_) => _getSchedulesForDate(dateStr))
        .startWith(_getSchedulesForDate(dateStr));
  }

  List<ScheduleItem> _getSchedulesForDate(String dateStr) {
    final all = db.schedulesBox.values.toList();
    final filtered = all.where((s) => s['date'] == dateStr).toList();
    return filtered.map((s) {
      return ScheduleItem(
        id: s['id'] as int,
        title: s['title'] as String,
        date: s['date'] as String,
        type: s['type'] as String,
        memo: s['memo'] as String?,
      );
    }).toList();
  }

  @override
  Stream<List<ScheduleItem>> watchAllSchedules() {
    return db.schedulesBox.watch().map((_) => _getAllSchedules())
        .startWith(_getAllSchedules());
  }

  List<ScheduleItem> _getAllSchedules() {
    final all = db.schedulesBox.values.toList();
    all.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return all.map((s) {
      return ScheduleItem(
        id: s['id'] as int,
        title: s['title'] as String,
        date: s['date'] as String,
        type: s['type'] as String,
        memo: s['memo'] as String?,
      );
    }).toList();
  }

  @override
  Future<void> addSchedule({
    required String title,
    required String date,
    required String type,
    String? memo,
    int? studentId,
  }) async {
    final keys = db.schedulesBox.keys.toList();
    final newId = keys.isNotEmpty ? (keys.cast<int>().reduce((a, b) => a > b ? a : b) + 1) : 1;

    await db.schedulesBox.put(newId, {
      'id': newId,
      'title': title,
      'date': date,
      'type': type,
      'memo': memo,
      if (studentId != null) 'student_id': studentId,
    });
  }

  @override
  Future<void> updateSchedule({
    required int id,
    required String title,
    required String date,
    String? memo,
  }) async {
    final scheduleMap = db.schedulesBox.get(id);
    if (scheduleMap != null) {
      final map = Map<String, dynamic>.from(scheduleMap);
      map['title'] = title;
      map['date'] = date;
      map['memo'] = memo;
      await db.schedulesBox.put(id, map);
    }
  }

  @override
  Future<void> deleteSchedule(int id) async {
    await db.schedulesBox.delete(id);
  }

  @override
  Stream<AcademyStats> watchAcademyStats({int? gradeFilter}) {
    return _watchMulti([
      db.studentsBox,
      db.examRecordsBox,
      db.attendancesBox,
      db.homeworksBox,
    ]).asyncMap((_) async {
      final allStudents = db.studentsBox.values.toList();
      var activeStudents = allStudents.where((s) => s['is_active'] == true).toList();
      if (gradeFilter != null) {
        activeStudents = activeStudents.where((s) => s['grade'] == gradeFilter).toList();
      }
      final activeStudentIds = activeStudents.map((s) => s['id'] as int).toSet();

      final allRecords = db.examRecordsBox.values.toList();
      final allAttendances = db.attendancesBox.values.toList();
      final allHomeworks = db.homeworksBox.values.toList();

      // Compute student analytics
      final List<RankingItem> scoreRankings = [];
      final List<RankingItem> growthRankings = [];

      final Map<int, List<int>> studentScoresMap = {};
      for (final r in allRecords) {
        final sId = r['student_id'] as int;
        if (activeStudentIds.contains(sId)) {
          studentScoresMap.putIfAbsent(sId, () => []).add(r['score'] as int);
        }
      }

      final Map<int, List<String>> studentAttsMap = {};
      for (final a in allAttendances) {
        final sId = a['student_id'] as int;
        if (activeStudentIds.contains(sId)) {
          studentAttsMap.putIfAbsent(sId, () => []).add(a['status'] as String);
        }
      }

      final Map<int, List<String>> studentHwsMap = {};
      for (final h in allHomeworks) {
        final sId = h['student_id'] as int;
        if (activeStudentIds.contains(sId)) {
          studentHwsMap.putIfAbsent(sId, () => []).add(h['status'] as String);
        }
      }

      for (final s in activeStudents) {
        final id = s['id'] as int;
        final name = s['name'] as String;
        final grade = s['grade'] as int;
        final className = s['class_name'] as String;

        final scores = studentScoresMap[id] ?? [];
        final avgScore = scores.isNotEmpty ? scores.reduce((a, b) => a + b) / scores.length : 0.0;

        double growthRate = 0.0;
        if (scores.length >= 2) {
          final latest = scores[scores.length - 1];
          final previous = scores[scores.length - 2];
          if (previous > 0) {
            growthRate = ((latest - previous) / previous) * 100;
          }
        }

        scoreRankings.add(RankingItem(
          studentId: id,
          name: name,
          grade: grade,
          className: className,
          value: avgScore,
        ));

        growthRankings.add(RankingItem(
          studentId: id,
          name: name,
          grade: grade,
          className: className,
          value: growthRate,
        ));
      }

      // Sort rankings
      scoreRankings.sort((a, b) => b.value.compareTo(a.value));
      growthRankings.sort((a, b) => b.value.compareTo(a.value));

      // Calculate grade statistics (grades 1 to 9)
      final List<GradeStats> gradeStats = [];
      for (int grade = 1; grade <= 9; grade++) {
        final gradeStudents = activeStudents.where((s) => s['grade'] == grade).toList();
        if (gradeStudents.isEmpty) {
          continue;
        }

        double totalAvgScores = 0.0;
        double totalAttendanceRates = 0.0;
        double totalHwRates = 0.0;

        for (final student in gradeStudents) {
          final id = student['id'] as int;

          // Exam avg
          final scores = studentScoresMap[id] ?? [];
          final studentAvg = scores.isNotEmpty ? scores.reduce((a, b) => a + b) / scores.length : 0.0;
          totalAvgScores += studentAvg;

          // Attendance rate
          final atts = studentAttsMap[id] ?? [];
          int present = 0;
          int lates = 0;
          for (final st in atts) {
            if (st == 'ATTENDANCE') present++;
            if (st == 'LATE') lates++;
          }
          final attRate = atts.isNotEmpty ? (present + lates) / atts.length : 1.0;
          totalAttendanceRates += attRate;

          // Homework rate
          final hws = studentHwsMap[id] ?? [];
          int completed = 0;
          int partial = 0;
          for (final st in hws) {
            if (st == 'COMPLETED') completed++;
            if (st == 'PARTIAL') partial++;
          }
          final hwRate = hws.isNotEmpty ? (completed + (partial * 0.5)) / hws.length : 1.0;
          totalHwRates += hwRate;
        }

        gradeStats.add(GradeStats(
          grade: grade,
          averageScore: totalAvgScores / gradeStudents.length,
          attendanceRate: totalAttendanceRates / gradeStudents.length,
          homeworkRate: totalHwRates / gradeStudents.length,
        ));
      }

      return AcademyStats(
        gradeStats: gradeStats,
        scoreRankings: scoreRankings,
        growthRankings: growthRankings,
      );
    });
  }
}

extension StreamExtension<T> on Stream<T> {
  Stream<T> startWith(T initialValue) async* {
    yield initialValue;
    yield* this;
  }
}
