class StudentStats {
  final String id;
  final String name;
  final String? photoPath;
  final String school;
  final int grade;
  final String className;
  final String parentPhone;
  final String registrationDate;
  final String? memo;
  final bool isActive;
  final double averageScore;
  final double growthRate;
  final String growthTrend; // "상승 중", "하락 중", "유지"
  final double attendanceRate;
  final double homeworkCompletionRate;

  const StudentStats({
    required this.id,
    required this.name,
    this.photoPath,
    required this.school,
    required this.grade,
    required this.className,
    required this.parentPhone,
    required this.registrationDate,
    this.memo,
    required this.isActive,
    required this.averageScore,
    required this.growthRate,
    required this.growthTrend,
    required this.attendanceRate,
    required this.homeworkCompletionRate,
  });
}
