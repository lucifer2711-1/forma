import ARKit
import RealityKit

/// Hardware/framework capability checks — the single source of truth for
/// device gating (never infer from device model strings).
enum CapabilityChecker {
  /// Whether photogrammetry reconstruction is supported on this device.
  static var isScanSupported: Bool {
    PhotogrammetrySession.isSupported
  }

  /// Whether this device has LiDAR scene reconstruction.
  static var hasLiDAR: Bool {
    ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
  }
}
