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

/// How hard a scan is allowed to work (mirrors Swift `ScanProfile`).
///
/// The single knob behind "make a scan take two minutes instead of twenty".
/// A profile bounds three real costs at once: how many frames the capture may
/// keep, how large the images handed to reconstruction are, and how hard the
/// reconstruction looks for features.
///
/// It exists because on-device reconstruction is, measurably, a pixel-count
/// problem and Apple leaves almost nothing to trade away — `Request.Detail`
/// is `.reduced`-only on iOS — so the only lever left is *which and how many*
/// images go in (user request 2026-09-20: scanning a small object took
/// 20–25 minutes).
enum ScanProfile {
  /// Pay for speed: a small object, a phone screen, a quick turnaround.
  quick,

  /// The default — a good model without a long wait.
  balanced,

  /// Pay for detail: texture-rich objects that reward a closer look.
  detail;

  /// Roughly how long a whole scan takes, for the picker.
  ///
  /// Deliberately coarse: the number exists to set the expectation *before*
  /// the scan starts, and a promise in seconds is one this app cannot keep.
  int get approximateMinutes => switch (this) {
        ScanProfile.quick => 2,
        ScanProfile.balanced => 5,
        ScanProfile.detail => 10,
      };
}

/// Coverage progress while a capture is running.
///
/// [shots] is how many frames Object Capture has kept so far; [passComplete]
/// flips to true once it has captured enough to fill its dial from a full
/// circle around the object — the session's own "every side is covered"
/// milestone. Both drive the capture guidance, so the user is told which
/// sides still need scanning instead of re-scanning a finished one.
///
/// [targetShots] and [maxShots] are the scan profile's frame budget:
/// [targetShots] is when the scan has enough, [maxShots] when the session
/// ends the capture by itself. Together they are what makes the length of a
/// scan predictable instead of a function of how long the user keeps walking.
class CaptureProgress {
  /// Creates a progress snapshot.
  const CaptureProgress({
    required this.shots,
    required this.passComplete,
    this.targetShots = 0,
    this.maxShots = 0,
    this.budgetReached = false,
    this.canCapture = false,
  });

  /// No progress reported yet.
  static const empty = CaptureProgress(shots: 0, passComplete: false);

  /// Frames kept by the session so far.
  final int shots;

  /// Whether the session has completed a full scan pass.
  final bool passComplete;

  /// The frame count the profile aims for, or 0 when native has not said.
  final int targetShots;

  /// The frame count at which the session ends the capture, or 0 when
  /// native has not said.
  final int maxShots;

  /// The frame budget has ended this capture, so no more frames are coming.
  final bool budgetReached;

  /// Whether the session can take a manual frame right now.
  ///
  /// Read from `ObjectCaptureSession.canRequestImageCapture`, which is the
  /// only thing that knows: a manual request is silently ignored in any other
  /// state, so the guided shutter follows this rather than the phase. A
  /// button that greys out honestly beats a tap that vanishes.
  final bool canCapture;
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

/// What RealityKit is doing right now, and how long it thinks is left.
///
/// Both values come from Apple (`requestProgressInfo`), never from us: the
/// stage is the real pipeline step and the estimate is the session's own. The
/// wire stages are tokens (`aligning`, `mesh`, …) so the wording stays in
/// `Strings` with the rest of the UI copy.
class ReconstructionStage {
  /// Creates a stage update.
  const ReconstructionStage({required this.stage, this.remainingSeconds});

  /// Pipeline step: preprocessing, aligning, points, mesh, texture,
  /// optimizing, or working when Apple reports a step we have no name for.
  final String stage;

  /// Apple's estimate of the seconds left, or null while it has none yet
  /// (early in a build it returns nil).
  final int? remainingSeconds;
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
