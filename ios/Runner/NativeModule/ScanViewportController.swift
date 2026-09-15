import Flutter
import Foundation
import RealityKit
import SwiftUI

/// Holds the active `ObjectCaptureSession` so the native preview can bind
/// to it, and forwards session phase/feedback to Dart.
///
/// `CaptureService` owns the single iteration of `stateUpdates` /
/// `feedbackUpdates` (they are single-consumer streams — iterating them in
/// two places would split events), and calls the forwarding methods here;
/// the controller never iterates the session itself.
@MainActor
final class ScanViewportController: NSObject {
  private let events: FormaEventSink
  private(set) var session: ObjectCaptureSession?
  private weak var preview: CapturePreviewRenderer?

  nonisolated init(events: FormaEventSink) {
    self.events = events
    super.init()
  }

  /// Adopts a newly created session and shows it in the preview.
  func attach(session: ObjectCaptureSession) {
    self.session = session
    preview?.bind(session: session)
  }

  /// Drops the session reference (cancel/cleanup); the preview goes dark.
  func clearSession() {
    session = nil
    preview?.unbind()
  }

  /// Whether a capture session is currently alive.
  var hasActiveSession: Bool {
    session != nil
  }

  /// Registers the platform view's renderer and binds any live session.
  func setPreview(_ preview: CapturePreviewRenderer) {
    self.preview = preview
    if let session {
      preview.bind(session: session)
    }
  }

  /// Forwards a capture phase name to the Dart event channel.
  func forwardPhase(_ name: String) {
    events.emitPhase(name)
  }

  /// Forwards a guidance feedback name to the Dart event channel.
  func forwardFeedback(_ name: String) {
    events.emitFeedback(name)
  }
}
