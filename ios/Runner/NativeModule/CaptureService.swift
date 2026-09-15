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
  func start() throws -> String {
    let auth = AVCaptureDevice.authorizationStatus(for: .video)
    let authLog = "camera authorization: \(auth.rawValue) (2=authorized)"
    CameraDebugLogger.capture.info("\(authLog, privacy: .public)")
    let scanId = UUID().uuidString
    let imagesDirectory = try FormaStorage.makeScanImagesDirectory(
      scanId: scanId
    )

    let session = ObjectCaptureSession()
    session.start(imagesDirectory: imagesDirectory)
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
  func beginCapturing(scanId: String) throws {
    guard let session, scanId == self.scanId else {
      throw FormaNativeError(
        domain: .capture,
        code: 1004,
        message: "No active capture session for scan \(scanId)"
      )
    }
    session.startCapturing()
  }

  /// Requests the session to finish; images flush asynchronously.
  func finish(scanId: String) throws {
    guard let session, scanId == self.scanId else {
      throw FormaNativeError(
        domain: .capture,
        code: 1002,
        message: "No active capture session for scan \(scanId)"
      )
    }
    session.finish()
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
    viewport?.forwardPhase(Self.phaseName(state))
    switch state {
    case .ready:
      // Auto-advance to bounding-box detection; the capture view
      // (Phase 2) lets the user confirm the box before capture begins.
      session?.startDetecting()
    case .completed:
      if let scanId {
        completedScans.insert(scanId)
        resumeWaiters(scanId, with: imagesDirectories[scanId])
      }
    case .failed(let error):
      if let scanId {
        resumeWaiters(scanId, with: nil)
        CameraDebugLogger.capture.error(
          "capture failed (scan \(scanId, privacy: .public)): \(error.localizedDescription, privacy: .public)"
        )
        events.emitError(code: 1001, message: error.localizedDescription)
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

  private static func phaseName(
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
