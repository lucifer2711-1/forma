import 'package:flutter/material.dart';

import 'package:forma/design_system/tokens/app_colors.dart';
import 'package:forma/design_system/tokens/app_typography.dart';

/// Builds the Forma [ThemeData] for light or dark mode.
///
/// Dark-first: dark values are the reference, light is equally loved.
ThemeData buildFormaTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colors = isDark ? FormaColors.dark : FormaColors.light;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: colors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.accent,
      brightness: brightness,
      primary: colors.accent,
      surface: colors.bgElevated,
      error: colors.danger,
    ),
    extensions: [colors],
    textTheme: const TextTheme(
      displayLarge: AppTypography.displayL,
      displayMedium: AppTypography.displayM,
      titleLarge: AppTypography.title,
      titleMedium: AppTypography.headline,
      bodyLarge: AppTypography.body,
      bodyMedium: AppTypography.callout,
      bodySmall: AppTypography.subhead,
      labelSmall: AppTypography.caption,
    ),
    dividerColor: colors.separator,
    splashFactory: InkSparkle.splashFactory,
  );
}
