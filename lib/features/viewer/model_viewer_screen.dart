import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:forma/core/errors/forma_error.dart';
import 'package:forma/core/models/scan.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/core/strings.dart';
import 'package:forma/design_system/components/empty_state.dart';
import 'package:forma/design_system/haptics/app_haptics.dart';
import 'package:forma/design_system/tokens/app_colors.dart';
import 'package:forma/design_system/tokens/app_spacing.dart';
import 'package:forma/design_system/tokens/app_typography.dart';
import 'package:forma/features/viewer/widgets/model_preview.dart';
import 'package:forma/platform/native_bridge/native_bridge.dart';

/// Full-screen 360° viewer for a finished scan's model.
///
/// The model is rendered natively (RealityKit) with the phone's own gestures
/// for orbit and zoom, so the finished scan is actually inspectable from every
/// side instead of only existing as a file in the container.
class ModelViewerScreen extends ConsumerStatefulWidget {
  /// Creates a viewer for [scan].
  const ModelViewerScreen({required this.scan, super.key});

  /// The scan whose model is shown.
  final Scan scan;

  @override
  ConsumerState<ModelViewerScreen> createState() => _ModelViewerScreenState();
}

class _ModelViewerScreenState extends ConsumerState<ModelViewerScreen> {
  /// Whether the model file is on disk.
  ///
  /// Checked once, synchronously: it is a single `stat` on a path we already
  /// hold, and the alternative (an async check plus a spinner frame) only
  /// delays the honest answer for the common case of a missing file.
  late final bool _hasModel = _modelExists();

  /// The viewer's magnification, as reported by the native renderer.
  ///
  /// Read from native rather than counted here so the number follows a pinch
  /// as well as the buttons — and so a zoom command that never arrives shows
  /// as a level that never moves, instead of leaving the user to guess
  /// whether the gesture or the app is at fault.
  double _zoomFactor = 1;

  StreamSubscription<double>? _zoomSub;

  @override
  void initState() {
    super.initState();
    _zoomSub = ref.read(nativeBridgeProvider).modelZoomUpdates.listen((factor) {
      if (mounted) {
        setState(() => _zoomFactor = factor);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_zoomSub?.cancel());
    super.dispose();
  }

  bool _modelExists() {
    final path = widget.scan.modelPath;
    if (path == null) {
      return false;
    }
    try {
      return File(path).existsSync();
    } on FileSystemException {
      return false;
    }
  }

  /// Whether this platform can host the native viewer at all. Other hosts
  /// (dev machines, widget tests) say so honestly instead of showing black.
  bool get _viewerSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Leaves the viewer, back to whatever opened it.
  void _pop() {
    AppHaptics.tap();
    Navigator.of(context).pop();
  }

  Future<void> _resetView() => _run((bridge) => bridge.resetModelView());

  /// Zooms via the native viewer.
  ///
  /// Pinch is the gesture people reach for, and it does work — but a lost
  /// gesture must never leave the user unable to zoom at all, so the zoom is
  /// also a button (device-test finding 2026-09-18: the model could be
  /// rotated but not zoomed).
  Future<void> _zoom(double scale) =>
      _run((bridge) => bridge.zoomModelView(scale));

  /// One step of the zoom buttons — a step big enough to be unmistakable, so
  /// the button doing nothing and the button working are never confused.
  void _zoomStep(double scale) => unawaited(_zoom(scale));

  Future<void> _run(Future<void> Function(NativeBridge bridge) action) async {
    AppHaptics.tap();
    try {
      await action(ref.read(nativeBridgeProvider));
    } on FormaError catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.userMessage),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = FormaColors.of(context);
    final path = widget.scan.modelPath;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_hasModel && _viewerSupported && path != null)
            ModelPreview(modelPath: path),
          if (_hasModel && !_viewerSupported)
            const EmptyState(
              icon: Icons.view_in_ar_outlined,
              title: Strings.modelMissingTitle,
              subtitle: Strings.modelViewerIosOnly,
            ),
          if (!_hasModel)
            const EmptyState(
              icon: Icons.view_in_ar_outlined,
              title: Strings.modelMissingTitle,
              subtitle: Strings.modelMissingSubtitle,
            ),
          // A viewer that cannot show the model still has to let the user
          // leave: the message screens replace the chrome, so each carries its
          // own back button (user request 2026-09-18).
          if (!(_hasModel && _viewerSupported))
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: _PillIconButton(
                    icon: Icons.arrow_back,
                    semanticLabel: Strings.back,
                    onPressed: _pop,
                  ),
                ),
              ),
            ),
          if (_hasModel && _viewerSupported)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  children: [
                    _buildTopBar(colors),
                    const Spacer(),
                    // Zoom sits above the hint, on the thumb side of the
                    // screen, where a right-handed grip reaches it.
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildZoomControls(colors),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildGestureHint(colors),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(FormaColors colors) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _PillIconButton(
            icon: Icons.arrow_back,
            semanticLabel: Strings.back,
            onPressed: _pop,
          ),
          Flexible(
            child: Text(
              widget.scan.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.subhead.copyWith(color: colors.textPrimary),
            ),
          ),
          _PillIconButton(
            icon: Icons.threed_rotation,
            semanticLabel: Strings.resetView,
            onPressed: _resetView,
          ),
        ],
      );

  Widget _buildZoomControls(FormaColors colors) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildZoomLevel(colors),
          const SizedBox(height: AppSpacing.md),
          _HoldButton(
            icon: Icons.add,
            semanticLabel: Strings.zoomIn,
            onStep: () => _zoomStep(1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          _HoldButton(
            icon: Icons.remove,
            semanticLabel: Strings.zoomOut,
            onStep: () => _zoomStep(1 / 1.4),
          ),
        ],
      );

  /// The current magnification. Proof the zoom is doing something, and the
  /// only way to tell a pinch that native ignored from one the app never saw.
  Widget _buildZoomLevel(FormaColors colors) => Semantics(
        label: Strings.zoomLevel(_zoomFactor),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: colors.bgElevated.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(
            Strings.zoomLevel(_zoomFactor),
            style: AppTypography.caption.copyWith(color: colors.textPrimary),
          ),
        ),
      );

  Widget _buildGestureHint(FormaColors colors) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: colors.bgElevated.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          Strings.modelViewerHint,
          textAlign: TextAlign.center,
          style: AppTypography.headline.copyWith(color: colors.textPrimary),
        ),
      );
}

/// A zoom button that keeps stepping while it is held down.
///
/// The viewer's zoom range is wide on purpose (the object can be pulled right
/// up to the camera), and reaching the far end a tap at a time is tedious —
/// holding the button walks it there.
class _HoldButton extends StatefulWidget {
  const _HoldButton({
    required this.icon,
    required this.semanticLabel,
    required this.onStep,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onStep;

  @override
  State<_HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<_HoldButton> {
  /// Delay before the hold starts repeating, so a plain tap steps once.
  static const _holdDelay = Duration(milliseconds: 320);
  static const _repeatEvery = Duration(milliseconds: 90);

  Timer? _startTimer;
  Timer? _repeatTimer;

  void _press() {
    widget.onStep();
    _cancel();
    _startTimer = Timer(_holdDelay, () {
      _repeatTimer = Timer.periodic(_repeatEvery, (_) => widget.onStep());
    });
  }

  void _cancel() {
    _startTimer?.cancel();
    _startTimer = null;
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = FormaColors.of(context);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: Material(
        color: colors.bgElevated.withValues(alpha: 0.72),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTapDown: (_) => _press(),
          onTapUp: (_) => _cancel(),
          onTapCancel: _cancel,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(widget.icon, size: 22, color: colors.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Blurred circular icon button, matching the capture screen's chrome.
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
