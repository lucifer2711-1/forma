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
  private var statePollTask: Task<Void, Never>?

  /// Last phase already acted on, so the stream and the poll below can both
  /// feed `handle(_:)` without double-driving the state machine.
  private var lastHandledPhase: String?

  /// How often the session's `state` property is polled. It is a cheap
  /// property read on the main actor.
  private static let statePollNanoseconds: UInt64 = 200_000_000

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
    CameraDebugLogger.capture.info(
      "capture session created (scan \(scanId, privacy: .public)) — awaiting state machine"
    )
    self.session = session
    recordScan(scanId, imagesDirectory: imagesDirectory)
    lastHandledPhase = nil

    // Task created here inherits the main actor. Subscribed BEFORE start():
    // an update sequence only yields transitions observed after it is
    // consumed.
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
    startStatePolling()

    // Bind the preview BEFORE starting the session.
    //
    // Apple's own Object Capture sample installs `ObjectCaptureView` for the
    // session first and starts it from the view's `onAppear`. Creating the
    // view afterwards let the session run (frames flowing at 30 Hz in the
    // device log) while the view never attached to the live feed — a
    // permanently black preview. The view must exist before `start(…)`
    // (device-test finding 2026-09-18).
    viewport?.attach(session: session)
    session.start(imagesDirectory: imagesDirectory)
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
      // Blank every preview BEFORE releasing the session, so no installed
      // `ObjectCaptureView` is ever left holding a session this service has
      // dropped (RealityKit draws "Cannot make a view for a deinitialized
      // ObjectCaptureSession" over the feed when that happens).
      viewport?.clearSession()
      self.scanId = nil
      self.session = nil
      lastHandledPhase = nil
      stateTask?.cancel()
      feedbackTask?.cancel()
      statePollTask?.cancel()
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

  /// Records the bookkeeping for a freshly created session, before any
  /// state can be handled for it.
  private func recordScan(_ scanId: String, imagesDirectory: URL) {
    self.scanId = scanId
    imagesDirectories[scanId] = imagesDirectory
  }

  /// Drives the session from its `state` property.
  ///
  /// The session's `stateUpdates`/`feedbackUpdates` sequences proved
  /// unreliable on device: a session was created, reached `.ready`, and sat
  /// there while the iteration produced no updates at all — so nothing ever
  /// called `startDetecting()`, `.detecting` was never reached, and every
  /// capture request was refused forever (device-test finding 2026-09-17:
  /// `beginCapturing rejected in state ready` x30 with zero state events).
  /// Polling the property is the dependable driver; the stream above stays
  /// as a fast path.
  private func startStatePolling() {
    statePollTask?.cancel()
    var readyObservations = 0
    statePollTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self, let session = self.session else { return }
        let state = session.state
        self.handle(state)
        if Self.phaseName(state) == "ready" {
          readyObservations += 1
          // Detection occasionally doesn't take on first ask; nudge again
          // while the session waits, and log it so the device log shows it.
          if readyObservations % 5 == 0 {
            CameraDebugLogger.capture.error(
              "session still .ready after \(readyObservations / 5)s — retrying startDetecting"
            )
            self.requestDetecting()
          }
        } else {
          readyObservations = 0
        }
        do {
          try await Task.sleep(nanoseconds: Self.statePollNanoseconds)
        } catch {
          return
        }
      }
    }
  }

  /// Asks the session to begin detecting, only while it is actually ready.
  private func requestDetecting() {
    guard let session, Self.phaseName(session.state) == "ready" else {
      return
    }
    session.startDetecting()
  }

  private func handle(_ state: ObjectCaptureSession.CaptureState) {
    let name = Self.phaseName(state)
    // The stream and the poll both call in; only act on real changes.
    guard name != lastHandledPhase else { return }
    lastHandledPhase = name
    // Every transition is logged so a stuck session can be diagnosed from
    // the device log alone (device test 2026-09-17).
    CameraDebugLogger.capture.info(
      "capture state → \(name, privacy: .public)"
    )
    viewport?.forwardPhase(name)
    switch state {
    case .ready:
      // Auto-advance to bounding-box detection; the capture view
      // (Phase 2) lets the user confirm the box before capture begins.
      CameraDebugLogger.capture.info("capture state: ready → startDetecting")
      requestDetecting()
    case .completed:
      // The live feed is over. Drop the view before Apple tears the
      // session's capture model down, or the preview keeps trying to draw
      // a finished session (device-test finding 2026-09-18: black feed
      // with "Cannot make a view for a deinitialized ObjectCaptureSession").
      viewport?.unbindPreviews()
      if let scanId {
        completedScans.insert(scanId)
        resumeWaiters(scanId, with: imagesDirectories[scanId])
      }
    case .initializing:
      break
    case .failed(let error):
      viewport?.unbindPreviews()
      if let scanId {
        resumeWaiters(scanId, with: nil)
        // Log the raw case as well as the description: the description alone
        // does not distinguish every failure mode on every SDK.
        let described = String(describing: error)
        CameraDebugLogger.capture.error(
          "capture failed (scan \(scanId, privacy: .public)): \(described, privacy: .public)"
        )
        events.emitError(
          code: Self.failureCode(for: described),
          message: error.localizedDescription
        )
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

  /// Maps an `ObjectCaptureSession.Error` to the wire contract's error code.
  ///
  /// The individual cases are not public in every SDK build, so the
  /// description is matched instead — it does name them
  /// ("Error.insufficientStorage(requiredBytes: …)", "Error.trackingFailed",
  /// …). The distinction matters: every capture failure used to reach the UI
  /// as one generic "Something went wrong", which hid the cause from the user
  /// AND from anyone reading the screen (device-test finding 2026-09-18).
  static func failureCode(for description: String) -> Int {
    if description.contains("insufficientStorage") {
      return 1007
    }
    if description.contains("trackingFailed") {
      return 1010
    }
    if description.contains("sensorFailed") {
      return 1009
    }
    if description.contains("exceededMaximumNumberOfImages") {
      return 1008
    }
    return 1001
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
  ///
  /// Priority is "fix the environment first": nothing else can be read while
  /// the scene is too dark, so low light outranks framing and speed. The
  /// environment and object-detection cases are matched by description rather
  /// than by enum case: `Feedback` gains cases between SDKs, and naming a case
  /// a given SDK lacks would not compile (gotcha 22). Matching the description
  /// also means a case we cannot name is logged instead of silently dropped —
  /// the device log showed `Feedback.environmentLowLight`, which the previous
  /// four-value mapping threw away (device-test finding 2026-09-18).
  private static func primaryFeedback(
    _ feedback: Set<ObjectCaptureSession.Feedback>
  ) -> String {
    guard !feedback.isEmpty else {
      return "none"
    }
    let described = feedback.map { String(describing: $0) }
    func has(_ name: String) -> Bool {
      described.contains { $0.contains(name) }
    }

    if has("environmentLowLight") || has("environmentTooDark") {
      return "environmentLowLight"
    }
    if has("objectNotDetected") {
      return "objectNotDetected"
    }
    if has("outOfFieldOfView") {
      return "outOfFieldOfView"
    }
    if has("movingTooFast") {
      return "movingTooFast"
    }
    if has("objectTooClose") {
      return "objectTooClose"
    }
    if has("objectTooFar") {
      return "objectTooFar"
    }
    // Unknown guidance is reported, never swallowed: this is how a renamed
    // case gets discovered from the device log instead of by guesswork.
    CameraDebugLogger.capture.info(
      "unmapped capture feedback: \(described.joined(separator: ", "), privacy: .public)"
    )
    return "none"
  }
}
