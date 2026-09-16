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
  ///
  /// A session still in `.initializing` when this is probed has failed to
  /// produce the first frame — a healthy session reaches `.ready` in well
  /// under a second. Reporting it as alive would blind Dart's watchdog
  /// (device-test finding 2026-09-16: black preview with no error because
  /// the wedged session counted as active).
  var hasActiveSession: Bool {
    guard let session else {
      return false
    }
    return session.state != .initializing
  }

  /// The session's current state as a contract string, or "none" when no
  /// session exists. Lets Dart distinguish "camera dead" from "tracking
  /// hasn't initialized yet" — the latter needs lighting guidance, not an
  /// error (device test 2026-09-17: frames flowing, tracking "not normal",
  /// session parked in .initializing for the whole screen session).
  var sessionStateName: String {
    guard let session else {
      return "none"
    }
    return CaptureService.phaseName(session.state)
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

  /// Re-emits the session's current phase into a freshly attached sink.
  ///
  /// Dart needs the truth even when the transition itself was emitted before
  /// its listener existed (see `FormaEventSink.onListenHandler`).
  func replayCurrentPhase() {
    guard let session else {
      return
    }
    events.emitPhase(CaptureService.phaseName(session.state))
  }

  /// Forwards a guidance feedback name to the Dart event channel.
  func forwardFeedback(_ name: String) {
    events.emitFeedback(name)
  }
}
