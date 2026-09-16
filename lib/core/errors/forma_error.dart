/// Forma's single error hierarchy (rules.md §7).
///
/// Native errors arrive as `PlatformException` and are mapped here at the
/// bridge boundary. [userMessage] is always safe to display.
sealed class FormaError implements Exception {
  const FormaError(this.userMessage, {this.debugMessage});

  /// Safe, human-facing message.
  final String userMessage;

  /// Technical detail for logging only — never shown to users.
  final String? debugMessage;

  @override
  String toString() =>
      'FormaError: $userMessage'
      '${debugMessage == null ? '' : ' | $debugMessage'}';
}

/// Device cannot scan (no LiDAR / unsupported OS).
class UnsupportedDeviceError extends FormaError {
  const UnsupportedDeviceError([String? debug])
      : super(
          'Forma needs a Pro iPhone with LiDAR to scan.',
          debugMessage: debug,
        );
}

/// ObjectCaptureSession failed.
class CaptureError extends FormaError {
  const CaptureError([String? debug])
      : super('Capture failed.', debugMessage: debug);
}

/// Camera permission was denied (native code 1005).
class CameraPermissionError extends FormaError {
  const CameraPermissionError([String? debug])
      : super(
          'Forma needs camera access to scan. Enable it in Settings.',
          debugMessage: debug,
        );
}

/// The native session never answered within the start timeout — the
/// camera is declared wedged instead of hanging on "Starting camera…".
class CameraTimeoutError extends FormaError {
  const CameraTimeoutError([String? debug])
      : super(
          'The camera did not start. Close and reopen the app, then try '
          'again.',
          debugMessage: debug,
        );
}

/// The device has less free space than Object Capture requires (~4 GB,
/// native code 1007). Apple fails the session instantly below that.
class StorageFullError extends FormaError {
  const StorageFullError([String? debug])
      : super(
          'Not enough free space to scan. Free up at least 4 GB and try '
          'again.',
          debugMessage: debug,
        );
}

/// PhotogrammetrySession failed.
class ReconstructionError extends FormaError {
  const ReconstructionError([String? debug])
      : super(
          'Could not build the 3D model. Try scanning again with '
          'more coverage.',
          debugMessage: debug,
        );
}

/// Export failed.
class ExportError extends FormaError {
  const ExportError([String? debug])
      : super('Export failed.', debugMessage: debug);
}

/// StoreKit / purchase failed.
class StoreError extends FormaError {
  const StoreError([String? debug])
      : super('Purchase could not be completed.', debugMessage: debug);
}

/// Native failed with a code we don't recognize.
class UnknownError extends FormaError {
  const UnknownError([String? debug])
      : super('Something went wrong. Please try again.', debugMessage: debug);
}
