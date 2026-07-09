import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/home_provider.dart';
import '../../test/presentation/providers/exam_providers.dart';
import '../../test/domain/models/exam_group_models.dart';
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
          final selectedGroupId = ref.watch(dashboardExamGroupFilterProvider);
          final allGroups = ref.watch(examGroupsStreamProvider).value ?? [];
          final selectedGroup = allGroups.firstWhere(
            (g) => g.id == selectedGroupId,
            orElse: () => const ExamGroup(id: '', name: '', colorHex: '', orderIndex: 0),
          );
          final groupColor = selectedGroupId != null && selectedGroup.colorHex.isNotEmpty
              ? _parseColor(selectedGroup.colorHex)
              : null;

          return SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(dashboardStatsProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Exam Group Filter selector
                    _buildDashboardGroupFilter(context, ref),
                    const SizedBox(height: 16),

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
                      examGroupColor: groupColor,
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

  Widget _buildDashboardGroupFilter(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(examGroupsStreamProvider);
    final selectedGroupId = ref.watch(dashboardExamGroupFilterProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return groupsAsync.maybeWhen(
      data: (groups) {
        if (groups.isEmpty) return const SizedBox.shrink();

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Icon(Icons.filter_list_rounded, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Text(
                  '시험 분석 그룹:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: selectedGroupId,
                      isExpanded: true,
                      dropdownColor: theme.colorScheme.surface,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            '전체 시험 (합산)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        ...groups.map((g) {
                          final color = _parseColor(g.colorHex);
                          return DropdownMenuItem<String?>(
                            value: g.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  g.name,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        ref.read(dashboardExamGroupFilterProvider.notifier).state = val;
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Color _parseColor(String hex) {
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFF3F51B5);
    }
  }
}
