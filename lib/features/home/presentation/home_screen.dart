import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/home_provider.dart';
import 'widgets/quick_actions.dart';
import 'widgets/today_summary.dart';
import 'widgets/performance_stats.dart';
import 'widgets/ai_insights.dart';
import 'widgets/leaderboard.dart';
import 'widgets/recent_activity.dart';
import '../../../core/widgets/math_loader.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('대시보드'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('모든 데이터가 안전하게 저장되었습니다.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: '데이터 저장',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: statsAsync.when(
        data: (stats) {
          return SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                // Drift stream query will update automatically, but this can serve as manual triggers
                ref.invalidate(dashboardStatsProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Quick Actions
                    const QuickActions(),
                    const SizedBox(height: 24),
                    
                    // 2. Today's Summary
                    TodaySummary(
                      presentCount: stats.todayPresentCount,
                      lateCount: stats.todayLateCount,
                      absentCount: stats.todayAbsentCount,
                      hwIncompleteCount: stats.todayHomeworkIncompleteCount,
                      dangerStudentCount: stats.dangerStudentCount,
                    ),
                    const SizedBox(height: 24),
                    
                    // 3. AI Insights
                    AIInsights(summary: stats.aiAnalysisSummary),
                    const SizedBox(height: 24),

                    // 4. Performance Statistics (Monthly Rates & Average)
                    PerformanceStats(
                      monthlyAverageScore: stats.monthlyAverageScore,
                      monthlyAttendanceRate: stats.monthlyAttendanceRate,
                      monthlyHomeworkCompletionRate: stats.monthlyHomeworkCompletionRate,
                    ),
                    const SizedBox(height: 24),

                    // 5. Growth Leaderboard
                    GrowthLeaderboard(items: stats.growthLeaderboard),
                    const SizedBox(height: 24),

                    // 6. Recent Activity
                    RecentActivity(items: stats.recentActivity),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const MathLoader(message: '대시보드 데이터를 불러오는 중...'),
        error: (error, stack) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFF44336),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '데이터를 불러오지 못했습니다.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(dashboardStatsProvider),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
