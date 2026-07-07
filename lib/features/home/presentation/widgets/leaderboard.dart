import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/dashboard_stats.dart';
import '../../../../core/widgets/math_card.dart';

class GrowthLeaderboard extends StatelessWidget {
  final List<GrowthLeaderboardItem> items;

  const GrowthLeaderboard({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Limit to top 5 items
    final list = items.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            '성장률 우수 학생 (최근 시험 대비)',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          MathCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                '시험 데이터가 충분하지 않습니다.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else
          MathCard(
            padding: EdgeInsets.zero,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final student = list[index];
                final rank = index + 1;
                final growthPercent = student.growthRate;
                final isGrowing = growthPercent > 0;
                final isDeclining = growthPercent < 0;

                final rateText = (isGrowing ? '+' : '') + growthPercent.toStringAsFixed(0) + '%';
                final badgeColor = isGrowing
                    ? const Color(0xFFE8F5E9)
                    : isDeclining
                        ? const Color(0xFFFFEBEE)
                        : Colors.grey.shade100;
                final textColor = isGrowing
                    ? const Color(0xFF2E7D32)
                    : isDeclining
                        ? const Color(0xFFC62828)
                        : Colors.grey.shade700;

                return ListTile(
                  leading: _buildRankBadge(context, rank),
                  title: Row(
                    children: [
                      Text(
                        student.studentName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatGrade(student.grade),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark 
                          ? Colors.white.withOpacity(0.05) 
                          : badgeColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      rateText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.brightness == Brightness.dark 
                            ? (isGrowing ? const Color(0xFF81C784) : (isDeclining ? const Color(0xFFE57373) : Colors.white70)) 
                            : textColor,
                      ),
                    ),
                  ),
                  onTap: () => context.push('/student/${student.studentId}'),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRankBadge(BuildContext context, int rank) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (rank == 1) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: isDark ? const Color(0xFFFBC02D).withOpacity(0.2) : const Color(0xFFFFF9C4),
        child: const Icon(Icons.star, color: Color(0xFFFBC02D), size: 16),
      );
    }
    if (rank == 2) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: isDark ? Colors.grey.withOpacity(0.2) : const Color(0xFFF5F5F5),
        child: Text('2', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
      );
    }
    if (rank == 3) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: isDark ? const Color(0xFF8D6E63).withOpacity(0.2) : const Color(0xFFFFE0B2),
        child: Text('3', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFF8D6E63))),
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: Colors.transparent,
      child: Text(
        '$rank',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
        ),
      ),
    );
  }

  String _formatGrade(int grade) {
    if (grade >= 1 && grade <= 6) {
      return '초$grade';
    } else if (grade >= 7 && grade <= 9) {
      return '중${grade - 6}';
    }
    return '$grade학년';
  }
}
