import Foundation

/// On-disk layout for scans:
/// `Documents/Scans/{scanId}/Images/…`, `Documents/Scans/{scanId}/Model.usdz`,
/// `Documents/Exports/{scanId}/model.{ext}`.
enum FormaStorage {
  private static var scansRoot: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Scans", isDirectory: true)
  }

  private static var exportsRoot: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Exports", isDirectory: true)
  }

  /// Creates `Scans/{scanId}/Images` and returns the images directory.
  static func makeScanImagesDirectory(scanId: String) throws -> URL {
    let directory = scansRoot
      .appendingPathComponent(scanId, isDirectory: true)
      .appendingPathComponent("Images", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  /// Where the reconstructed USDZ model for [scanId] is written.
  static func modelURL(scanId: String) -> URL {
    scansRoot
      .appendingPathComponent(scanId, isDirectory: true)
      .appendingPathComponent("Model.usdz")
  }

  /// Export destination for [scanId] and [pathExtension].
  static func exportURL(scanId: String, pathExtension: String) -> URL {
    exportsRoot
      .appendingPathComponent(scanId, isDirectory: true)
      .appendingPathComponent("model.\(pathExtension)")
  }
}
