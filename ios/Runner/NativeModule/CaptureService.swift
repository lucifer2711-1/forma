import Foundation
import RealityKit

/// Wraps an `ObjectCaptureSession` for one scan lifecycle and tracks the
/// on-disk image directories per scan id.
final class CaptureService {
  private let events: FormaEventSink

  private var session: ObjectCaptureSession?
  private var scanId: String?
  private var imagesDirectories: [String: URL] = [:]
  private var completedScans: Set<String> = []
  private var completionWaiters: [String: [CheckedContinuation<URL?, Never>]] = [:]
  private var stateTask: Task<Void, Never>?
  private var feedbackTask: Task<Void, Never>?

  init(events: FormaEventSink) {
    self.events = events
  }

  /// Starts a capture session for a new scan; returns the scan id.
  func start() throws -> String {
    let scanId = UUID().uuidString
    let imagesDirectory = try FormaStorage.makeScanImagesDirectory(scanId: scanId)

    let session = ObjectCaptureSession()
    session.start(imagesDirectory: imagesDirectory)
    self.session = session
    self.scanId = scanId
    imagesDirectories[scanId] = imagesDirectory

    stateTask = Task { [weak self] in
      guard let updates = self?.session?.stateUpdates else { return }
      for await state in updates {
        self?.handle(state)
      }
    }
    feedbackTask = Task { [weak self] in
      guard let updates = self?.session?.feedbackUpdates else { return }
      for await feedback in updates {
        self?.events.emitFeedback(Self.feedbackName(feedback))
      }
    }
    return scanId
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
    }
    if let imagesDirectory {
      try? FileManager.default.removeItem(at: imagesDirectory.deletingLastPathComponent())
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

  private func handle(_ state: ObjectCaptureSession.State) {
    events.emitPhase(Self.phaseName(state))
    switch state {
    case .completed:
      if let scanId {
        completedScans.insert(scanId)
        resumeWaiters(scanId, with: imagesDirectories[scanId])
      }
    case .failed:
      if let scanId {
        resumeWaiters(scanId, with: nil)
      }
    default:
      break
    }
  }

  private func resumeWaiters(_ scanId: String, with directory: URL?) {
    guard let waiters = completionWaiters.removeValue(forKey: scanId) else { return }
    for waiter in waiters {
      waiter.resume(returning: directory)
    }
  }

  private static func phaseName(_ state: ObjectCaptureSession.State) -> String {
    switch state {
    case .initialize: return "initializing"
    case .ready: return "ready"
    case .detecting: return "detecting"
    case .capturing: return "capturing"
    case .finishing: return "finishing"
    case .completed: return "completed"
    case .failed: return "failed"
    @unknown default: return "failed"
    }
  }

  private static func feedbackName(_ feedback: ObjectCaptureSession.Feedback) -> String {
    if feedback == .objectTooClose {
      return "objectTooClose"
    }
    if feedback == .objectTooFar {
      return "objectTooFar"
    }
    if feedback == .movingTooFast {
      return "movingTooFast"
    }
    if feedback == .outOfFieldOfView {
      return "outOfFieldOfView"
    }
    return "none"
  }
}
