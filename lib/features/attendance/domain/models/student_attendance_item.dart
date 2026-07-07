class StudentAttendanceItem {
  final String studentId;
  final String studentName;
  final String school;
  final int grade;
  final String className;
  final String? attendanceId;
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
    String? studentId,
    String? studentName,
    String? school,
    int? grade,
    String? className,
    String? attendanceId,
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
