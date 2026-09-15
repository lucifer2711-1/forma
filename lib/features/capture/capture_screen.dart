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
import 'package:forma/features/capture/widgets/camera_preview.dart';
import 'package:forma/features/capture/widgets/centered_message.dart';
import 'package:forma/features/capture/widgets/reconstruction_panel.dart';
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
    ref.listen(captureViewModelProvider, (previous, next) {
      final wasCompleted = previous?.isCompleted ?? false;
      if (next.isCompleted && !wasCompleted) {
        AppHaptics.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(Strings.modelReady),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CameraPreview(),
          _buildOverlay(state),
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
            Expanded(child: Center(child: _buildStatusText(state))),
            _buildBottomControls(state),
          ],
        ),
      ),
    );
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
            semanticLabel: 'Flashlight',
            onPressed: () {
              AppHaptics.tap();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Torch arrives in the next build'),
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

  Widget _buildBottomControls(CaptureUiState state) {
    if (_showsStartButton(state)) {
      return ScaleTransition(
        scale: Tween<double>(begin: 1, end: 1.05).animate(
          CurvedAnimation(parent: _pulse, curve: Motion.curvePulse),
        ),
        child: _buildStartButton(),
      );
    }
    if (state.phase == CapturePhase.capturing) {
      return _buildFinishButton();
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
    switch (state.feedback) {
      case CaptureFeedbackType.objectTooClose:
        return Strings.moveCloser;
      case CaptureFeedbackType.objectTooFar:
        return Strings.moveFarther;
      case CaptureFeedbackType.movingTooFast:
        return Strings.slowDown;
      case CaptureFeedbackType.outOfFieldOfView:
        return Strings.keepInView;
      case CaptureFeedbackType.none:
        break;
    }
    switch (state.phase) {
      case CapturePhase.capturing:
        return Strings.capturingHint;
      case CapturePhase.finishing:
        return Strings.finishingHint;
      case CapturePhase.ready:
      case CapturePhase.detecting:
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
