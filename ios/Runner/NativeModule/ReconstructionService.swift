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
      // The scan's speed profile is read here rather than passed in, so a
      // build that starts while a *newer* scan is already running still
      // rebuilds the right scan's images at the right size.
      let profile = await capture.profile(scanId: scanId)
      await self?.reconstruct(
        scanId: scanId,
        imagesDirectory: imagesDirectory,
        profile: profile
      )
    }
  }

  /// Cancels an in-flight reconstruction for [scanId].
  func cancel(scanId: String) {
    tasks.removeValue(forKey: scanId)?.cancel()
  }

  /// Fraction of the reported build progress that preparing the images owns.
  ///
  /// The ring composes the two stages so it only ever moves forwards:
  /// downsizing a hundred frames is real work the user is waiting for, and a
  /// ring pinned at 0% through it is exactly the "this is taking forever"
  /// feeling this whole path exists to remove. Reported as one number because
  /// to the user it is one build, not two.
  private static let preparationShare = 0.15

  private func reconstruct(
    scanId: String,
    imagesDirectory: URL,
    profile: ScanProfile
  ) async {
    let outputURL = FormaStorage.modelURL(scanId: scanId)
    let preparedDirectory = FormaStorage.preparedImagesDirectory(scanId: scanId)
    do {
      try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try? FileManager.default.removeItem(at: outputURL)

      // Named before it starts, not after: "Preparing your photos" is an
      // honest answer to "what is it doing right now?" from the first frame.
      events.emitReconstructionStage(stage: "preparing", remainingSeconds: nil)
      let result = try ImagePreprocessor.prepare(
        imagesDirectory: imagesDirectory,
        profile: profile,
        outputDirectory: preparedDirectory
      ) { [weak self] fraction in
        self?.events.emitProgress(Self.preparationShare * fraction)
      }
      CameraDebugLogger.reconstruct.info(
        "prepared \(result.outputCount)/\(result.inputCount) frames at \(Int(result.maxDimension))px (\(profile.rawValue, privacy: .public))"
      )
      // The prepared frames are a working copy, not a second scan: the
      // originals stay in `Images/` (they are what a future higher-quality
      // rebuild would use) and this is dropped either way.
      defer { try? FileManager.default.removeItem(at: preparedDirectory) }

      let session = try PhotogrammetrySession(
        input: result.directory,
        configuration: profile.configuration
      )
      try session.process(
        requests: [PhotogrammetrySession.Request(modelFile: outputURL)]
      )
      for try await output in session.outputs {
        handle(output, scanId: scanId)
      }
    } catch {
      try? FileManager.default.removeItem(at: preparedDirectory)
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
      // Scaled past the preparation share so the ring keeps moving forwards
      // from where downsizing the photos left it.
      events.emitProgress(
        Self.preparationShare + (1 - Self.preparationShare) * fraction
      )
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
