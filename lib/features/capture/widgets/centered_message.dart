import 'package:flutter/material.dart';

import 'package:forma/design_system/tokens/app_colors.dart';
import 'package:forma/design_system/tokens/app_spacing.dart';
import 'package:forma/design_system/tokens/app_typography.dart';

/// Icon + message (+ optional action) centered on screen.
class CenteredMessage extends StatelessWidget {
  const CenteredMessage({
    required this.icon,
    required this.iconColor,
    required this.text,
    this.action,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 72, color: iconColor),
          const SizedBox(height: AppSpacing.xl),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.title.copyWith(
              color: FormaColors.of(context).textPrimary,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(width: 240, child: action),
          ],
        ],
      ),
    );
  }
}
