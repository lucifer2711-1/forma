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

  Future<void> _resetView() async {
    AppHaptics.tap();
    try {
      await ref.read(nativeBridgeProvider).resetModelView();
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
          if (_hasModel && _viewerSupported)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  children: [
                    _buildTopBar(colors),
                    const Spacer(),
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
            icon: Icons.close,
            semanticLabel: Strings.close,
            onPressed: () {
              AppHaptics.tap();
              Navigator.of(context).pop();
            },
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
