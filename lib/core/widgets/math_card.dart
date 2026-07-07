import 'package:flutter/material.dart';

class MathCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double borderRadius;

  const MathCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      side: theme.brightness == Brightness.light
          ? BorderSide(color: Colors.grey.shade200, width: 1.0)
          : const BorderSide(color: Color(0xFF2E3135), width: 1.0),
    );

    Widget content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null || subtitle != null || trailing != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );

    if (onTap != null) {
      return Card(
        color: color ?? theme.cardTheme.color,
        shape: cardShape,
        elevation: 0,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: content,
        ),
      );
    }

    return Card(
      color: color ?? theme.cardTheme.color,
      shape: cardShape,
      elevation: 0,
      margin: EdgeInsets.zero,
      child: content,
    );
  }
}
