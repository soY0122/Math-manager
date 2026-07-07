class ScheduleItem {
  final int id;
  final String title;
  final String date; // YYYY-MM-DD
  final String type; // 'EXAM', 'LEAVE', 'CONSULT'
  final String? memo;

  const ScheduleItem({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
    this.memo,
  });
}

class GradeStats {
  final int grade; // 1 to 9
  final double averageScore;
  final double attendanceRate;
  final double homeworkRate;

  const GradeStats({
    required this.grade,
    required this.averageScore,
    required this.attendanceRate,
    required this.homeworkRate,
  });
}

class RankingItem {
  final int studentId;
  final String name;
  final int grade;
  final String className;
  final double value; // Can be average score or growth rate

  const RankingItem({
    required this.studentId,
    required this.name,
    required this.grade,
    required this.className,
    required this.value,
  });
}

class AcademyStats {
  final List<GradeStats> gradeStats;
  final List<RankingItem> scoreRankings;
  final List<RankingItem> growthRankings;

  const AcademyStats({
    required this.gradeStats,
    required this.scoreRankings,
    required this.growthRankings,
  });
}
