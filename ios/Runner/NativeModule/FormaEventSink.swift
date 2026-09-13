import Flutter
import Foundation

/// Bridges native events to the Dart `capture_events` EventChannel.
///
/// Payloads match the Dart `IosNativeBridge._onEvent` contract:
/// `{"type": …, "value": …}`.
final class FormaEventSink: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?

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

  func emitProgress(_ value: Double) {
    emit(["type": "reconstruction_progress", "value": value])
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
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }
}
