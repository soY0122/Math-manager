import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final List<_QuickActionItem> actions = [
      _QuickActionItem(
        icon: Icons.person_add_outlined,
        label: '학생 추가',
        color: const Color(0xFFE3F2FD),
        iconColor: const Color(0xFF1E88E5),
        onTap: () => context.push('/student/add'),
      ),
      _QuickActionItem(
        icon: Icons.check_circle_outline,
        label: '출석 기록',
        color: const Color(0xFFE8F5E9),
        iconColor: const Color(0xFF4CAF50),
        onTap: () => context.go('/attendance'),
      ),
      _QuickActionItem(
        icon: Icons.menu_book_outlined,
        label: '과제 기록',
        color: const Color(0xFFFFF3E0),
        iconColor: const Color(0xFFFF9800),
        onTap: () => context.push('/homework'),
      ),
      _QuickActionItem(
        icon: Icons.post_add_outlined,
        label: '시험 등록',
        color: const Color(0xFFF3E5F5),
        iconColor: const Color(0xFF9C27B0),
        onTap: () => context.push('/grades/add-exam'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            '빠른 작업',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: actions.map((item) {
            final isDark = theme.brightness == Brightness.dark;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? theme.colorScheme.surface : item.color,
                      borderRadius: BorderRadius.circular(16),
                      border: isDark 
                          ? Border.all(color: theme.colorScheme.onSurface.withOpacity(0.1)) 
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          color: isDark ? theme.colorScheme.primary : item.iconColor,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isDark ? theme.colorScheme.onSurface : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _QuickActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });
}
