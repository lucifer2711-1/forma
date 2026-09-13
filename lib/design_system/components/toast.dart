import 'package:flutter/material.dart';

import 'package:forma/design_system/tokens/app_colors.dart';
import 'package:forma/design_system/tokens/app_spacing.dart';

/// Severity levels for the [Toast].
enum ToastSeverity { info, success, error }

/// Transient message overlay â€” surfaced via the Toast.show helper.
///
/// Per rules.md §7: recoverable errors degrade to a toast, never a crash.
class Toast extends StatelessWidget {
  /// Creates a toast.
  const Toast({
    required this.message,
    this.severity = ToastSeverity.info,
    super.key,
  });

  /// Message text.
  final String message;

  /// Visual severity.
  final ToastSeverity severity;

  /// Shows a toast overlay at the top of the screen and auto-dismisses it.
  static void show(
    BuildContext context,
    String message, {
    ToastSeverity severity = ToastSeverity.info,
  }) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastOverlay(
        message: message,
        severity: severity,
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final colors = FormaColors.of(context);
    final iconColor = switch (severity) {
      ToastSeverity.success => colors.success,
      ToastSeverity.error => colors.danger,
      ToastSeverity.info => colors.accent,
    };
    final icon = switch (severity) {
      ToastSeverity.success => Icons.check_circle,
      ToastSeverity.error => Icons.error,
      ToastSeverity.info => Icons.info,
    };

    return Material(
      color: colors.bgElevated,
      borderRadius: BorderRadius.circular(AppRadii.small),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textPrimary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToastOverlay extends StatefulWidget {
  const _ToastOverlay({
    required this.message,
    required this.severity,
    required this.onDismiss,
  });

  final String message;
  final ToastSeverity severity;
  final VoidCallback onDismiss;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 3), widget.onDismiss);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
      left: AppSpacing.lg,
      right: AppSpacing.lg,
      child: IgnorePointer(
        child: Toast(message: widget.message, severity: widget.severity),
      ),
    );
  }
}
