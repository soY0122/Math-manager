class ExamOverview {
  final String id;
  final String title;
  final String date;
  final int grade;
  final double averageScore;
  final int maxScore;
  final int minScore;
  final int studentCount;

  const ExamOverview({
    required this.id,
    required this.title,
    required this.date,
    required this.grade,
    required this.averageScore,
    required this.maxScore,
    required this.minScore,
    required this.studentCount,
  });
}

class StudentExamScoreItem {
  final String studentId;
  final String studentName;
  final String school;
  final int grade;
  final String className;
  final String? recordId;
  final int score;

  const StudentExamScoreItem({
    required this.studentId,
    required this.studentName,
    required this.school,
    required this.grade,
    required this.className,
    this.recordId,
    required this.score,
  });

  StudentExamScoreItem copyWith({
    String? studentId,
    String? studentName,
    String? school,
    int? grade,
    String? className,
    String? recordId,
    int? score,
  }) {
    return StudentExamScoreItem(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      school: school ?? this.school,
      grade: grade ?? this.grade,
      className: className ?? this.className,
      recordId: recordId ?? this.recordId,
      score: score ?? this.score,
    );
  }
}
