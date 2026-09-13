import 'package:flutter/animation.dart';

/// Motion timing tokens for Forma.
///
/// Every animation in the app must reference one of these constants —
/// never define ad-hoc durations or curves inline. See design.md §5.1.
abstract final class Motion {
  /// Quick, tight interaction (button presses, small transitions).
  static const Curve snappyCurve = Curves.easeOutCubic;

  /// Standard spring feel for most UI movement.
  static const Duration snappy = Duration(milliseconds: 280);

  /// Smooth, slightly slower transitions (sheets, cards).
  static const Duration smooth = Duration(milliseconds: 420);

  /// Playful overshoot for celebrations (purchase, reveal).
  static const Duration bouncy = Duration(milliseconds: 550);

  /// Gentle crossfades and color shifts.
  static const Duration gentle = Duration(milliseconds: 300);

  /// Long cinematic moments (model reveal, onboarding).
  static const Duration cinematic = Duration(milliseconds: 900);

  /// Micro feedback (scale-on-press, icon toggles).
  static const Duration micro = Duration(milliseconds: 150);

  /// Standard curve for most animations.
  static const Curve curve = Curves.easeOutCubic;

  /// Overshooting curve for celebratory moments.
  static const Curve curveBouncy = Curves.easeOutBack;
}
