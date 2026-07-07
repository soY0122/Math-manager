import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/dashboard_stats.dart';
import '../../../../core/widgets/math_card.dart';

class RecentActivity extends StatelessWidget {
  final List<RecentActivityItem> items;

  const RecentActivity({
    super.key,
    required this.items,
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
            '최근 활동 내역',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          MathCard(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                '최근 기록된 활동이 없습니다.',
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
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final activity = items[index];
                final type = activity.type;

                // Configure aesthetics based on activity type
                Color typeColor;
                IconData typeIcon;
                VoidCallback onTap;

                if (type == 'EXAM') {
                  typeColor = theme.colorScheme.primary;
                  typeIcon = Icons.assignment_outlined;
                  onTap = () => context.go('/grades');
                } else if (type == 'ATTENDANCE') {
                  typeColor = const Color(0xFF4CAF50);
                  typeIcon = Icons.calendar_today_outlined;
                  onTap = () => context.go('/attendance');
                } else {
                  typeColor = const Color(0xFFFF9800);
                  typeIcon = Icons.menu_book_outlined;
                  onTap = () => context.push('/homework');
                }

                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      typeIcon,
                      color: typeColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    activity.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    activity.description,
                    style: theme.textTheme.bodyMedium,
                  ),
                  trailing: Text(
                    activity.timestamp,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                    ),
                  ),
                  onTap: onTap,
                );
              },
            ),
          ),
      ],
    );
  }
}
