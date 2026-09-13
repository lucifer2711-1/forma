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

  /// Continuous capture phase updates.
  Stream<CapturePhase> get phaseUpdates;

  /// Continuous guidance feedback updates.
  Stream<CaptureFeedback> get feedbackUpdates;

  /// Reconstruction progress from 0.0 to 1.0.
  Stream<double> get reconstructionProgressUpdates;

  /// Reconstruction completion; emits the model file path.
  Stream<String> get reconstructionCompleteUpdates;

  /// Native error events.
  Stream<BridgeError> get errorUpdates;

  /// Releases native resources.
  void dispose();
}

/// Export formats supported by Forma.
enum ExportFormat { usdz, obj, stl }
