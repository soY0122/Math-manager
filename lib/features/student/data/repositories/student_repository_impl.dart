import 'dart:async';
import '../../domain/models/student_stats.dart';
import '../../domain/models/student_detail_data.dart';
import '../../domain/repositories/student_repository.dart';
import '../../../../core/database/database.dart';
import '../../../../core/utils/student_evaluator.dart';
import 'package:hive/hive.dart';

class StudentRepositoryImpl implements StudentRepository {
  final AppDatabase db;

  StudentRepositoryImpl(this.db);

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
  Stream<List<StudentStats>> watchStudents({String? search, int? gradeFilter}) {
    return _watchMulti([db.studentsBox, db.examRecordsBox, db.attendancesBox, db.homeworksBox]).asyncMap((_) async {
      final List<StudentStats> list = [];

      final allStudents = db.studentsBox.values.toList();
      final allRecords = db.examRecordsBox.values.toList();
      final allAttendances = db.attendancesBox.values.toList();
      final allHomeworks = db.homeworksBox.values.toList();

      for (final sVal in allStudents) {
        final Map s = Map.from(sVal);
        final id = s['id'] as int;
        final name = s['name'] as String;
        final photoPath = s['photo_path'] as String?;
        final school = s['school'] as String;
        final grade = s['grade'] as int;
        final className = s['class_name'] as String;
        final parentPhone = s['parent_phone'] as String;
        final registrationDate = s['registration_date'] as String;
        final memo = s['memo'] as String?;
        final isActive = s['is_active'] as bool? ?? true;

        // Apply filters
        if (search != null && search.trim().isNotEmpty) {
          if (!name.contains(search) && !school.contains(search) && !className.contains(search)) {
            continue;
          }
        }
        if (gradeFilter != null) {
          if (grade != gradeFilter) {
            continue;
          }
        }

        // Calculate stats
        // 1. Exam scores (chronological order)
        final studentScores = allRecords
            .where((r) => r['student_id'] == id)
            .toList();
        // Sort by exam_id or exam date (we can sort by exam_id for safety)
        studentScores.sort((a, b) => (a['exam_id'] as int).compareTo(b['exam_id'] as int));
        final scoresList = studentScores.map((r) => r['score'] as int).toList();
        final double avgScore = scoresList.isNotEmpty
            ? scoresList.reduce((a, b) => a + b) / scoresList.length
            : 0.0;

        // 2. Attendance rate
        final studentAtts = allAttendances.where((a) => a['student_id'] == id).toList();
        int presentCount = 0;
        int lateCount = 0;
        for (final att in studentAtts) {
          final status = att['status'] as String;
          if (status == 'ATTENDANCE') presentCount++;
          if (status == 'LATE') lateCount++;
        }
        final double attendanceRate = studentAtts.isNotEmpty
            ? (presentCount + lateCount) / studentAtts.length
            : 1.0;

        // 3. Homework rate
        final studentHws = allHomeworks.where((h) => h['student_id'] == id).toList();
        int completedCount = 0;
        int partialCount = 0;
        for (final hw in studentHws) {
          final status = hw['status'] as String;
          if (status == 'COMPLETED') completedCount++;
          if (status == 'PARTIAL') partialCount++;
        }
        final double homeworkRate = studentHws.isNotEmpty
            ? (completedCount + (partialCount * 0.5)) / studentHws.length
            : 1.0;

        // 4. Growth indicator
        double growthRate = 0.0;
        String growthTrend = '➖';
        if (scoresList.length >= 2) {
          final latest = scoresList[scoresList.length - 1];
          final previous = scoresList[scoresList.length - 2];
          if (previous > 0) {
            growthRate = ((latest - previous) / previous) * 100;
          }
          if (latest > previous) {
            growthTrend = '📈';
          } else if (latest < previous) {
            growthTrend = '📉';
          }
        }

        list.add(StudentStats(
          id: id,
          name: name,
          photoPath: photoPath,
          school: school,
          grade: grade,
          className: className,
          parentPhone: parentPhone,
          registrationDate: registrationDate,
          memo: memo,
          isActive: isActive,
          averageScore: avgScore,
          growthRate: growthRate,
          growthTrend: growthTrend,
          attendanceRate: attendanceRate,
          homeworkCompletionRate: homeworkRate,
        ));
      }

      list.sort((a, b) {
        final gradeCompare = a.grade.compareTo(b.grade);
        if (gradeCompare != 0) return gradeCompare;
        return a.name.compareTo(b.name);
      });

      return list;
    });
  }

  @override
  Stream<StudentDetailData> watchStudentDetail(int studentId) {
    return _watchMulti([db.studentsBox, db.examRecordsBox, db.attendancesBox, db.homeworksBox, db.examsBox, db.schedulesBox])
        .asyncMap((_) async {
      final sVal = db.studentsBox.get(studentId);
      if (sVal == null) {
        throw Exception('Student not found: $studentId');
      }
      final Map s = Map.from(sVal);
      final name = s['name'] as String;
      final photoPath = s['photo_path'] as String?;
      final school = s['school'] as String;
      final grade = s['grade'] as int;
      final className = s['class_name'] as String;
      final parentPhone = s['parent_phone'] as String;
      final registrationDate = s['registration_date'] as String;
      final memo = s['memo'] as String?;
      final isActive = s['is_active'] as bool? ?? true;

      // 1. Fetch exams history
      final allExams = db.examsBox.values.toList();
      final allRecords = db.examRecordsBox.values.toList();
      final studentRecords = allRecords.where((r) => r['student_id'] == studentId).toList();
      
      final List<StudentExamLog> examLogs = [];
      for (final rec in studentRecords) {
        final examId = rec['exam_id'] as int;
        final score = rec['score'] as int;
        final exam = allExams.firstWhere((e) => e['id'] == examId, orElse: () => null);
        if (exam != null) {
          examLogs.add(StudentExamLog(
            title: exam['title'] as String,
            date: exam['date'] as String,
            score: score,
          ));
        }
      }
      examLogs.sort((a, b) => b.date.compareTo(a.date));

      // 2. Fetch attendance logs
      final allAttendances = db.attendancesBox.values.toList();
      final studentAtts = allAttendances.where((a) => a['student_id'] == studentId).toList();
      final List<StudentAttendanceLog> attendanceLogs = studentAtts.map<StudentAttendanceLog>((a) {
        return StudentAttendanceLog(
          date: a['date'] as String,
          status: a['status'] as String,
        );
      }).toList();
      attendanceLogs.sort((a, b) => b.date.compareTo(a.date));

      // 3. Fetch homework logs
      final allHomeworks = db.homeworksBox.values.toList();
      final studentHws = allHomeworks.where((h) => h['student_id'] == studentId).toList();
      final List<StudentHomeworkLog> homeworkLogs = studentHws.map<StudentHomeworkLog>((h) {
        return StudentHomeworkLog(
          title: h['title'] as String,
          date: h['date'] as String,
          status: h['status'] as String,
          memo: h['memo'] as String?,
        );
      }).toList();
      homeworkLogs.sort((a, b) => b.date.compareTo(a.date));

      // 4. Fetch counseling notes (schedules of type CONSULT)
      final allSchedules = db.schedulesBox.values.toList();
      final List<StudentConsultingLog> consultingLogs = [];
      
      for (final s in allSchedules) {
        if (s['type'] == 'CONSULT' && (s['student_id'] == studentId || s['student_id'] == null)) {
          consultingLogs.add(StudentConsultingLog(
            id: s['id'] as int?,
            title: s['title'] as String,
            date: s['date'] as String,
            memo: s['memo'] ?? '정기 상담 기록',
          ));
        }
      }
      // Also add the registration memo as the initial consulting log
      if (memo != null && memo.trim().isNotEmpty) {
        consultingLogs.add(StudentConsultingLog(
          title: '학원 등록 상담',
          date: registrationDate,
          memo: memo,
        ));
      }
      consultingLogs.sort((a, b) => b.date.compareTo(a.date));

      // 5. Generate AI Evaluation
      final scoresList = examLogs.reversed.map((e) => e.score).toList();
      
      int presentCount = 0;
      int lateCount = 0;
      for (final att in studentAtts) {
        final status = att['status'] as String;
        if (status == 'ATTENDANCE') presentCount++;
        if (status == 'LATE') lateCount++;
      }
      final double attendanceRate = studentAtts.isNotEmpty
          ? (presentCount + lateCount) / studentAtts.length
          : 1.0;

      int completedCount = 0;
      int partialCount = 0;
      for (final hw in studentHws) {
        final status = hw['status'] as String;
        if (status == 'COMPLETED') completedCount++;
        if (status == 'PARTIAL') partialCount++;
      }
      final double homeworkRate = studentHws.isNotEmpty
          ? (completedCount + (partialCount * 0.5)) / studentHws.length
          : 1.0;
      final ai = StudentEvaluator.evaluate(
        scores: scoresList,
        attendanceStatuses: attendanceLogs.reversed.map((a) => a.status).toList(),
        homeworkStatuses: homeworkLogs.reversed.map((h) => h.status).toList(),
      );

      double growthRate = 0.0;
      String growthTrend = '➖';
      if (scoresList.length >= 2) {
        final latest = scoresList[scoresList.length - 1];
        final previous = scoresList[scoresList.length - 2];
        if (previous > 0) {
          growthRate = ((latest - previous) / previous) * 100;
        }
        if (latest > previous) {
          growthTrend = '📈';
        } else if (latest < previous) {
          growthTrend = '📉';
        }
      }

      final studentStats = StudentStats(
        id: studentId,
        name: name,
        photoPath: photoPath,
        school: school,
        grade: grade,
        className: className,
        parentPhone: parentPhone,
        registrationDate: registrationDate,
        memo: memo,
        isActive: isActive,
        averageScore: scoresList.isNotEmpty ? scoresList.reduce((a, b) => a + b) / scoresList.length : 0.0,
        growthRate: growthRate,
        growthTrend: growthTrend,
        attendanceRate: attendanceRate,
        homeworkCompletionRate: homeworkRate,
      );

      return StudentDetailData(
        stats: studentStats,
        examLogs: examLogs,
        attendanceLogs: attendanceLogs,
        homeworkLogs: homeworkLogs,
        consultingLogs: consultingLogs,
        aiEvaluation: ai,
      );
    });
  }

  @override
  Future<int> addStudent({
    required String name,
    String? photoPath,
    required String school,
    required int grade,
    required String className,
    required String parentPhone,
    required String registrationDate,
    String? memo,
    required bool isActive,
  }) async {
    // Generate new ID
    final keys = db.studentsBox.keys.toList();
    final newId = keys.isNotEmpty ? (keys.cast<int>().reduce((a, b) => a > b ? a : b) + 1) : 1;

    final map = {
      'id': newId,
      'name': name,
      'photo_path': photoPath,
      'school': school,
      'grade': grade,
      'class_name': className,
      'parent_phone': parentPhone,
      'registration_date': registrationDate,
      'memo': memo,
      'is_active': isActive,
    };

    await db.studentsBox.put(newId, map);
    return newId;
  }

  @override
  Future<void> updateStudent({
    required int id,
    required String name,
    String? photoPath,
    required String school,
    required int grade,
    required String className,
    required String parentPhone,
    required String registrationDate,
    String? memo,
    required bool isActive,
  }) async {
    final map = {
      'id': id,
      'name': name,
      'photo_path': photoPath,
      'school': school,
      'grade': grade,
      'class_name': className,
      'parent_phone': parentPhone,
      'registration_date': registrationDate,
      'memo': memo,
      'is_active': isActive,
    };

    await db.studentsBox.put(id, map);
  }

  @override
  Future<void> deleteStudent(int id) async {
    await db.studentsBox.delete(id);

    // Relational safety deletes:
    // 1. Delete attendances
    final attKeys = db.attendancesBox.keys.toList();
    for (final key in attKeys) {
      if (key.toString().startsWith('${id}_')) {
        await db.attendancesBox.delete(key);
      }
    }

    // 2. Delete homeworks
    final hwKeys = db.homeworksBox.keys.toList();
    for (final key in hwKeys) {
      if (key.toString().startsWith('${id}_')) {
        await db.homeworksBox.delete(key);
      }
    }

    // 3. Delete exam records
    final erKeys = db.examRecordsBox.keys.toList();
    for (final key in erKeys) {
      if (key.toString().endsWith('_${id}')) {
        await db.examRecordsBox.delete(key);
      }
    }
  }

  @override
  Future<void> updateStudentMemo(int id, String memo) async {
    final studentMap = db.studentsBox.get(id);
    if (studentMap != null) {
      final map = Map<String, dynamic>.from(studentMap);
      map['memo'] = memo;
      await db.studentsBox.put(id, map);
    }
  }

  @override
  Future<StudentBackup> deleteStudentWithBackup(int id) async {
    final studentMap = db.studentsBox.get(id);
    if (studentMap == null) {
      throw Exception('학생을 찾을 수 없습니다.');
    }

    final attendances = db.attendancesBox.values
        .where((a) => a['student_id'] == id)
        .map((a) => Map<dynamic, dynamic>.from(a))
        .toList();

    final homeworks = db.homeworksBox.values
        .where((h) => h['student_id'] == id)
        .map((h) => Map<dynamic, dynamic>.from(h))
        .toList();

    final examRecords = db.examRecordsBox.values
        .where((e) => e['student_id'] == id)
        .map((e) => Map<dynamic, dynamic>.from(e))
        .toList();

    final backup = StudentBackup(
      student: Map<dynamic, dynamic>.from(studentMap),
      attendances: attendances,
      homeworks: homeworks,
      examRecords: examRecords,
    );

    await deleteStudent(id);
    return backup;
  }

  @override
  Future<void> restoreStudentBackup(StudentBackup backup) async {
    final id = backup.student['id'] as int;
    await db.studentsBox.put(id, backup.student);

    for (final a in backup.attendances) {
      await db.attendancesBox.put('${id}_${a['date']}', a);
    }

    for (final h in backup.homeworks) {
      await db.homeworksBox.put('${id}_${h['date']}', h);
    }

    for (final e in backup.examRecords) {
      await db.examRecordsBox.put('${e['exam_id']}_$id', e);
    }
  }
}
