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
        configuration: .init()
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
    case .inputComplete, .processingComplete, .processingCancelled,
      .automaticDownsampling, .stitchingIncomplete, .invalidSample,
      .skippedSample, .requestProgressInfo:
      break
    @unknown default:
      break
    }
  }
}
