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

  /// The scene is too dark for Object Capture to read.
  ///
  /// Reported by the session (`Feedback.environmentLowLight`) and previously
  /// thrown away, which left the user with a scan that never progressed and
  /// no reason why (device-test finding 2026-09-18).
  environmentLowLight,

  /// The session cannot find an object to scan yet.
  objectNotDetected,
}

/// A guidance feedback event.
class CaptureFeedback {
  /// Creates a feedback event.
  const CaptureFeedback(this.type);

  /// The feedback kind.
  final CaptureFeedbackType type;
}

/// Coverage progress while a capture is running.
///
/// [shots] is how many frames Object Capture has kept so far; [passComplete]
/// flips to true once it has captured enough to fill its dial from a full
/// circle around the object — the session's own "every side is covered"
/// milestone. Both drive the capture guidance, so the user is told which
/// sides still need scanning instead of re-scanning a finished one.
class CaptureProgress {
  /// Creates a progress snapshot.
  const CaptureProgress({required this.shots, required this.passComplete});

  /// No progress reported yet.
  static const empty = CaptureProgress(shots: 0, passComplete: false);

  /// Frames kept by the session so far.
  final int shots;

  /// Whether the session has completed a full scan pass.
  final bool passComplete;
}

/// A direction on the scan globe: the object's surface that was facing the
/// phone, as a unit vector in native's gravity-aligned frame (z is up).
///
/// [isKept] separates the two signals the bridge carries on one event: a
/// direction Object Capture actually kept a frame for (a finished side) and
/// the phone's live aim (the "you are here" marker).
class ScanDirection {
  /// Creates a direction.
  const ScanDirection({
    required this.x,
    required this.y,
    required this.z,
    this.isKept = true,
  });

  /// X component (horizontal).
  final double x;

  /// Y component (horizontal).
  final double y;

  /// Z component (vertical — gravity-up, the axis the top/bottom bands use).
  final double z;

  /// Whether a frame was kept for this direction.
  final bool isKept;

  /// Dot product with [other] — 1 when the two point the same way.
  double dot(ScanDirection other) => x * other.x + y * other.y + z * other.z;

  /// Squared length; 1 for a unit vector.
  double get squaredLength => x * x + y * y + z * z;

  /// Whether the vector is usable (native normalises, so this only rejects
  /// a zero/invalid sample).
  bool get isUsable => squaredLength > 0.25;

  @override
  String toString() =>
      'ScanDirection(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, '
      '${z.toStringAsFixed(2)}${isKept ? '' : ', live'})';
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
