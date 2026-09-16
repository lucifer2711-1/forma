import 'package:flutter/material.dart';
import 'package:forma/design_system/components/primary_button.dart';
import 'package:forma/design_system/tokens/app_colors.dart';
import 'package:forma/design_system/tokens/app_spacing.dart';
import 'package:forma/design_system/tokens/app_typography.dart';

/// Large icon + title + subtitle + optional CTA for empty screens.
///
/// Per design.md §3.5: 72pt symbol at 40% opacity, Display M title.
class EmptyState extends StatelessWidget {
  /// Creates an empty state.
  const EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onCta,
    super.key,
  });

  /// Large decorative icon.
  final IconData icon;

  /// Primary message.
  final String title;

  /// Secondary message.
  final String subtitle;

  /// Optional call-to-action label.
  final String? ctaLabel;

  /// Optional call-to-action handler.
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final colors = FormaColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 72,
              color: colors.textTertiary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.displayM.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: 240,
                child: PrimaryButton(label: ctaLabel!, onPressed: onCta),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
