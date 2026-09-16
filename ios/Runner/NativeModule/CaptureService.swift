import AVFoundation
import Foundation
import RealityKit
import SwiftUI

/// Wraps an `ObjectCaptureSession` for one scan lifecycle and tracks the
/// on-disk image directories per scan id.
///
/// The session is `@MainActor` (it lives in the RealityKit SwiftUI
/// overlay), so this service is main-actor isolated; the channel handler
/// reaches it through the `*Async` nonisolated entry points.
@MainActor
final class CaptureService {
  private let events: FormaEventSink

  /// Bridges session events to Dart and binds sessions to the preview.
  private var viewport: ScanViewportController?

  private var session: ObjectCaptureSession?
  private var scanId: String?
  private var imagesDirectories: [String: URL] = [:]
  private var completedScans: Set<String> = []
  private var completionWaiters: [String: [CheckedContinuation<URL?, Never>]] = [:]
  private var stateTask: Task<Void, Never>?
  private var feedbackTask: Task<Void, Never>?

  nonisolated init(events: FormaEventSink, viewport: ScanViewportController?) {
    self.events = events
    self.viewport = viewport
  }

  // MARK: Nonisolated entry points (channel handler)

  /// Starts a capture session on the main actor; returns the scan id.
  ///
  /// `start()` is async (camera-permission request), so the plain await
  /// already hops to the main actor — `MainActor.run` requires a
  /// synchronous closure and would not compile here.
  nonisolated func startAsync() async throws -> String {
    try await start()
  }

  /// Moves the session into image capture on the main actor.
  nonisolated func beginCapturingAsync(scanId: String) async throws {
    try await beginCapturing(scanId: scanId)
  }

  /// Finishes the session on the main actor.
  nonisolated func finishAsync(scanId: String) async throws {
    try await finish(scanId: scanId)
  }

  /// Cancels the scan on the main actor.
  nonisolated func cancelAsync(scanId: String) async {
    await cancel(scanId: scanId)
  }

  // MARK: Session lifecycle

  /// Starts a capture session for a new scan; returns the scan id.
  ///
  /// Restart semantics: every `startCapture()` call yields a fresh,
  /// usable session. Any previous session — wedged in `.initializing`,
  /// orphaned after a Dart-side timeout, or left over from a re-entered
  /// start — is torn down first instead of stacking a second camera
  /// session on top of it (device-test finding 2026-09-16: stacked
  /// sessions fight over the camera, feed stays black, later taps
  /// crash inside the invalid state machine).
  func start() async throws -> String {
    // Apple requires an explicit requestAccess before the session can use
    // the camera. With .notDetermined, ObjectCaptureSession.start() wedges
    // in .initializing forever — no frames, no phase events, black preview
    // (device-test finding 2026-09-16). Ask, then fail honestly.
    // Note: a re-signed update install (Sideloadly) resets the TCC grant,
    // so this dialog legitimately reappears after an update.
    let granted = await AVCaptureDevice.requestAccess(for: .video)
    if !granted {
      CameraDebugLogger.capture.error("camera permission denied by user")
      throw FormaNativeError(
        domain: .capture,
        code: 1005,
        message: "Camera permission denied"
      )
    }

    // Tear down any previous session before creating a new one. There is
    // no explicit stop API: resuming pending completion waiters, cancelling
    // the event tasks, and dropping every reference deallocates the
    // session and frees the camera.
    if let previousScanId = scanId {
      CameraDebugLogger.capture.error(
        "start re-entered — replacing previous capture session"
      )
      cancel(scanId: previousScanId)
    }

    let scanId = UUID().uuidString
    let imagesDirectory = try FormaStorage.makeScanImagesDirectory(
      scanId: scanId
    )

    let session = ObjectCaptureSession()
    session.start(imagesDirectory: imagesDirectory)
    CameraDebugLogger.capture.info(
      "capture session created (scan \(scanId, privacy: .public)) — awaiting state machine"
    )
    self.session = session
    self.scanId = scanId
    imagesDirectories[scanId] = imagesDirectory
    viewport?.attach(session: session)

    // Tasks created here inherit the main actor.
    stateTask = Task { [weak self] in
      guard let updates = self?.session?.stateUpdates else { return }
      for await state in updates {
        self?.handle(state)
      }
    }
    feedbackTask = Task { [weak self] in
      guard let updates = self?.session?.feedbackUpdates else { return }
      for await feedback in updates {
        self?.viewport?.forwardFeedback(Self.primaryFeedback(feedback))
      }
    }
    return scanId
  }

  /// Moves the session from detection into image capture.
  ///
  /// `startCapturing()` is only legal from `.detecting` — calling it on a
  /// wedged/`.initializing` session traps inside the session's state
  /// machine and kills the app. Throw an honest error instead.
  func beginCapturing(scanId: String) throws {
    guard let session, scanId == self.scanId else {
      throw FormaNativeError(
        domain: .capture,
        code: 1004,
        message: "No active capture session for scan \(scanId)"
      )
    }
    switch session.state {
    case .detecting, .capturing:
      session.startCapturing()
    default:
      CameraDebugLogger.capture.error(
        "beginCapturing rejected in state \(String(describing: session.state), privacy: .public)"
      )
      throw FormaNativeError(
        domain: .capture,
        code: 1006,
        message: "Capture session is not ready yet — try again in a moment"
      )
    }
  }

  /// Requests the session to finish; images flush asynchronously.
  ///
  /// Same state guard as `beginCapturing`: `finish()` is only legal once
  /// images are being captured.
  func finish(scanId: String) throws {
    guard let session, scanId == self.scanId else {
      throw FormaNativeError(
        domain: .capture,
        code: 1002,
        message: "No active capture session for scan \(scanId)"
      )
    }
    switch session.state {
    case .capturing, .finishing:
      session.finish()
    default:
      CameraDebugLogger.capture.error(
        "finish rejected in state \(String(describing: session.state), privacy: .public)"
      )
      throw FormaNativeError(
        domain: .capture,
        code: 1006,
        message: "Capture session is not capturing yet"
      )
    }
  }

  /// Cancels a scan: stops event tasks and deletes its files.
  func cancel(scanId: String) {
    let imagesDirectory = imagesDirectories.removeValue(forKey: scanId)
    completedScans.remove(scanId)
    if let waiters = completionWaiters.removeValue(forKey: scanId) {
      for waiter in waiters {
        waiter.resume(returning: nil)
      }
    }
    if scanId == self.scanId {
      self.scanId = nil
      self.session = nil
      stateTask?.cancel()
      feedbackTask?.cancel()
      viewport?.clearSession()
    }
    if let imagesDirectory {
      try? FileManager.default.removeItem(
        at: imagesDirectory.deletingLastPathComponent()
      )
    }
  }

  /// Suspends until the session finished writing images for [scanId];
  /// returns the images directory, or nil for unknown/cancelled/failed scans.
  func awaitCompletion(scanId: String) async -> URL? {
    if completedScans.contains(scanId) {
      return imagesDirectories[scanId]
    }
    guard imagesDirectories[scanId] != nil else {
      return nil
    }
    return await withCheckedContinuation { continuation in
      completionWaiters[scanId, default: []].append(continuation)
    }
  }

  // MARK: Event handling

  private func handle(_ state: ObjectCaptureSession.CaptureState) {
    // Every transition is logged so a stuck session can be diagnosed from
    // the device log alone (device test 2026-09-17: session alive, frames
    // flowing, but tracking "not normal" → no .ready, UI stuck starting).
    CameraDebugLogger.capture.info(
      "capture state → \(Self.phaseName(state), privacy: .public)"
    )
    viewport?.forwardPhase(Self.phaseName(state))
    switch state {
    case .ready:
      // Auto-advance to bounding-box detection; the capture view
      // (Phase 2) lets the user confirm the box before capture begins.
      CameraDebugLogger.capture.info("capture state: ready → startDetecting")
      session?.startDetecting()
    case .completed:
      if let scanId {
        completedScans.insert(scanId)
        resumeWaiters(scanId, with: imagesDirectories[scanId])
      }
    case .initializing:
      break
    case .failed(let error):
      if let scanId {
        resumeWaiters(scanId, with: nil)
        CameraDebugLogger.capture.error(
          "capture failed (scan \(scanId, privacy: .public)): \(error.localizedDescription, privacy: .public)"
        )
        // Object Capture hard-requires ~4 GB free; below that the session
        // fails instantly with .insufficientStorage (device log 2026-09-17:
        // 3.43 GB free → failed before the first frame). Surface it
        // specifically so the UI can tell the user what to do. The case
        // isn't public in every SDK, so match the description the session
        // actually prints ("…Error.insufficientStorage(requiredBytes: …)").
        if String(describing: error).contains("insufficientStorage") {
          events.emitError(
            code: 1007,
            message: "Not enough free space on this iPhone."
          )
        } else {
          events.emitError(code: 1001, message: error.localizedDescription)
        }
      }
    default:
      break
    }
  }

  private func resumeWaiters(_ scanId: String, with directory: URL?) {
    guard let waiters = completionWaiters.removeValue(forKey: scanId) else {
      return
    }
    for waiter in waiters {
      waiter.resume(returning: directory)
    }
  }

  /// Maps a capture state to the wire-contract phase name. Internal (not
  /// private) so the viewport controller can answer session-state probes.
  static func phaseName(
    _ state: ObjectCaptureSession.CaptureState
  ) -> String {
    switch state {
    case .initializing: return "initializing"
    case .ready: return "ready"
    case .detecting: return "detecting"
    case .capturing: return "capturing"
    case .finishing: return "finishing"
    case .completed: return "completed"
    case .failed: return "failed"
    @unknown default: return "failed"
    }
  }

  /// Maps a feedback set to the single most urgent guidance value.
  private static func primaryFeedback(
    _ feedback: Set<ObjectCaptureSession.Feedback>
  ) -> String {
    if feedback.contains(.outOfFieldOfView) {
      return "outOfFieldOfView"
    }
    if feedback.contains(.movingTooFast) {
      return "movingTooFast"
    }
    if feedback.contains(.objectTooClose) {
      return "objectTooClose"
    }
    if feedback.contains(.objectTooFar) {
      return "objectTooFar"
    }
    return "none"
  }
}
