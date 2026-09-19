import 'dart:io';

import 'package:flutter/material.dart';

import 'package:forma/core/models/scan.dart';
import 'package:forma/core/strings.dart';
import 'package:forma/design_system/tokens/app_colors.dart';
import 'package:forma/design_system/tokens/app_spacing.dart';
import 'package:forma/design_system/tokens/app_typography.dart';

/// Library grid tile — 3:4 thumbnail with a translucent info strip.
///
/// Per design.md §3.3; context menu lands in Phase 3.
///
/// Thumbnails load asynchronously with graceful fallback: a missing or
/// unreadable file shows the placeholder art instead of jank from sync
/// I/O on the UI thread.
class ScanCard extends StatefulWidget {
  /// Creates a card for [scan].
  const ScanCard({required this.scan, this.onTap, this.onDelete, super.key});

  /// The scan to render.
  final Scan scan;

  /// Opens the scan (its 360° model viewer).
  final VoidCallback? onTap;

  /// Deletes the scan; null hides the affordance.
  ///
  /// A visible button as well as a long press: a destructive action that can
  /// only be found by guessing is a destructive action users cannot reach
  /// (user request 2026-09-18: delete the models on the dashboard).
  final VoidCallback? onDelete;

  @override
  State<ScanCard> createState() => _ScanCardState();
}

class _ScanCardState extends State<ScanCard> {
  @override
  Widget build(BuildContext context) {
    final colors = FormaColors.of(context);
    final path = widget.scan.thumbnailPath;
    return Semantics(
      button: true,
      label: widget.scan.name,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onDelete,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: _buildTile(colors, path),
        ),
      ),
    );
  }

  Widget _buildTile(FormaColors colors, String? path) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (path != null)
            _ThumbnailImage(path: path)
          else
            _PlaceholderArt(colors: colors),
          if (widget.onDelete != null)
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: _DeleteButton(
                label: Strings.deleteScanLabel(widget.scan.name),
                onPressed: widget.onDelete!,
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: colors.bgElevated.withValues(alpha: 0.82),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.scan.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.subhead.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _formatDate(widget.scan.createdAt),
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small translucent delete button, overlaid on the card's thumbnail.
///
/// Deliberately quiet — it is a secondary action on a tile whose job is to be
/// opened — but always present, so removing a model never depends on knowing
/// a hidden gesture.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = FormaColors.of(context);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: colors.bgElevated.withValues(alpha: 0.72),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              Icons.delete_outline,
              size: 18,
              color: colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Decodes the thumbnail off the UI-critical path and falls back to the
/// placeholder art when the file cannot be loaded.
class _ThumbnailImage extends StatelessWidget {
  const _ThumbnailImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final colors = FormaColors.of(context);
    final file = File(path);
    return Image(
      image: FileImage(file),
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSync) {
        if (wasSync) {
          return child;
        }
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 120),
          child: child,
        );
      },
      errorBuilder: (context, error, stack) => _PlaceholderArt(colors: colors),
    );
  }
}

class _PlaceholderArt extends StatelessWidget {
  const _PlaceholderArt({required this.colors});

  final FormaColors colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.accentSoft, colors.bgSunken],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.view_in_ar,
          size: 48,
          color: colors.textTertiary.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final month = switch (date.month) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'May',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Aug',
    9 => 'Sep',
    10 => 'Oct',
    11 => 'Nov',
    _ => 'Dec',
  };
  return '$month ${date.day}';
}
