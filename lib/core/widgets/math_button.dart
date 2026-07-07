import 'package:flutter/material.dart';

class MathButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool isFullWidth;
  final bool isSecondary;

  const MathButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isFullWidth = true,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: isSecondary 
          ? theme.colorScheme.surface 
          : theme.colorScheme.primary,
      foregroundColor: isSecondary 
          ? theme.colorScheme.primary 
          : theme.colorScheme.onPrimary,
      side: isSecondary 
          ? BorderSide(color: theme.colorScheme.primary, width: 1.5) 
          : null,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isSecondary ? theme.colorScheme.primary : theme.colorScheme.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ] else if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            color: isSecondary ? theme.colorScheme.primary : theme.colorScheme.onPrimary,
          ),
        ),
      ],
    );

    Widget button = ElevatedButton(
      style: buttonStyle,
      onPressed: isLoading ? null : onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: content,
      ),
    );

    if (isFullWidth) {
      button = SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    // Wrap in animated container for minor tap scale feedback (micro-animation)
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      child: button,
    );
  }
}
