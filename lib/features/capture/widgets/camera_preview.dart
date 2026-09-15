import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:forma/core/strings.dart';
import 'package:forma/design_system/tokens/app_colors.dart';
import 'package:forma/design_system/tokens/app_spacing.dart';
import 'package:forma/design_system/tokens/app_typography.dart';

/// Native camera preview (Apple's `ObjectCaptureView`) embedded via
/// platform views — Phase 2a pulled forward so the capture screen shows
/// the real camera feed (master spec §8.4).
///
/// On non-iOS hosts the platform view fails to hydrate; this widget
/// recovers by rendering a labeled placeholder so dev/CI keeps working.
class CameraPreview extends StatefulWidget {
  /// Creates the camera preview.
  const CameraPreview({super.key});

  @override
  State<CameraPreview> createState() => _CameraPreviewState();
}

class _CameraPreviewState extends State<CameraPreview> {
  @override
  Widget build(BuildContext context) {
    // The native factory only exists in the iOS Runner; elsewhere (Windows
    // dev, widget tests) show an honest placeholder instead of a blank hole.
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const _Placeholder();
    }
    return const UiKitView(
      viewType: 'com.forma.app/capture_preview',
      creationParamsCodec: StandardMessageCodec(),
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{},
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    final colors = FormaColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.bgSunken),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off_outlined,
                size: 56,
                color: colors.textTertiary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                Strings.cameraUnavailable,
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
