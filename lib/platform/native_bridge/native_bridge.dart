import 'package:forma/platform/native_bridge/capture_state.dart';

/// The single seam between the Flutter UI and native iOS (Swift).
///
/// All communication with `ObjectCaptureSession`, `PhotogrammetrySession`,
/// and Model I/O export flows through this interface. The UI and view models
/// must never import platform channels directly — they depend on this
/// contract. The sole implementation is `IosNativeBridge`, backed by the
/// Swift `NativeModule` via `com.forma.app/*` channels.
///
/// See architecture.md §3 for the full channel contract.
abstract interface class NativeBridge {
  /// Whether this device can scan (`PhotogrammetrySession.isSupported`).
  Future<bool> isScanSupported();

  /// Starts an `ObjectCaptureSession` and returns the scan id.
  Future<String> startCapture();

  /// Advances the session from detection into image capture.
  Future<void> beginCapturing(String scanId);

  /// Finishes capture and begins reconstruction for [scanId].
  Future<void> finishCapture(String scanId);

  /// Runs photogrammetry reconstruction for a completed capture.
  Future<void> startReconstruction(String scanId);

  /// Cancels the active capture session, discarding captured images.
  Future<void> cancelCapture(String scanId);

  /// Exports the finished model to the given [format]; returns the file path.
  Future<String> exportModel(String scanId, ExportFormat format);

  /// Whether a native capture session is currently alive (camera-health
  /// probe used by the capture watchdog).
  Future<bool> hasActiveCaptureSession();

  /// The native capture session's current phase name, or "none" when no
  /// session exists. Distinguishes a dead session from one still waiting
  /// for ARKit tracking to initialize (lighting/texture guidance case).
  Future<String> getSessionState();

  /// Returns every mounted model viewer to its framing position (the 360°
  /// viewer's "reset view" affordance).
  Future<void> resetModelView();

  /// Multiplies the 360° viewer's zoom by [scale] (> 1 zooms in).
  ///
  /// Pinch is the primary gesture; this backs the on-screen zoom controls,
  /// which work even where a native gesture cannot be delivered.
  Future<void> zoomModelView(double scale);

  /// The 360° viewer's magnification after every change (1 = framed).
  ///
  /// Reported by native, so the level readout follows a pinch as well as
  /// the buttons — and so a zoom command that never arrives is visible
  /// instead of silent.
  Stream<double> get modelZoomUpdates;

  /// Directions the object has been scanned from, for the coverage globe.
  ///
  /// Emits one sample per frame Object Capture keeps, plus a throttled live
  /// sample of where the phone is pointed right now.
  Stream<ScanDirection> get scanDirectionUpdates;

  /// Switches the capture preview between the live camera feed ([enabled]
  /// false) and the captured point cloud (`true`).
  ///
  /// The point cloud is the coverage check: geometry the session has
  /// captured, with the shots taken marked on it — holes are the sides
  /// still to scan.
  Future<void> setCaptureReviewMode({required bool enabled});

  /// Turns the capture screen's rear torch on ([enabled] true) or off.
  ///
  /// Driven directly on the rear camera, since `ObjectCaptureSession` owns
  /// the camera but exposes no torch control (master spec §4.2). A device
  /// without a torch is not an error: the request is simply a no-op.
  Future<void> setTorch({required bool enabled});

  /// Captures one frame where the phone is aimed right now.
  ///
  /// This is what makes the guided side-by-side walk a tap: the app asks for
  /// a named side, the user aims at it and presses the shutter. Apple's own
  /// `requestImageCapture()`, and the frame lands in the same image set the
  /// automatic capture writes to — so a deliberate tap adds coverage rather
  /// than replacing it.
  ///
  /// Throws when the session is not capturing or is not ready for a frame
  /// (native code 1006/1011); the UI mirrors readiness through
  /// [CaptureProgress.canCapture] so the tap is never unknowingly dropped.
  Future<void> requestImageCapture(String scanId);

  /// Starts a new capture pass after the object has been flipped over.
  ///
  /// The underside of an object resting on a surface cannot be walked to, and
  /// this is Apple's answer: shoot the side facing up, pause, turn the object
  /// over, then call this. The frames land in the same directory, so
  /// reconstruction stitches both passes into one model with a real bottom
  /// (`ObjectCaptureSession.beginNewScanPassAfterFlip()`).
  Future<void> beginPassAfterFlip(String scanId);

  /// Sets how hard the active scan is allowed to work.
  ///
  /// Takes effect immediately: the profile decides the frame budget the
  /// capture session is held to and the size of the images reconstruction is
  /// given, which is what makes a scan take two minutes instead of twenty
  /// (user request 2026-09-20). Safe to call before a session exists — the
  /// value is kept for the next scan.
  Future<void> setScanProfile(ScanProfile profile);

  /// Deletes every file Forma wrote for [scanId] — its source images, the
  /// reconstructed model, and any exports.
  ///
  /// The library row is removed separately by the repository, so a scan the
  /// user deletes actually reclaims its disk space instead of only vanishing
  /// from the dashboard.
  Future<void> deleteScan(String scanId);

  /// Continuous capture phase updates.
  Stream<CapturePhase> get phaseUpdates;

  /// Continuous guidance feedback updates.
  Stream<CaptureFeedback> get feedbackUpdates;

  /// Coverage progress while capturing (shots kept, pass completed).
  Stream<CaptureProgress> get captureProgressUpdates;

  /// Reconstruction progress from 0.0 to 1.0.
  Stream<double> get reconstructionProgressUpdates;

  /// Reconstruction stage updates, with RealityKit's own estimate of the
  /// seconds remaining.
  ///
  /// A bare percentage cannot answer "how long is this going to take?", which
  /// is what makes a build feel endless. Apple's stage and ETA can.
  Stream<ReconstructionStage> get reconstructionStageUpdates;

  /// Reconstruction completion; emits the model file path.
  Stream<String> get reconstructionCompleteUpdates;

  /// Native error events.
  Stream<BridgeError> get errorUpdates;

  /// Releases native resources.
  void dispose();
}

/// Export formats supported by Forma.
enum ExportFormat { usdz, obj, stl }
