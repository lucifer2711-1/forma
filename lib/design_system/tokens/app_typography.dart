import 'package:flutter/material.dart';

/// Typography scale per design.md §1.2.
///
/// All styles use the platform default (SF Pro on iOS) and scale with
/// the system text scaler up to AX sizes.
abstract final class AppTypography {
  /// Display L — 40 bold (used with rounded feel on iOS).
  static const TextStyle displayL = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -1,
  );

  /// Display M — 32 semibold.
  static const TextStyle displayM = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.15,
    letterSpacing: -0.5,
  );

  /// Title — 24 semibold.
  static const TextStyle title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.3,
  );

  /// Headline — 17 semibold.
  static const TextStyle headline = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.2,
  );

  /// Body — 17 regular.
  static const TextStyle body = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: -0.2,
  );

  /// Callout — 16 regular.
  static const TextStyle callout = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: -0.2,
  );

  /// Subhead — 15 regular.
  static const TextStyle subhead = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.35,
    letterSpacing: -0.1,
  );

  /// Footnote — 13 regular.
  static const TextStyle footnote = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  /// Caption — 12 regular.
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );
}
