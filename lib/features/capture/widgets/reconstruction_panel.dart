import 'package:flutter/material.dart';

import 'package:forma/core/strings.dart';
import 'package:forma/design_system/components/progress_ring.dart';
import 'package:forma/design_system/tokens/app_colors.dart';
import 'package:forma/design_system/tokens/app_spacing.dart';
import 'package:forma/design_system/tokens/app_typography.dart';

/// Reconstruction progress: ring + animated percentage + label.
class ReconstructionPanel extends StatelessWidget {
  const ReconstructionPanel({required this.progress, super.key});

  final double progress;

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
          Text(
            Strings.reconstructing,
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
