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

  /// Deletes everything Forma wrote for [scanId]: its source images, the
  /// reconstructed model, and any exports.
  ///
  /// Deleting the library row alone left the model on disk forever — a scan
  /// is hundreds of megabytes, so "delete" has to actually reclaim the space
  /// (user request 2026-09-18: models could not be removed from the
  /// dashboard). Missing directories are not an error: the caller is removing
  /// a row it can see, and the files may already be gone.
  static func deleteScanFiles(scanId: String) {
    for root in [scansRoot, exportsRoot] {
      let directory = root.appendingPathComponent(scanId, isDirectory: true)
      try? FileManager.default.removeItem(at: directory)
    }
  }
}
