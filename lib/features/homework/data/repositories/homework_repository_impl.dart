import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/models/student_homework_item.dart';
import '../../domain/repositories/homework_repository.dart';
import '../../../../core/database/database.dart';

class HomeworkRepositoryImpl implements HomeworkRepository {
  final AppDatabase db;

  HomeworkRepositoryImpl(this.db);

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
  Stream<List<StudentHomeworkItem>> watchHomeworkForDate(String date, {int? gradeFilter}) {
    return _watchMulti([db.studentsBox, db.homeworksBox]).asyncMap((_) async {
      final List<StudentHomeworkItem> list = [];

      final allStudents = db.studentsBox.values.toList();
      var activeStudents = allStudents.where((s) => s['is_active'] == true).toList();
      if (gradeFilter != null) {
        activeStudents = activeStudents.where((s) => s['grade'] == gradeFilter).toList();
      }
      activeStudents.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      for (final s in activeStudents) {
        final studentId = s['id'] as int;
        final studentName = s['name'] as String;
        final school = s['school'] as String;
        final grade = s['grade'] as int;
        final className = s['class_name'] as String;

        // Lookup homework record
        final hwKey = '${studentId}_$date';
        final hwRecord = db.homeworksBox.get(hwKey);
        
        final String status = hwRecord != null ? (hwRecord['status'] as String) : 'INCOMPLETE';
        final String title = hwRecord != null ? (hwRecord['title'] as String) : '오늘의 과제';
        final String memo = hwRecord != null ? (hwRecord['memo'] as String? ?? '') : '';
        final int homeworkId = hwRecord != null ? 1 : 0; // Simulated indicator

        list.add(StudentHomeworkItem(
          studentId: studentId,
          studentName: studentName,
          school: school,
          grade: grade,
          className: className,
          homeworkId: homeworkId,
          title: title,
          date: date,
          status: status,
          memo: memo,
        ));
      }

      return list;
    });
  }

  @override
  Future<void> updateHomeworkStatus({
    required int studentId,
    required String date,
    required String status,
    required String title,
    String? memo,
    int? homeworkId,
  }) async {
    final hwKey = '${studentId}_$date';
    await db.homeworksBox.put(hwKey, {
      'student_id': studentId,
      'date': date,
      'status': status,
      'title': title,
      'memo': memo ?? '',
    });
  }

  @override
  Future<void> markAllAsCompleted(String date, String title, {int? gradeFilter}) async {
    final allStudents = db.studentsBox.values.toList();
    var activeStudents = allStudents.where((s) => s['is_active'] == true).toList();
    if (gradeFilter != null) {
      activeStudents = activeStudents.where((s) => s['grade'] == gradeFilter).toList();
    }

    final Map<String, Map<String, dynamic>> batch = {};
    for (final s in activeStudents) {
      final studentId = s['id'] as int;
      final hwKey = '${studentId}_$date';
      batch[hwKey] = {
        'student_id': studentId,
        'date': date,
        'status': 'COMPLETED',
        'title': title,
        'memo': '',
      };
    }

    if (batch.isNotEmpty) {
      await db.homeworksBox.putAll(batch);
    }
  }
}
