import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/models/student_attendance_item.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../../../core/database/database.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final AppDatabase db;

  AttendanceRepositoryImpl(this.db);

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
  Stream<List<StudentAttendanceItem>> watchAttendanceForDate(String date, {int? gradeFilter}) {
    return _watchMulti([db.studentsBox, db.attendancesBox]).asyncMap((_) async {
      final List<StudentAttendanceItem> list = [];

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

        // Lookup attendance record
        final attKey = '${studentId}_$date';
        final attRecord = db.attendancesBox.get(attKey);
        
        final String status = attRecord != null ? (attRecord['status'] as String) : 'ATTENDANCE';
        final int attendanceId = attRecord != null ? 1 : 0; // Simulated indicator if record exists

        list.add(StudentAttendanceItem(
          studentId: studentId,
          studentName: studentName,
          school: school,
          grade: grade,
          className: className,
          attendanceId: attendanceId,
          date: date,
          status: status,
        ));
      }

      return list;
    });
  }

  @override
  Future<void> updateAttendanceStatus({
    required int studentId,
    required String date,
    required String status,
    int? attendanceId,
  }) async {
    final attKey = '${studentId}_$date';
    await db.attendancesBox.put(attKey, {
      'student_id': studentId,
      'date': date,
      'status': status,
    });
  }

  @override
  Future<void> markAllAsPresent(String date, {int? gradeFilter}) async {
    final allStudents = db.studentsBox.values.toList();
    var activeStudents = allStudents.where((s) => s['is_active'] == true).toList();
    if (gradeFilter != null) {
      activeStudents = activeStudents.where((s) => s['grade'] == gradeFilter).toList();
    }

    final Map<String, Map<String, dynamic>> batch = {};
    for (final s in activeStudents) {
      final studentId = s['id'] as int;
      final attKey = '${studentId}_$date';
      batch[attKey] = {
        'student_id': studentId,
        'date': date,
        'status': 'ATTENDANCE',
      };
    }

    if (batch.isNotEmpty) {
      await db.attendancesBox.putAll(batch);
    }
  }
}
