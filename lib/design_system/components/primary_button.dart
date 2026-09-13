import 'package:flutter/material.dart';

import 'package:forma/design_system/tokens/app_colors.dart';
import 'package:forma/design_system/tokens/app_spacing.dart';
import 'package:forma/design_system/tokens/motion.dart';

/// Forma's primary pill button â€” accent background, white label.
///
/// Per design.md §3.1: height 56, scale 0.97 on press, loading state
/// crossfades the label for a spinner.
class PrimaryButton extends StatefulWidget {
  /// Creates a primary button.
  const PrimaryButton({
    required this.label,
    this.onPressed,
    this.isLoading = false,
    super.key,
  });

  /// Button text.
  final String label;

  /// Called when tapped; null disables the button.
  final VoidCallback? onPressed;

  /// When true, shows an inline spinner instead of the label.
  final bool isLoading;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = FormaColors.of(context);
    final disabled = widget.onPressed == null || widget.isLoading;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: disabled ? null : () => widget.onPressed!(),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: Motion.micro,
        curve: Motion.curve,
        child: AnimatedOpacity(
          duration: Motion.micro,
          opacity: disabled ? 0.4 : 1,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: AnimatedSwitcher(
              duration: Motion.micro,
              child: widget.isLoading
                  ? SizedBox.square(
                      key: const ValueKey('loading'),
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colors.bgElevated,
                      ),
                    )
                  : Text(
                      widget.label,
                      key: const ValueKey('label'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vertical padding helper for consistent button margins.
const primaryButtonMargin = EdgeInsets.symmetric(
  horizontal: AppSpacing.lg,
  vertical: AppSpacing.sm,
);
