class StudentAttendanceItem {
  final int studentId;
  final String studentName;
  final String school;
  final int grade;
  final String className;
  final int? attendanceId;
  final String date; // YYYY-MM-DD
  final String status; // 'ATTENDANCE', 'LATE', 'ABSENT', 'LEAVE'

  const StudentAttendanceItem({
    required this.studentId,
    required this.studentName,
    required this.school,
    required this.grade,
    required this.className,
    this.attendanceId,
    required this.date,
    required this.status,
  });

  StudentAttendanceItem copyWith({
    int? studentId,
    String? studentName,
    String? school,
    int? grade,
    String? className,
    int? attendanceId,
    String? date,
    String? status,
  }) {
    return StudentAttendanceItem(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      school: school ?? this.school,
      grade: grade ?? this.grade,
      className: className ?? this.className,
      attendanceId: attendanceId ?? this.attendanceId,
      date: date ?? this.date,
      status: status ?? this.status,
    );
  }
}
