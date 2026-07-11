import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/math_card.dart';

class PerformanceStats extends StatelessWidget {
  final double monthlyAverageScore;
  final double monthlyAttendanceRate;
  final double monthlyHomeworkCompletionRate;
  final Color? examGroupColor;

  const PerformanceStats({
    super.key,
    required this.monthlyAverageScore,
    required this.monthlyAttendanceRate,
    required this.monthlyHomeworkCompletionRate,
    this.examGroupColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            '이번 달 종합 지표',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        MathCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildProgressRow(
                context,
                title: '평균 시험 점수',
                value: '${monthlyAverageScore.toStringAsFixed(1)}%',
                percentage: monthlyAverageScore / 100,
                color: examGroupColor ?? theme.colorScheme.primary,
                onTap: () => context.go('/grades'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(height: 1),
              ),
              _buildProgressRow(
                context,
                title: '평균 출석률',
                value: '${(monthlyAttendanceRate * 100).toStringAsFixed(0)}%',
                percentage: monthlyAttendanceRate,
                color: const Color(0xFF4CAF50),
                onTap: () => context.go('/attendance'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(height: 1),
              ),
              _buildProgressRow(
                context,
                title: '과제 완료율',
                value: '${(monthlyHomeworkCompletionRate * 100).toStringAsFixed(0)}%',
                percentage: monthlyHomeworkCompletionRate,
                color: const Color(0xFFFF9800),
                onTap: () => context.push('/homework'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressRow(
    BuildContext context, {
    required String title,
    required String value,
    required double percentage,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final clampedPercentage = percentage.clamp(0.0, 1.0);

    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.3),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: clampedPercentage,
              backgroundColor: theme.brightness == Brightness.dark
                  ? const Color(0xFF2E3135)
                  : Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
