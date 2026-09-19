import 'package:flutter/material.dart';

import 'package:forma/core/strings.dart';
import 'package:forma/design_system/components/progress_ring.dart';
import 'package:forma/design_system/tokens/app_colors.dart';
import 'package:forma/design_system/tokens/app_spacing.dart';
import 'package:forma/design_system/tokens/app_typography.dart';
import 'package:forma/design_system/tokens/motion.dart';

/// Reconstruction progress: ring + percentage + stage + time left.
///
/// The stage and the remaining time are RealityKit's own
/// (`requestProgressInfo`), which is what makes a long build bearable:
/// "Aligning the photos — about 2 minutes left" answers the question a bare
/// percentage leaves open, and it answers it honestly rather than with our
/// guess (user request 2026-09-18: the build feels like it takes too long).
class ReconstructionPanel extends StatelessWidget {
  const ReconstructionPanel({
    required this.progress,
    this.stage,
    this.secondsRemaining,
    super.key,
  });

  /// Progress from 0 to 1.
  final double progress;

  /// Apple's current pipeline stage token, or null before it reports one.
  final String? stage;

  /// Apple's estimate of the seconds left, or null while it has none.
  final int? secondsRemaining;

  @override
  Widget build(BuildContext context) {
    final colors = FormaColors.of(context);
    final percent = (progress * 100).round();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProgressRing(progress: progress, size: 120),
          const SizedBox(height: AppSpacing.xl),
          Text(
            '$percent%',
            style: AppTypography.displayM.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedSwitcher(
            duration: Motion.snappy,
            child: Text(
              // Keyed so the crossfade follows the stage rather than the
              // widget's position in the tree.
              stage == null
                  ? Strings.reconstructing
                  : Strings.reconstructionStageName(stage!),
              key: ValueKey(stage),
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
          ),
          if (secondsRemaining != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              Strings.timeRemaining(secondsRemaining!),
              style: AppTypography.headline.copyWith(color: colors.accent),
            ),
          ],
        ],
      ),
    );
  }
}
