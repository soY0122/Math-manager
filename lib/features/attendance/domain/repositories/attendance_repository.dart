import '../models/student_attendance_item.dart';

abstract class AttendanceRepository {
  Stream<List<StudentAttendanceItem>> watchAttendanceForDate(String date, {int? gradeFilter});
  Future<void> updateAttendanceStatus({
    required String studentId,
    required String date,
    required String status,
    String? attendanceId,
  });
  Future<void> markAllAsPresent(String date, {int? gradeFilter});
}
