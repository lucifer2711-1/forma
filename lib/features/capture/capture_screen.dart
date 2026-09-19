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
import 'package:forma/features/capture/coverage/capture_steps.dart';
import 'package:forma/features/capture/coverage/coverage_guidance.dart';
import 'package:forma/features/capture/widgets/camera_health_overlay.dart';
import 'package:forma/features/capture/widgets/camera_preview.dart';
import 'package:forma/features/capture/widgets/capture_step_bar.dart';
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
      // It carries its own back button: this layer replaces the live chrome,
      // and a failure screen whose only option is "Try again" traps the user
      // on a camera that is refusing to work (user request 2026-09-18: be
      // able to go back from every option).
      return SafeArea(
        child: ColoredBox(
          color:
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _PillIconButton(
                    icon: Icons.arrow_back,
                    semanticLabel: Strings.back,
                    onPressed: _close,
                  ),
                ),
                Expanded(child: Center(child: _buildError(state.error!))),
              ],
            ),
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
              // Only before a capture starts: once frames are landing the
              // speed is no longer a decision the user is making, and the
              // bottom of the screen belongs to the shutter.
              if (_showsStartButton(state)) _buildProfilePicker(state),
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
          Semantics(
            toggled: state.isTorchOn,
            child: _PillIconButton(
              icon: state.isTorchOn
                  ? Icons.flashlight_on
                  : Icons.flashlight_off_outlined,
              semanticLabel: Strings.torchLabel,
              isActive: state.isTorchOn,
              onPressed: () => unawaited(
                ref.read(captureViewModelProvider.notifier).toggleTorch(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusText(CaptureUiState state) {
    if (state.isReconstructing) {
      return ReconstructionPanel(
        progress: state.reconstructionProgress,
        stage: state.reconstructionStage,
        secondsRemaining: state.reconstructionSecondsRemaining,
      );
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
            // Against a target when native has reported one: "18 of 35
            // photos" answers "how much longer?" on the first frame, which a
            // count that only ever grows never does (user request 2026-09-20:
            // a small object was taking 20-25 minutes).
            state.targetShots > 0
                ? Strings.shotsOfTarget(state.shots, state.targetShots)
                : Strings.photosCaptured(state.shots),
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
          // The guided walk, one named side at a time. Tapping a side asks
          // for it next, which is the user's escape hatch from the order
          // rather than a rule they are stuck with.
          CaptureStepBar(
            plan: state.stepPlan,
            onSelect: (id) =>
                ref.read(captureViewModelProvider.notifier).focusStep(id),
          ),
          if (state.stepPlan.isAnchored) const SizedBox(height: AppSpacing.sm),
          _buildStepActions(state),
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
          // The shutter sits beside the primary action: the tap the user was
          // asked for, and the button that ends the scan, in one place.
          Row(
            children: [
              _buildShutter(state),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _buildFinishButton(state)),
            ],
          ),
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
        child: _buildStartButton(state),
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

  /// The scan-speed picker, shown before a capture starts.
  ///
  /// It lives on this screen rather than behind settings because it is the
  /// decision the user is actually making at that moment — "how long is this
  /// going to take?" — and because the honest answer to "why is scanning
  /// slow?" is to let them choose the trade before they spend the time
  /// (user request 2026-09-20).
  Widget _buildProfilePicker(CaptureUiState state) {
    final colors = FormaColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Strings.scanSpeedTitle,
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final profile in ScanProfile.values) ...[
                _buildProfileChip(profile, state.profile),
                if (profile != ScanProfile.values.last)
                  const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileChip(ScanProfile profile, ScanProfile selected) {
    final colors = FormaColors.of(context);
    final isSelected = profile == selected;
    final label = _profileLabel(profile);
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label, ${Strings.profileMinutes(profile.approximateMinutes)}',
      child: Material(
        color: isSelected
            ? colors.accent
            : colors.bgElevated.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(
            ref.read(captureViewModelProvider.notifier).selectProfile(profile),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTypography.headline.copyWith(
                    color: isSelected ? Colors.white : colors.textPrimary,
                  ),
                ),
                Text(
                  Strings.profileMinutes(profile.approximateMinutes),
                  style: AppTypography.caption.copyWith(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.85)
                        : colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The picker's label for a profile.
  ///
  /// Mapped here rather than on [ScanProfile] so the wire enum stays a wire
  /// enum and every user-facing word stays in `Strings` (rules.md §2).
  String _profileLabel(ScanProfile profile) => switch (profile) {
        ScanProfile.quick => Strings.profileQuickLabel,
        ScanProfile.balanced => Strings.profileBalancedLabel,
        ScanProfile.detail => Strings.profileDetailLabel,
      };

  /// The capture CTA.
  ///
  /// It is relabelled during the flipped second pass, because that pass is not
  /// "start a scan" — it is the one side the user could not walk to, and saying
  /// so is the difference between a button they understand and one they have to
  /// guess at.
  Widget _buildStartButton(CaptureUiState state) => PrimaryButton(
        label: state.isUndersidePass
            ? Strings.scanUnderside
            : Strings.scanCta,
        onPressed: () {
          AppHaptics.tap();
          unawaited(
            ref.read(captureViewModelProvider.notifier).startOrBegin(),
          );
        },
      );

  /// The manual shutter for the side the walk just asked for.
  ///
  /// This is a real capture (`requestImageCapture`), so the button is only
  /// enabled when the session says it can take a frame — `canCapture` comes
  /// straight from `ObjectCaptureSession.canRequestImageCapture`, and a tap in
  /// any other state is silently ignored by the OS. A greyed shutter is an
  /// honest "hold steady", where a tap that vanishes is a bug report.
  Widget _buildShutter(CaptureUiState state) {
    final colors = FormaColors.of(context);
    final isEnabled = state.canCapture && !state.isFrameRequestPending;
    return Semantics(
      button: true,
      enabled: isEnabled,
      label: Strings.shutterLabel,
      child: Material(
        color: isEnabled
            ? colors.accent
            : colors.bgElevated.withValues(alpha: 0.72),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isEnabled
              ? () => unawaited(
                    ref.read(captureViewModelProvider.notifier).captureStep(),
                  )
              : null,
          child: SizedBox(
            width: 60,
            height: 60,
            child: Icon(
              Icons.camera_alt,
              size: 26,
              color: isEnabled ? Colors.white : colors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }

  /// Skip and flip, the two ways out of a side.
  ///
  /// Skip exists because a checklist nobody can satisfy is worse than no
  /// checklist: an object that cannot be turned over has no underside, and the
  /// user has to be able to say so rather than circle forever (gotcha 35).
  /// Flip is the deliberate second pass for the side that is *not* out of
  /// reach, only out of sight.
  Widget _buildStepActions(CaptureUiState state) {
    if (!state.stepPlan.isAnchored) {
      return const SizedBox.shrink();
    }
    final current = state.stepPlan.currentId;
    if (current == null) {
      return const SizedBox.shrink();
    }
    final isUnderside = current == CaptureStepId.underside;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isUnderside && !state.isUndersidePass)
          TextButton(
            onPressed: () => unawaited(
              ref
                  .read(captureViewModelProvider.notifier)
                  .beginUndersidePass(),
            ),
            child: const Text(Strings.flipAndScan),
          ),
        TextButton(
          onPressed: () =>
              ref.read(captureViewModelProvider.notifier).skipStep(),
          child: const Text(Strings.skipSide),
        ),
      ],
    );
  }

  /// Finish, relabelled once the scan is complete.
  ///
  /// The word matters: while coverage is still missing, "Finish" is a guess
  /// the user has to make. Once every side is captured the same button says
  /// "Build model now", which is the app telling them to stop — the single
  /// cheapest way to make a scan take less time (user request 2026-09-18).
  Widget _buildFinishButton(CaptureUiState state) => PrimaryButton(
        label: state.hasEnoughCoverage
            ? Strings.buildNow
            : Strings.finishCapture,
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
        // The frame cap has ended this capture; asking for more frames the
        // session will never take would be a lie about what is happening.
        if (state.hasReachedShotBudget) {
          return Strings.shotBudgetHint;
        }
        // The guided walk leads, because it is the most specific guidance
        // there is: one named side, in the user's own frame of reference,
        // instead of a band name they have to translate into a direction to
        // walk. It is also what makes the scan short — six known steps with a
        // visible end, rather than a lap the user has to judge for themselves
        // (user request 2026-09-20).
        if (state.stepPlan.isAnchored) {
          final step = state.stepPlan.currentId;
          if (step == null) {
            return Strings.guidedCompleteHint;
          }
          return sideHint(step);
        }
        // Before anything is on the card there is no side to name yet, and the
        // one thing worth saying is how to start the walk.
        //
        // Deliberately not "no directions have arrived": a scan that has kept
        // frames without reporting directions is a device that cannot guide by
        // bearing, and that case falls through to the band guidance below,
        // which needs no bearing to be useful.
        if (state.directions.isEmpty && state.shots == 0) {
          return Strings.guidedStartHint;
        }
        // The guidance narrows as the scan fills in, because each extra lap
        // costs the user time and adds nothing. In order: keep circling →
        // name the exact sides still missing → tell them to stop.
        if (state.hasEnoughCoverage) {
          return state.isOnlyUndersideMissing
              ? Strings.undersideOptionalHint
              : Strings.enoughCoverageHint;
        }
        if (state.isScanPassComplete && state.coverage.hasData) {
          return Strings.stillToScanHint(
            joinCoverageBandNames(state.missingReachableBands),
          );
        }
        // Apple's own milestone but no direction data to narrow it down with:
        // the sides a single circle always misses are the top and underside.
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
    this.isActive = false,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  /// Renders the button as a lit toggle (the torch's on state) rather than a
  /// neutral action, so "the light is on" is visible without reading an icon.
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = FormaColors.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: isActive
            ? colors.accent
            : colors.bgElevated.withValues(alpha: 0.72),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 22,
              color: isActive ? Colors.white : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
