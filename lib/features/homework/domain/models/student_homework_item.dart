class StudentHomeworkItem {
  final String studentId;
  final String studentName;
  final String school;
  final int grade;
  final String className;
  final String? homeworkId;
  final String title;
  final String date; // YYYY-MM-DD
  final String status; // 'COMPLETED', 'PARTIAL', 'INCOMPLETE'
  final String? memo;

  const StudentHomeworkItem({
    required this.studentId,
    required this.studentName,
    required this.school,
    required this.grade,
    required this.className,
    this.homeworkId,
    required this.title,
    required this.date,
    required this.status,
    this.memo,
  });

  StudentHomeworkItem copyWith({
    String? studentId,
    String? studentName,
    String? school,
    int? grade,
    String? className,
    String? homeworkId,
    String? title,
    String? date,
    String? status,
    String? memo,
  }) {
    return StudentHomeworkItem(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      school: school ?? this.school,
      grade: grade ?? this.grade,
      className: className ?? this.className,
      homeworkId: homeworkId ?? this.homeworkId,
      title: title ?? this.title,
      date: date ?? this.date,
      status: status ?? this.status,
      memo: memo ?? this.memo,
    );
  }
}
