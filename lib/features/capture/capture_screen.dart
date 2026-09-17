import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:forma/core/strings.dart';
import 'package:forma/design_system/components/primary_button.dart';
import 'package:forma/design_system/haptics/app_haptics.dart';
import 'package:forma/design_system/tokens/app_colors.dart';
import 'package:forma/design_system/tokens/app_spacing.dart';
import 'package:forma/design_system/tokens/app_typography.dart';
import 'package:forma/design_system/tokens/motion.dart';
import 'package:forma/features/capture/capture_view_model.dart';
import 'package:forma/features/capture/widgets/camera_health_overlay.dart';
import 'package:forma/features/capture/widgets/camera_preview.dart';
import 'package:forma/features/capture/widgets/centered_message.dart';
import 'package:forma/features/capture/widgets/coverage_panel.dart';
import 'package:forma/features/capture/widgets/reconstruction_panel.dart';
import 'package:forma/features/viewer/model_viewer_screen.dart';
import 'package:forma/platform/native_bridge/capture_state.dart';

/// Full-screen capture flow: aim → capture → reconstruct (spec §8.4).
///
/// The camera preview is the native `ObjectCaptureView` platform view;
/// this screen stacks guidance, phase messaging, and CTAs on top of it.
class CaptureScreen extends ConsumerStatefulWidget {
  /// Creates the capture screen.
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: Motion.pulse,
    )..repeat(reverse: true);
    // Opening the screen starts the native session (spec §8.4:
    // initializing → ready → detecting); the user then taps to capture.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(captureViewModelProvider.notifier).start());
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(captureViewModelProvider);
    final colors = FormaColors.of(context);
    ref.listen(captureViewModelProvider, (previous, next) {
      final wasCompleted = previous?.isCompleted ?? false;
      if (next.isCompleted && !wasCompleted) {
        AppHaptics.success();
        // Resolve both before popping: the capture screen's context is gone
        // by the time the viewer opens.
        final navigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);
        final scan = next.completedScan;
        messenger.showSnackBar(
          const SnackBar(
            content: Text(Strings.modelReady),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        navigator.pop();
        if (scan != null) {
          // Straight into the 360° model the scan just produced.
          navigator.push(
            MaterialPageRoute<void>(
              builder: (_) => ModelViewerScreen(scan: scan),
            ),
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CameraPreview(),
          CameraHealthOverlay(
            isCameraLive: state.isCameraLive,
            isSessionStarting: state.isSessionStarting,
            isTrackingInitializing: state.isTrackingInitializing,
          ),
          _buildOverlay(state),
          // The coverage globe sits above everything else: it is an opaque
          // review screen, and while it is open the camera underneath is not
          // what the user is looking at.
          if (state.isShowingCoverage && state.error == null)
            ColoredBox(
              color: colors.bg,
              child: CoveragePanel(
                map: state.coverage,
                shots: state.shots,
                passComplete: state.isScanPassComplete,
                currentDirection: state.currentDirection,
                onClose: () => ref
                    .read(captureViewModelProvider.notifier)
                    .hideCoverage(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverlay(CaptureUiState state) {
    final isError = state.error != null;
    if (isError) {
      // Opaque failure layer: blocks the camera and offers retry.
      return SafeArea(
        child: ColoredBox(
          color:
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: _buildError(state.error!),
          ),
        ),
      );
    }
    // Live layer: chrome sits on the preview; only the widgets themselves
    // hit-test, so the camera view receives the rest of the touches.
    // (Device test 2026-09-15: wrapping the whole overlay in IgnorePointer
    // made Start/Finish/Close untappable — do not reintroduce it.)
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          children: [
            _buildTopBar(state),
            if (state.isReconstructing)
              Expanded(child: Center(child: _buildStatusText(state)))
            else ...[
              const SizedBox(height: AppSpacing.lg),
              _buildStatusText(state),
              _buildProgressCaption(state),
              // The middle of the screen belongs to Object Capture's own AR
              // guidance: the bounding box, the walk-around arrows and the
              // coverage ring are all drawn there. Our hint used to sit
              // centred on top of it — hiding exactly the guidance a
              // full-coverage scan needs (device-test finding 2026-09-18).
              const Spacer(),
              _buildStepDots(state),
            ],
            _buildBottomControls(state),
          ],
        ),
      ),
    );
  }

  /// Progress through the three capture steps (aim → walk → build).
  ///
  /// The phase alone only says what to do next; a scan needs the user to know
  /// it is a loop around the whole object, and where they are in it.
  Widget _buildStepDots(CaptureUiState state) {
    final colors = FormaColors.of(context);
    final active = _stepFor(state);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        label: Strings.captureStepLabel(active + 1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var step = 0; step < 3; step++)
              AnimatedContainer(
                duration: Motion.micro,
                curve: Motion.curve,
                width: step == active ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: step == active
                      ? colors.accent
                      : colors.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 0 = aim, 1 = walk around, 2 = build.
  int _stepFor(CaptureUiState state) {
    switch (state.phase) {
      case CapturePhase.capturing:
        return 1;
      case CapturePhase.finishing:
      case CapturePhase.completed:
        return 2;
      case CapturePhase.initializing:
      case CapturePhase.ready:
      case CapturePhase.detecting:
      case CapturePhase.failed:
      case null:
        return 0;
    }
  }

  Widget _buildTopBar(CaptureUiState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _PillIconButton(
          icon: Icons.close,
          semanticLabel: Strings.close,
          onPressed: _close,
        ),
        // Reconstruction takes over the whole screen; hide chrome then.
        if (!state.isReconstructing)
          _PillIconButton(
            icon: Icons.flashlight_off_outlined,
            semanticLabel: Strings.torchLabel,
            onPressed: () {
              AppHaptics.tap();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(Strings.torchComingSoon),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildStatusText(CaptureUiState state) {
    if (state.isReconstructing) {
      return ReconstructionPanel(progress: state.reconstructionProgress);
    }
    // The "Starting camera…" scrim owns the center while the session
    // spins up, and the tracking-guidance layer owns it while ARKit
    // hasn't locked — the hint pill overlapped both (device tests
    // 2026-09-16/17).
    if ((state.isSessionStarting || state.isTrackingInitializing) &&
        !state.isCameraLive) {
      return const SizedBox.shrink();
    }
    final colors = FormaColors.of(context);
    return AnimatedSwitcher(
      duration: Motion.snappy,
      child: Container(
        key: ValueKey(_hintFor(state)),
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: colors.bgElevated.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          _hintFor(state),
          key: ValueKey(_hintFor(state)),
          textAlign: TextAlign.center,
          style: AppTypography.headline.copyWith(color: colors.textPrimary),
        ),
      ),
    );
  }

  /// Live proof that the scan is building, while capturing.
  ///
  /// The frame count is the session's own number. The percentage is our own
  /// measurement, but an honest one: it is the share of directions a frame has
  /// actually been kept for, not an interpolation of anything — which is what
  /// makes it usable as "keep going" feedback instead of decoration.
  Widget _buildProgressCaption(CaptureUiState state) {
    if (state.phase != CapturePhase.capturing || state.shots == 0) {
      return const SizedBox.shrink();
    }
    final colors = FormaColors.of(context);
    final coverage = state.coverage;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.sm,
        children: [
          Text(
            Strings.photosCaptured(state.shots),
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
          ),
          if (coverage.hasData)
            Text(
              Strings.coverageShort((coverage.fraction * 100).round()),
              style: AppTypography.caption.copyWith(color: colors.accent),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(CaptureUiState state) {
    if (state.phase == CapturePhase.capturing) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Two different questions, two answers: "which sides are done?"
          // (the globe) and "what did it actually capture?" (the geometry).
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: _buildCoverageButton(
                  icon: Icons.public,
                  label: Strings.coveragePillLabel,
                  onPressed: () => ref
                      .read(captureViewModelProvider.notifier)
                      .showCoverage(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: _buildCoverageButton(
                  icon: state.isReviewingModel
                      ? Icons.camera_alt_outlined
                      : Icons.threed_rotation,
                  label: state.isReviewingModel
                      ? Strings.backToCamera
                      : Strings.geometryPillLabel,
                  onPressed: () {
                    AppHaptics.tap();
                    unawaited(
                      ref
                          .read(captureViewModelProvider.notifier)
                          .toggleReviewMode(),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildFinishButton(),
        ],
      );
    }
    if (state.isCapturePending) {
      // The tap was accepted but the session has not confirmed the capture
      // yet. Showing it keeps a tap visible while it is retried, instead of
      // looking like an unresponsive button (device-test finding
      // 2026-09-17).
      return const PrimaryButton(label: Strings.gettingReady);
    }
    if (_showsStartButton(state)) {
      return ScaleTransition(
        scale: Tween<double>(begin: 1, end: 1.05).animate(
          CurvedAnimation(parent: _pulse, curve: Motion.curvePulse),
        ),
        child: _buildStartButton(),
      );
    }
    return const SizedBox(height: 56);
  }

  /// Whether the pulsing "Start Capture" CTA should show (spec §8.4).
  bool _showsStartButton(CaptureUiState state) {
    switch (state.phase) {
      case null:
      case CapturePhase.initializing:
      case CapturePhase.ready:
      case CapturePhase.detecting:
        return true;
      case CapturePhase.capturing:
      case CapturePhase.finishing:
      case CapturePhase.completed:
      case CapturePhase.failed:
        return false;
    }
  }

  /// A pill button that reviews what the scan has captured so far.
  Widget _buildCoverageButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final colors = FormaColors.of(context);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: colors.bgElevated.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: colors.textPrimary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headline.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStartButton() => PrimaryButton(
        label: Strings.scanCta,
        onPressed: () {
          AppHaptics.tap();
          unawaited(
            ref.read(captureViewModelProvider.notifier).startOrBegin(),
          );
        },
      );

  Widget _buildFinishButton() => PrimaryButton(
        label: Strings.finishCapture,
        onPressed: () {
          AppHaptics.tap();
          unawaited(ref.read(captureViewModelProvider.notifier).finish());
        },
      );

  Widget _buildError(String message) => CenteredMessage(
        icon: Icons.error_outline,
        iconColor: FormaColors.of(context).danger,
        text: message,
        action: PrimaryButton(
          label: Strings.retry,
          onPressed: () {
            AppHaptics.tap();
            unawaited(ref.read(captureViewModelProvider.notifier).retry());
          },
        ),
      );

  String _hintFor(CaptureUiState state) {
    // While the point cloud is on screen the camera is not, so live framing
    // feedback would be guidance about a view the user cannot see.
    if (state.isReviewingModel) {
      return Strings.geometryHint;
    }
    // The feedback names describe where the object is, so the guidance is the
    // opposite direction. These were inverted: `objectTooClose` told the user
    // to move closer and `objectTooFar` to move farther — the app fought the
    // session's own guidance (device-test finding 2026-09-18).
    switch (state.feedback) {
      case CaptureFeedbackType.objectTooClose:
        return Strings.moveFarther;
      case CaptureFeedbackType.objectTooFar:
        return Strings.moveCloser;
      case CaptureFeedbackType.movingTooFast:
        return Strings.slowDown;
      case CaptureFeedbackType.outOfFieldOfView:
        return Strings.keepInView;
      case CaptureFeedbackType.environmentLowLight:
        return Strings.lowLightHint;
      case CaptureFeedbackType.objectNotDetected:
        return Strings.objectNotDetectedHint;
      case CaptureFeedbackType.none:
        break;
    }
    switch (state.phase) {
      case CapturePhase.detecting:
        return Strings.detectingHint;
      case CapturePhase.capturing:
        // Apple's own milestone: the dial is full and every side is covered.
        // Asking for another lap would waste the user's time and add nothing
        // — the sides a single circle always misses are the top and the
        // underside.
        return state.isScanPassComplete
            ? Strings.passCompleteHint
            : Strings.capturingHint;
      case CapturePhase.finishing:
        return Strings.finishingHint;
      case CapturePhase.ready:
      case CapturePhase.initializing:
      case CapturePhase.completed:
      case CapturePhase.failed:
      case null:
        return Strings.aimHint;
    }
  }

  void _close() {
    AppHaptics.tap();
    unawaited(ref.read(captureViewModelProvider.notifier).cancel());
    Navigator.of(context).pop();
  }
}

/// Blurred circular icon button for the capture top bar (spec §8.4).
class _PillIconButton extends StatelessWidget {
  const _PillIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = FormaColors.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: colors.bgElevated.withValues(alpha: 0.72),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 22, color: colors.textPrimary),
          ),
        ),
      ),
    );
  }
}
