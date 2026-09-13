import 'package:flutter/material.dart';

/// Semantic color tokens for Forma. Light values per design.md Â§1.1.
///
/// Dark-mode values live in [FormaColors.dark].
@immutable
class FormaColors extends ThemeExtension<FormaColors> {
  const FormaColors({
    required this.bg,
    required this.bgElevated,
    required this.bgSunken,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.separator,
  });

  /// Base background.
  final Color bg;

  /// Cards and sheets.
  final Color bgElevated;

  /// Wells and recessed areas.
  final Color bgSunken;

  /// Primary body text.
  final Color textPrimary;

  /// Subheads and secondary text.
  final Color textSecondary;

  /// Captions and tertiary text.
  final Color textTertiary;

  /// Brand accent (warm orange â€” differentiates from Polycam blue).
  final Color accent;

  /// Soft tint of the accent.
  final Color accentSoft;

  /// Confirmations.
  final Color success;

  /// Alerts.
  final Color warning;

  /// Destructive actions.
  final Color danger;

  /// Dividers.
  final Color separator;

  /// Light theme tokens.
  static const light = FormaColors(
    bg: Color(0xFFFAFAF7),
    bgElevated: Color(0xFFFFFFFF),
    bgSunken: Color(0xFFF0F0EC),
    textPrimary: Color(0xFF0A0A0A),
    textSecondary: Color(0xFF6B6B70),
    textTertiary: Color(0xFFA0A0A6),
    accent: Color(0xFFFF6B35),
    accentSoft: Color(0xFFFFE7DC),
    success: Color(0xFF34C759),
    warning: Color(0xFFFF9F0A),
    danger: Color(0xFFFF3B30),
    separator: Color(0xFFE5E5EA),
  );

  /// Dark theme tokens (dark-first design).
  static const dark = FormaColors(
    bg: Color(0xFF0B0B0D),
    bgElevated: Color(0xFF16161A),
    bgSunken: Color(0xFF050506),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFF9A9AA1),
    textTertiary: Color(0xFF5F5F66),
    accent: Color(0xFFFF7A45),
    accentSoft: Color(0xFF3A1F13),
    success: Color(0xFF30D158),
    warning: Color(0xFFFFD60A),
    danger: Color(0xFFFF453A),
    separator: Color(0xFF2C2C2E),
  );

  /// Convenience accessor: `context.formaColors.accent`.
  static FormaColors of(BuildContext context) =>
      Theme.of(context).extension<FormaColors>() ?? light;

  @override
  FormaColors copyWith({
    Color? bg,
    Color? bgElevated,
    Color? bgSunken,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentSoft,
    Color? success,
    Color? warning,
    Color? danger,
    Color? separator,
  }) {
    return FormaColors(
      bg: bg ?? this.bg,
      bgElevated: bgElevated ?? this.bgElevated,
      bgSunken: bgSunken ?? this.bgSunken,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      separator: separator ?? this.separator,
    );
  }

  @override
  FormaColors lerp(FormaColors? other, double t) {
    if (other == null) {
      return this;
    }
    return FormaColors(
      bg: Color.lerp(bg, other.bg, t)!,
      bgElevated: Color.lerp(bgElevated, other.bgElevated, t)!,
      bgSunken: Color.lerp(bgSunken, other.bgSunken, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
    );
  }
}
