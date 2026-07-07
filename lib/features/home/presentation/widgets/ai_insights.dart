import 'package:flutter/material.dart';
import '../../../../core/widgets/math_card.dart';

class AIInsights extends StatelessWidget {
  final String summary;

  const AIInsights({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'AI 분석 리포트',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MathCard(
          padding: const EdgeInsets.all(18),
          color: isDark 
              ? const Color(0xFF1F2B3E) 
              : const Color(0xFFE3F2FD).withOpacity(0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.insights_outlined,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '지능형 요약',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                summary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  fontSize: 14.5,
                  color: isDark ? Colors.grey.shade300 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
