import 'package:flutter/material.dart';

import 'package:forma/core/strings.dart';
import 'package:forma/design_system/tokens/app_colors.dart';
import 'package:forma/design_system/tokens/app_spacing.dart';
import 'package:forma/design_system/tokens/app_typography.dart';
import 'package:forma/design_system/tokens/motion.dart';

/// Honest explainer for devices that cannot scan — spec §8.10.
///
/// No scanning entry point, no "try anyway", no dark patterns: just a clear
/// explanation of the LiDAR requirement and the supported devices.
class UnsupportedDeviceScreen extends StatefulWidget {
  /// Creates the unsupported-device screen.
  const UnsupportedDeviceScreen({super.key});

  @override
  State<UnsupportedDeviceScreen> createState() =>
      _UnsupportedDeviceScreenState();
}

class _UnsupportedDeviceScreenState extends State<UnsupportedDeviceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: Motion.pulse,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = FormaColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.appName),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 1, end: 1.05)
                    .animate(CurvedAnimation(
                  parent: _pulse,
                  curve: Motion.curvePulse,
                )),
                child: Icon(
                  Icons.mobile_off,
                  size: 72,
                  color: colors.textTertiary.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                Strings.unsupportedTitle,
                textAlign: TextAlign.center,
                style: AppTypography.displayM.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                Strings.unsupportedBody,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                Strings.unsupportedDevicesTitle,
                style: AppTypography.title.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                Strings.unsupportedDevicesBody,
                textAlign: TextAlign.center,
                style: AppTypography.subhead.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
