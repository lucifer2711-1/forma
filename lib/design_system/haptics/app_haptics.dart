import 'package:flutter/services.dart';

/// Centralized haptics (design.md §5.4 mapping — Flutter has no
/// notification-style generators, so we map: success→medium, error→heavy).
abstract final class AppHaptics {
  /// Button taps.
  static void tap() => HapticFeedback.lightImpact();

  /// Scan state transitions and guidance direction changes.
  static void stateChange() => HapticFeedback.mediumImpact();

  /// Capture / reconstruction / export completion.
  static void success() => HapticFeedback.mediumImpact();

  /// Failures.
  static void error() => HapticFeedback.heavyImpact();
}
