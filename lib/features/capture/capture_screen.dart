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
import 'package:forma/features/capture/widgets/centered_message.dart';
import 'package:forma/features/capture/widgets/reconstruction_panel.dart';
import 'package:forma/platform/native_bridge/capture_state.dart';

/// Full-screen capture flow: aim → capture → reconstruct (spec §8.4).
///
/// The camera preview itself is a native platform view added in Phase 2;
/// this screen owns the guidance UI, state machine, and transitions.
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
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      backgroundColor: FormaColors.of(context).bgSunken,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: CloseButton(onPressed: _close),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(CaptureUiState state) {
    if (state.error != null) {
      return _buildError(state.error!);
    }
    if (state.isReconstructing) {
      return ReconstructionPanel(progress: state.reconstructionProgress);
    }
    return _buildCapture(state);
  }

  Widget _buildCapture(CaptureUiState state) {
    final colors = FormaColors.of(context);
    final isCapturing = state.phase == CapturePhase.capturing;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AnimatedSwitcher(
                duration: Motion.snappy,
                child: Text(
                  _hintFor(state),
                  key: ValueKey(_hintFor(state)),
                  textAlign: TextAlign.center,
                  style: AppTypography.headline.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          if (_showsStartButton(state))
            ScaleTransition(
              scale: Tween<double>(begin: 1, end: 1.05).animate(
                CurvedAnimation(parent: _pulse, curve: Motion.curvePulse),
              ),
              child: _buildStartButton(),
            )
          else if (isCapturing)
            _buildFinishButton(),
        ],
      ),
    );
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
