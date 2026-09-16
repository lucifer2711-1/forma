import 'package:flutter/material.dart';

import 'package:forma/core/strings.dart';
import 'package:forma/design_system/tokens/app_colors.dart';
import 'package:forma/design_system/tokens/app_spacing.dart';
import 'package:forma/design_system/tokens/app_typography.dart';

/// Sits between the camera preview and the capture chrome and renders an
/// honest state layer when the feed is not (yet) live:
/// - "Starting camera…" scrim while the session spins up
/// - dark fallback with a message once the camera is declared dead
/// While the feed is live it renders nothing, so the preview and the
/// capture overlay work simultaneously with zero interference.
class CameraHealthOverlay extends StatelessWidget {
  /// Creates the camera health overlay.
  const CameraHealthOverlay({
    required this.isCameraLive,
    required this.isSessionStarting,
    super.key,
  });

  /// Whether the native camera feed is confirmed alive.
  final bool isCameraLive;

  /// Whether startCapture() is still awaiting its first phase event.
  final bool isSessionStarting;

  @override
  Widget build(BuildContext context) {
    if (isCameraLive) {
      return const SizedBox.shrink();
    }
    final colors = FormaColors.of(context);
    if (isSessionStarting) {
      return ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: AppSpacing.lg),
              Text(
                Strings.cameraStarting,
                style: AppTypography.body.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    // Camera declared dead: dim the dead preview and tell the user why.
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off,
                size: 56,
                color: colors.textTertiary.withValues(alpha: 0.7),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                Strings.cameraDead,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
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
