import Foundation
import RealityKit

/// Runs a `PhotogrammetrySession` per finished scan and streams progress
/// and completion over the event channel. Errors surface as event errors.
final class ReconstructionService {
  private let events: FormaEventSink
  private let onModelReady: (String, URL) -> Void
  private var tasks: [String: Task<Void, Never>] = [:]

  init(events: FormaEventSink, onModelReady: @escaping (String, URL) -> Void) {
    self.events = events
    self.onModelReady = onModelReady
  }

  /// Starts reconstruction once [capture] reports images flushed.
  func start(scanId: String, capture: CaptureService) {
    tasks[scanId]?.cancel()
    tasks[scanId] = Task.detached { [weak self] in
      guard let imagesDirectory = await capture.awaitCompletion(
        scanId: scanId
      ) else {
        self?.events.emitError(
          code: 2003,
          message: "Capture incomplete for scan \(scanId)"
        )
        return
      }
      await self?.reconstruct(scanId: scanId, imagesDirectory: imagesDirectory)
    }
  }

  /// Cancels an in-flight reconstruction for [scanId].
  func cancel(scanId: String) {
    tasks.removeValue(forKey: scanId)?.cancel()
  }

  private func reconstruct(scanId: String, imagesDirectory: URL) async {
    let outputURL = FormaStorage.modelURL(scanId: scanId)
    do {
      try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try? FileManager.default.removeItem(at: outputURL)
      let session = try PhotogrammetrySession(
        input: imagesDirectory,
        configuration: .forma
      )
      try session.process(
        requests: [PhotogrammetrySession.Request(modelFile: outputURL)]
      )
      for try await output in session.outputs {
        handle(output, scanId: scanId)
      }
    } catch {
      CameraDebugLogger.reconstruct.error(
        "reconstruction failed: \(error.localizedDescription, privacy: .public)"
      )
      events.emitError(code: 2001, message: error.localizedDescription)
    }
  }

  private func handle(
    _ output: PhotogrammetrySession.Output,
    scanId: String
  ) {
    switch output {
    case .requestProgress(_, fractionComplete: let fraction):
      events.emitProgress(fraction)
    case .requestProgressInfo(_, let info):
      // Apple's own stage and remaining-time estimate, surfaced instead of
      // swallowed. "It takes too much time" is mostly a problem of not
      // knowing how long is left, and this is the only honest ETA that
      // exists — ours would be a guess (user request 2026-09-18: make the
      // build feel fast).
      events.emitReconstructionStage(
        stage: Self.stageName(info.processingStage),
        remainingSeconds: info.estimatedRemainingTime
      )
    case .requestComplete(_, let result):
      if case .modelFile(let url) = result {
        onModelReady(scanId, url)
        events.emitComplete(url.path)
      }
    case .requestError(_, let error):
      CameraDebugLogger.reconstruct.error(
        "request error: \(error.localizedDescription, privacy: .public)"
      )
      events.emitError(code: 2002, message: error.localizedDescription)
    case .automaticDownsampling:
      // Memory pressure made RealityKit shrink the input images. The model
      // still builds, but coarser and slower — logged at error level so a
      // mediocre result is not mistaken for a bad capture.
      CameraDebugLogger.reconstruct.error(
        "automatic downsampling — RealityKit reduced the input images under memory pressure"
      )
    case .stitchingIncomplete:
      // RealityKit could not join every frame into one model, which is the
      // signature of missing coverage rather than a build failure.
      CameraDebugLogger.reconstruct.error(
        "stitching incomplete — the scan is missing coverage"
      )
    case .inputComplete, .processingComplete, .processingCancelled,
      .invalidSample, .skippedSample:
      break
    @unknown default:
      break
    }
  }

  /// Maps a processing stage to the short wire name the UI reads.
  ///
  /// Kept as a token rather than a sentence: the wording lives in Dart with
  /// the rest of the UI copy (rules.md §2 — no user-facing English in Swift).
  ///
  /// The stage is optional — RealityKit reports nil before it has entered a
  /// named step, which is not the same as being finished, so that case reads
  /// as "working" rather than being dropped (CI caught this: the docs page
  /// does not show the `?`).
  static func stageName(
    _ stage: PhotogrammetrySession.Output.ProcessingStage?
  ) -> String {
    guard let stage else {
      return "working"
    }
    switch stage {
    case .preProcessing: return "preprocessing"
    case .imageAlignment: return "aligning"
    case .pointCloudGeneration: return "points"
    case .meshGeneration: return "mesh"
    case .textureMapping: return "texture"
    case .optimization: return "optimizing"
    @unknown default: return "working"
    }
  }
}

extension PhotogrammetrySession.Configuration {
  /// Forma's reconstruction configuration — the fastest path iOS offers.
  ///
  /// `sampleOrdering: .sequential` is the real lever available on device.
  /// Object Capture writes its frames in the order they were captured, walking
  /// around the object, so declaring the samples ordered lets the session skip
  /// the exhaustive pairwise matching it otherwise does for unordered input.
  /// Apple's guideline is explicit: use it when the images are in a sequence.
  /// (Revert to `.unordered` only if sequential ordering ever produces a
  /// visibly worse stitch — it trades some robustness for speed.)
  ///
  /// There is no detail level to trade against here: **on iOS,
  /// `Request.Detail` supports only `.reduced`** — `.preview` and `.full` are
  /// macOS-only. So the geometry stage is already as fast as Apple allows and
  /// the only remaining wins are the ordering above and telling the user how
  /// long is left (see `requestProgressInfo`).
  static var forma: PhotogrammetrySession.Configuration {
    var configuration = PhotogrammetrySession.Configuration()
    configuration.sampleOrdering = .sequential
    // Masking stays on: it is what keeps the turntable and the room out of the
    // model, and it is also one of the trained ML stages Apple runs for us.
    configuration.isObjectMaskingEnabled = true
    configuration.featureSensitivity = .normal
    return configuration
  }
}
