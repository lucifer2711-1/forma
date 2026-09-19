import Flutter
import Foundation

/// Bridges native events to the Dart `capture_events` EventChannel.
///
/// Payloads match the Dart `IosNativeBridge._onEvent` contract:
/// `{"type": …, "value": …}`.
final class FormaEventSink: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?

  /// Called when Dart (re)subscribes, so the current capture state can be
  /// replayed into the fresh sink.
  ///
  /// Phase events are emitted for every session transition, but a transition
  /// that happens before Dart's `listen` reaches the platform is emitted into
  /// a nil sink and lost permanently — the session's `stateUpdates` is
  /// single-consumer and iterated once. Dart would then sit with a null phase
  /// while the session was already `.detecting` (device-test finding
  /// 2026-09-17: every Start Capture tap became a silent no-op).
  var onListenHandler: (() -> Void)?

  /// Emits are always delivered on the main thread.
  func emit(_ payload: [String: Any]) {
    let sink = self.sink
    DispatchQueue.main.async {
      sink?(payload)
    }
  }

  func emitPhase(_ name: String) {
    emit(["type": "phase", "value": name])
  }

  func emitFeedback(_ name: String) {
    emit(["type": "feedback", "value": name])
  }

  /// Coverage progress while capturing: how many frames the session has
  /// kept, and whether the user has completed a full scan pass.
  func emitCaptureProgress(shots: Int, passComplete: Bool) {
    emit([
      "type": "capture_progress",
      "value": ["shots": shots, "passComplete": passComplete],
    ])
  }

  /// The direction the object was last scanned from.
  ///
  /// `kept` distinguishes a direction Object Capture actually stored a frame
  /// from one that is only the phone's current aim: the first paints a
  /// finished side, the second moves a "you are here" marker. Both are the
  /// same vector (the surface of the object facing the phone), which is what
  /// makes the coverage globe legible.
  func emitScanDirection(
    x: Float,
    y: Float,
    z: Float,
    kept: Bool
  ) {
    // Doubles, not Floats: the standard message codec carries NSNumber as a
    // Double, and a bare Float is the kind of value it drops on the floor.
    emit([
      "type": "scan_direction",
      "value": [
        "x": Double(x),
        "y": Double(y),
        "z": Double(z),
        "kept": kept,
      ],
    ])
  }

  /// The 360° viewer's current magnification (1 = framed).
  func emitModelZoom(_ factor: Float) {
    emit(["type": "model_zoom", "value": Double(factor)])
  }

  func emitProgress(_ value: Double) {
    emit(["type": "reconstruction_progress", "value": value])
  }

  /// The reconstruction stage RealityKit is in, plus its own estimate of the
  /// seconds left.
  ///
  /// `remainingSeconds` is omitted while the estimate is unavailable (Apple
  /// returns nil early in the build). Omitted, not zero: the UI shows the
  /// stage alone rather than a countdown that would be invented.
  func emitReconstructionStage(stage: String, remainingSeconds: Double?) {
    var value: [String: Any] = ["stage": stage]
    if let remainingSeconds {
      value["remainingSeconds"] = remainingSeconds
    }
    emit(["type": "reconstruction_stage", "value": value])
  }

  func emitComplete(_ path: String) {
    emit(["type": "reconstruction_complete", "value": path])
  }

  func emitError(code: Int, message: String) {
    emit(["type": "error", "value": ["code": code, "message": message]])
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = events
    onListenHandler?()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }
}
