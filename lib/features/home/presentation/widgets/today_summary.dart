import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/math_card.dart';

class TodaySummary extends StatelessWidget {
  final int presentCount;
  final int lateCount;
  final int absentCount;
  final int hwIncompleteCount;
  final int dangerStudentCount;

  const TodaySummary({
    super.key,
    required this.presentCount,
    required this.lateCount,
    required this.absentCount,
    required this.hwIncompleteCount,
    required this.dangerStudentCount,
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
            '오늘의 현황',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Layout: 3 columns for attendance, 2 columns below for homework and at-risk
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                title: '출석',
                value: '$presentCount명',
                color: const Color(0xFF4CAF50),
                onTap: () => context.go('/student?filter=attendance_present'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                context,
                title: '지각',
                value: '$lateCount명',
                color: const Color(0xFFFF9800),
                onTap: () => context.go('/student?filter=attendance_late'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                context,
                title: '결석',
                value: '$absentCount명',
                color: const Color(0xFFF44336),
                onTap: () => context.go('/student?filter=attendance_absent'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildWideStatCard(
                context,
                title: '숙제 미완료 학생',
                value: '$hwIncompleteCount명',
                icon: Icons.assignment_late_outlined,
                iconColor: const Color(0xFFEF5350),
                onTap: () => context.go('/student?filter=homework_incomplete'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildWideStatCard(
                context,
                title: '위험 학생군',
                value: '$dangerStudentCount명',
                icon: Icons.warning_amber_rounded,
                iconColor: const Color(0xFFE53935),
                onTap: () => context.go('/student?filter=at_risk'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MathCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? theme.colorScheme.onSurface.withOpacity(0.7) : Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return MathCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withOpacity(0.1),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.brightness == Brightness.dark 
                        ? theme.colorScheme.primary 
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
