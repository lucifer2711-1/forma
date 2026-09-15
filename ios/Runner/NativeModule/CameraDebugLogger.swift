import Foundation
import os.log

/// Structured logging so device issues can be diagnosed without a Mac:
/// stream the device log (Console.app, or `idevicesyslog`/`log stream`
/// over USB) and filter by subsystem `com.forma.app`.
enum CameraDebugLogger {
  private static let subsystem = "com.forma.app"

  /// Capture session lifecycle and guidance.
  static let capture = Logger(subsystem: subsystem, category: "capture")

  /// Photogrammetry reconstruction progress and failures.
  static let reconstruct = Logger(subsystem: subsystem, category: "reconstruct")

  /// Model export operations.
  static let export = Logger(subsystem: subsystem, category: "export")
}
