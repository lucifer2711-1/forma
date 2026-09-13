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
      guard let imagesDirectory = await capture.awaitCompletion(scanId: scanId) else {
        self?.events.emitError(code: 2003, message: "Capture incomplete for scan \(scanId)")
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
      let session = try PhotogrammetrySession(
        inputs: .images(directory: imagesDirectory)
      )
      try await session.process(requests: [.model(outputURL)])
      for try await output in session.outputs {
        try handle(output, scanId: scanId)
      }
    } catch {
      events.emitError(code: 2001, message: error.localizedDescription)
    }
  }

  private func handle(
    _ output: PhotogrammetrySession.Output,
    scanId: String
  ) throws {
    switch output {
    case .requestProgress(_, let fraction):
      events.emitProgress(fraction)
    case .requestComplete(_, let result):
      if case .model(let url) = result {
        onModelReady(scanId, url)
        events.emitComplete(url.path)
      }
    case .requestError(_, let error):
      events.emitError(code: 2002, message: error.localizedDescription)
    case .invalidated(let error):
      events.emitError(code: 2004, message: error.localizedDescription)
    case .inputComplete, .processingComplete:
      break
    @unknown default:
      break
    }
  }
}
