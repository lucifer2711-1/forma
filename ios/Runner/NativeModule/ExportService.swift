import Foundation

/// Exports reconstructed models. USDZ is a real file copy; OBJ and STL
/// writers arrive in Phase 4 (via MDLMesh) and fail honestly until then.
///
/// The in-memory registry only lives for the current run; the canonical
/// on-disk model location (`Scans/{scanId}/Model.usdz`) is always checked
/// as a fallback so export works after an app relaunch.
final class ExportService {
  private var models: [String: URL] = [:]

  /// Registers the reconstructed model for [scanId].
  func register(model: URL, scanId: String) {
    models[scanId] = model
  }

  /// Exports [scanId] to [format]; returns the exported file URL.
  func export(scanId: String, format: String) throws -> URL {
    guard let source = resolveModel(scanId: scanId) else {
      throw FormaNativeError(
        domain: .export,
        code: 3001,
        message: "No reconstructed model for scan \(scanId)"
      )
    }
    switch format {
    case "usdz":
      let destination = FormaStorage.exportURL(scanId: scanId, pathExtension: "usdz")
      try FileManager.default.createDirectory(
        at: destination.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try? FileManager.default.removeItem(at: destination)
      try FileManager.default.copyItem(at: source, to: destination)
      return destination
    case "obj", "stl":
      throw FormaNativeError(
        domain: .export,
        code: 3002,
        message: "\(format.uppercased()) export arrives in a future update"
      )
    default:
      throw FormaNativeError(
        domain: .export,
        code: 3003,
        message: "Unknown export format \(format)"
      )
    }
  }

  /// Resolves the model file for [scanId]: the registered URL if it still
  /// exists, else the canonical reconstruction output for the scan.
  private func resolveModel(scanId: String) -> URL? {
    if let registered = models[scanId],
       FileManager.default.fileExists(atPath: registered.path) {
      return registered
    }
    let canonical = FormaStorage.modelURL(scanId: scanId)
    return FileManager.default.fileExists(atPath: canonical.path)
      ? canonical
      : nil
  }
}
