import Foundation

/// Exports reconstructed models. USDZ is a real file copy; OBJ and STL
/// writers arrive in Phase 4 (via MDLMesh) and fail honestly until then.
final class ExportService {
  private var models: [String: URL] = [:]

  /// Registers the reconstructed model for [scanId].
  func register(model: URL, scanId: String) {
    models[scanId] = model
  }

  /// Exports [scanId] to [format]; returns the exported file URL.
  func export(scanId: String, format: String) throws -> URL {
    guard let source = models[scanId] else {
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
}
