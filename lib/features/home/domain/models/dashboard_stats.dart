class DashboardStats {
  final int todayPresentCount;
  final int todayLateCount;
  final int todayAbsentCount;
  final int todayHomeworkIncompleteCount;
  final double monthlyAverageScore;
  final double monthlyAttendanceRate;
  final double monthlyHomeworkCompletionRate;
  final int dangerStudentCount;
  final String aiAnalysisSummary;
  final List<GrowthLeaderboardItem> growthLeaderboard;
  final List<RecentActivityItem> recentActivity;

  const DashboardStats({
    required this.todayPresentCount,
    required this.todayLateCount,
    required this.todayAbsentCount,
    required this.todayHomeworkIncompleteCount,
    required this.monthlyAverageScore,
    required this.monthlyAttendanceRate,
    required this.monthlyHomeworkCompletionRate,
    required this.dangerStudentCount,
    required this.aiAnalysisSummary,
    required this.growthLeaderboard,
    required this.recentActivity,
  });

  DashboardStats copyWith({
    int? todayPresentCount,
    int? todayLateCount,
    int? todayAbsentCount,
    int? todayHomeworkIncompleteCount,
    double? monthlyAverageScore,
    double? monthlyAttendanceRate,
    double? monthlyHomeworkCompletionRate,
    int? dangerStudentCount,
    String? aiAnalysisSummary,
    List<GrowthLeaderboardItem>? growthLeaderboard,
    List<RecentActivityItem>? recentActivity,
  }) {
    return DashboardStats(
      todayPresentCount: todayPresentCount ?? this.todayPresentCount,
      todayLateCount: todayLateCount ?? this.todayLateCount,
      todayAbsentCount: todayAbsentCount ?? this.todayAbsentCount,
      todayHomeworkIncompleteCount: todayHomeworkIncompleteCount ?? this.todayHomeworkIncompleteCount,
      monthlyAverageScore: monthlyAverageScore ?? this.monthlyAverageScore,
      monthlyAttendanceRate: monthlyAttendanceRate ?? this.monthlyAttendanceRate,
      monthlyHomeworkCompletionRate: monthlyHomeworkCompletionRate ?? this.monthlyHomeworkCompletionRate,
      dangerStudentCount: dangerStudentCount ?? this.dangerStudentCount,
      aiAnalysisSummary: aiAnalysisSummary ?? this.aiAnalysisSummary,
      growthLeaderboard: growthLeaderboard ?? this.growthLeaderboard,
      recentActivity: recentActivity ?? this.recentActivity,
    );
  }
}

class GrowthLeaderboardItem {
  final int studentId;
  final String studentName;
  final int grade;
  final String className;
  final double growthRate; // e.g. 18.0
  final String growthTrend; // "상승 중", "하락 중", "유지"

  const GrowthLeaderboardItem({
    required this.studentId,
    required this.studentName,
    required this.grade,
    required this.className,
    required this.growthRate,
    required this.growthTrend,
  });
}

class RecentActivityItem {
  final String title;
  final String description;
  final String timestamp; // e.g. "오늘 14:30" or "7월 6일"
  final String type; // 'ATTENDANCE', 'HOMEWORK', 'EXAM'

  const RecentActivityItem({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.type,
  });
}
