import 'package:flutter/material.dart';

import 'package:forma/core/strings.dart';
import 'package:forma/design_system/tokens/app_colors.dart';
import 'package:forma/design_system/tokens/app_spacing.dart';
import 'package:forma/design_system/tokens/app_typography.dart';
import 'package:forma/features/capture/coverage/capture_steps.dart';

/// The six named sides of the guided walk, in the order they are asked for.
///
/// Tapping a side asks for it next. That is the point: the order is a
/// suggestion, not a rule — doing the underside first while the object is
/// still in your hand, or the back before the sides, is the user's call
/// (user request 2026-09-20: "add feature to scan side underside by just
/// clicking on it").
///
/// Hidden until the walk can be anchored. Before the first frame is kept there
/// is no way to name a side — "right" means nothing until the app knows which
/// way the user's front is — so showing six labels that could point anywhere
/// would be worse than showing none.
class CaptureStepBar extends StatelessWidget {
  /// Creates the walk's side chips.
  const CaptureStepBar({
    required this.plan,
    required this.onSelect,
    super.key,
  });

  /// The walk, tracked against the frames really kept.
  final CaptureStepPlan plan;

  /// Called when the user taps a side to do it next.
  final ValueChanged<CaptureStepId> onSelect;

  @override
  Widget build(BuildContext context) {
    if (!plan.isAnchored) {
      return const SizedBox.shrink();
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final step in plan.steps) ...[
            _SideChip(
              id: step.id,
              status: plan.statusOf(step.id),
              onTap: () => onSelect(step.id),
            ),
            if (step != plan.steps.last) const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// A side's own name.
String sideLabel(CaptureStepId id) => switch (id) {
      CaptureStepId.front => Strings.captureStepFront,
      CaptureStepId.right => Strings.captureStepRight,
      CaptureStepId.back => Strings.captureStepBack,
      CaptureStepId.left => Strings.captureStepLeft,
      CaptureStepId.top => Strings.captureStepTop,
      CaptureStepId.underside => Strings.captureStepUnderside,
    };

/// What to do for a side, in the user's own frame of reference.
///
/// Every instruction says which way to *move* rather than which part of the
/// object it is: nobody can tell an anonymous object's right from its left,
/// but everybody knows which way their own right is. This project has already
/// shipped inverted guidance once (gotcha 21), and the fix then was the same
/// one: describe the action, not the geometry.
String sideHint(CaptureStepId id) => switch (id) {
      CaptureStepId.front => Strings.guidedFrontHint,
      CaptureStepId.right => Strings.guidedRightHint,
      CaptureStepId.back => Strings.guidedBackHint,
      CaptureStepId.left => Strings.guidedLeftHint,
      CaptureStepId.top => Strings.guidedTopHint,
      CaptureStepId.underside => Strings.guidedUndersideHint,
    };

class _SideChip extends StatelessWidget {
  const _SideChip({
    required this.id,
    required this.status,
    required this.onTap,
  });

  final CaptureStepId id;
  final CaptureStepStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = FormaColors.of(context);
    final isCaptured = status == CaptureStepStatus.captured;
    final isCurrent = status == CaptureStepStatus.current;
    final isSkipped = status == CaptureStepStatus.skipped;
    final label = sideLabel(id);

    final Color background;
    final Color foreground;
    if (isCaptured) {
      background = colors.success.withValues(alpha: 0.22);
      foreground = colors.success;
    } else if (isCurrent) {
      background = colors.accent;
      foreground = Colors.white;
    } else {
      background = colors.bgElevated.withValues(alpha: 0.72);
      foreground = isSkipped
          ? colors.textTertiary
          : colors.textSecondary;
    }

    return Semantics(
      button: true,
      selected: isCurrent,
      label: '${Strings.sideChipLabel(label)}'
          '${isCaptured ? ', captured' : ''}'
          '${isSkipped ? ', skipped' : ''}',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCaptured
                      ? Icons.check_circle
                      : isSkipped
                          ? Icons.remove_circle_outline
                          : Icons.circle_outlined,
                  size: 14,
                  color: foreground,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: foreground,
                    fontWeight: isCurrent ? FontWeight.w600 : null,
                    decoration:
                        isSkipped ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
