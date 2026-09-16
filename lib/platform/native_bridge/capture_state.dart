/// Capture session states, mirroring `ObjectCaptureSession.stateUpdates`
/// on the native side (see architecture.md §3).
enum CapturePhase {
  /// Session is spinning up.
  initializing,

  /// Waiting for the user to aim at the object.
  ready,

  /// Looking for the object boundary.
  detecting,

  /// Frames are being captured.
  capturing,

  /// User tapped finish; session is wrapping up.
  finishing,

  /// Capture completed; images are ready for reconstruction.
  completed,

  /// Capture failed.
  failed,
}

/// Capture guidance feedback, mirroring `session.feedbackUpdates`.
enum CaptureFeedbackType {
  /// No active feedback.
  none,

  /// Object is too close to the camera.
  objectTooClose,

  /// Object is too far from the camera.
  objectTooFar,

  /// Camera is moving too fast.
  movingTooFast,

  /// Object is out of the field of view.
  outOfFieldOfView,
}

/// A guidance feedback event.
class CaptureFeedback {
  /// Creates a feedback event.
  const CaptureFeedback(this.type);

  /// The feedback kind.
  final CaptureFeedbackType type;
}

/// A native-side error event.
class BridgeError {
  /// Creates a bridge error.
  const BridgeError({required this.code, required this.message});

  /// Native error code.
  final int code;

  /// Human-readable description.
  final String message;
}
