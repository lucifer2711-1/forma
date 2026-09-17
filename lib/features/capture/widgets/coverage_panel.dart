import 'package:flutter/material.dart';

import 'package:forma/core/strings.dart';
import 'package:forma/design_system/tokens/app_colors.dart';
import 'package:forma/design_system/tokens/app_spacing.dart';
import 'package:forma/design_system/tokens/app_typography.dart';
import 'package:forma/features/capture/coverage/coverage_map.dart';
import 'package:forma/features/capture/widgets/coverage_globe.dart';
import 'package:forma/platform/native_bridge/capture_state.dart';

/// The "which sides are done?" screen.
///
/// A scan is only as good as its weakest side, and the previous way of
/// checking — a point cloud with a line drawn between every shot — told the
/// user nothing they could act on: it was a hairball, and it said nothing
/// about which way to walk next (device-test finding 2026-09-18). This panel
/// answers three questions at a glance: what is captured, what is missing, and
/// where the phone is pointing right now.
class CoveragePanel extends StatelessWidget {
  /// Creates the panel.
  const CoveragePanel({
    required this.map,
    required this.shots,
    required this.passComplete,
    required this.onClose,
    this.currentDirection,
    this.diameter = 248,
    super.key,
  });

  /// Coverage of the object by direction.
  final CoverageMap map;

  /// Frames the session has kept.
  final int shots;

  /// Whether the session reports a completed 360° pass.
  final bool passComplete;

  /// Where the phone is pointed right now.
  final ScanDirection? currentDirection;

  /// Rendered size of the globe.
  final double diameter;

  /// Dismisses the panel.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = FormaColors.of(context);
    final percent = (map.fraction * 100).round();
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context, colors),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: CoverageGlobe(
                  map: map,
                  currentDirection: currentDirection,
                  diameter: diameter,
                  semanticsLabel: _semanticsSummary(percent),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                Strings.coverageDragHint,
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                Strings.coveragePercent(percent),
                style:
                    AppTypography.displayM.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildLegend(colors),
              const SizedBox(height: AppSpacing.xl),
              _buildBands(colors),
              const SizedBox(height: AppSpacing.xl),
              _buildGuidance(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, FormaColors colors) => Row(
        children: [
          Expanded(
            child: Text(
              Strings.coverageTitle,
              style: AppTypography.title.copyWith(color: colors.textPrimary),
            ),
          ),
          Semantics(
            button: true,
            label: Strings.backToCamera,
            child: Material(
              color: colors.bgElevated.withValues(alpha: 0.72),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onClose,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.close, size: 22, color: colors.textPrimary),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _buildLegend(FormaColors colors) => Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.sm,
        children: [
          _LegendItem(
            color: colors.accent,
            label: Strings.coverageLegendScanned,
          ),
          _LegendItem(
            color: colors.textTertiary,
            label: Strings.coverageLegendMissing,
            hollow: true,
          ),
          _LegendItem(
            color: colors.textPrimary,
            label: Strings.coverageYouAreHere,
            ringed: true,
          ),
        ],
      );

  /// The per-band checklist: what a finished scan actually needs.
  Widget _buildBands(FormaColors colors) => Column(
        children: [
          for (final status in map.bands)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(
                      _bandLabel(status.band),
                      style: AppTypography.subhead.copyWith(
                        color: status.isComplete
                            ? colors.textPrimary
                            : colors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: LinearProgressIndicator(
                        value: status.fraction,
                        minHeight: 6,
                        backgroundColor: colors.bgElevated,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          status.isComplete ? colors.success : colors.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${(status.fraction * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    status.isComplete
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: status.isComplete
                        ? colors.success
                        : colors.textTertiary,
                  ),
                ],
              ),
            ),
        ],
      );

  /// Says what to do next, in the order the missing bands matter.
  Widget _buildGuidance(FormaColors colors) {
    final text = _guidanceText();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.bgElevated.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            map.missingBands.isEmpty
                ? Icons.check_circle_outline
                : Icons.info_outline,
            size: 20,
            color: map.missingBands.isEmpty ? colors.success : colors.accent,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: AppTypography.subhead.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  String _guidanceText() {
    if (!map.hasData) {
      // Directions come from device motion. If frames were kept but no
      // direction ever arrived, the honest answer is that this device cannot
      // show the globe — not a confident "0% scanned".
      return shots > 0
          ? Strings.coverageNoDirections
          : Strings.coverageEmptyHint;
    }
    final missing = map.missingBands;
    if (missing.isEmpty) {
      return passComplete
          ? Strings.coverageCompleteHint
          : Strings.coverageAlmostHint;
    }
    return Strings.coverageStillToScan(
      _joinBands(missing.map(_bandName).toList()),
    );
  }

  String _semanticsSummary(int percent) =>
      '${Strings.coveragePercent(percent)}. ${_guidanceText()}';

  static String _bandLabel(CoverageBand band) => switch (band) {
        CoverageBand.top => Strings.coverageBandTop,
        CoverageBand.sides => Strings.coverageBandSides,
        CoverageBand.bottom => Strings.coverageBandBottom,
      };

  static String _bandName(CoverageBand band) => switch (band) {
        CoverageBand.top => Strings.coverageNameTop,
        CoverageBand.sides => Strings.coverageNameSides,
        CoverageBand.bottom => Strings.coverageNameBottom,
      };

  static String _joinBands(List<String> bands) {
    if (bands.length == 1) {
      return bands.single;
    }
    if (bands.length == 2) {
      return '${bands.first} and ${bands.last}';
    }
    return '${bands.take(bands.length - 1).join(', ')} and ${bands.last}';
  }
}

/// A dot/swatch plus label for the globe's legend.
class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.hollow = false,
    this.ringed = false,
  });

  final Color color;
  final String label;
  final bool hollow;
  final bool ringed;

  @override
  Widget build(BuildContext context) {
    final colors = FormaColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: ringed ? 12 : 9,
          height: ringed ? 12 : 9,
          decoration: BoxDecoration(
            color: hollow ? Colors.transparent : color,
            shape: BoxShape.circle,
            border: hollow || ringed
                ? Border.all(color: color, width: ringed ? 2 : 1.5)
                : null,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}
