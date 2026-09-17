import CoreMotion
import Foundation

/// Tracks which way the phone is aimed at the object while scanning.
///
/// This is what the coverage globe is built from: one direction per frame
/// Object Capture keeps, so the user can see which sides of the object are
/// done and which still need scanning. Object Capture exposes no camera pose
/// of its own, so CoreMotion is the only source for "where was I standing".
///
/// The reference frame is gravity-aligned on purpose: the vertical axis is
/// real vertical, which is what makes "the top of the object" and "the
/// underside" meaningful, while yaw is relative to whenever the scan started
/// — exactly the frame a walk-around needs, and one that cannot be confused
/// by the phone being held in any orientation.
@MainActor
final class ScanDirectionRecorder {
  private let motion = CMMotionManager()

  /// The last direction sent as a kept frame, so re-scanning the same 10° of
  /// the object does not flood the event channel with the same side.
  private var lastKeptDirection: SIMD3<Float>?

  /// Minimum angle between two *kept* directions, in degrees.
  private static let minSeparationDegrees: Float = 10

  /// Whether device motion updates are running.
  private(set) var isRunning = false

  /// Whether this device can report device motion at all.
  var isAvailable: Bool { motion.isDeviceMotionAvailable }

  /// Starts motion tracking. Safe to call twice (a second scan reuses the
  /// running recorder only after `stop()`).
  func start() {
    guard motion.isDeviceMotionAvailable else {
      CameraDebugLogger.capture.error(
        "scan direction recorder: no device motion on this device"
      )
      return
    }
    guard !isRunning else {
      return
    }
    isRunning = true
    lastKeptDirection = nil
    motion.deviceMotionUpdateInterval = 1.0 / 30.0
    // `.xArbitraryZVertical`: z is gravity-up, x is whatever the phone was
    // facing when the scan began.
    motion.startDeviceMotionUpdates(using: .xArbitraryZVertical)
    CameraDebugLogger.capture.info("scan direction recorder started")
  }

  /// Stops motion tracking (scan cancelled, finished, or failed).
  func stop() {
    guard isRunning else {
      return
    }
    isRunning = false
    motion.stopDeviceMotionUpdates()
    lastKeptDirection = nil
  }

  /// The direction of the object's surface that faces the phone, as a unit
  /// vector in the gravity-aligned frame — or nil until the first motion
  /// sample arrives.
  ///
  /// The device frame has +x to the right, +y up the screen and +z out of the
  /// screen, so the surface facing the phone is the +z axis rotated into the
  /// reference frame (the camera itself looks along −z).
  var surfaceDirection: SIMD3<Float>? {
    guard isRunning, let attitude = motion.deviceMotion?.attitude else {
      return nil
    }
    let rotation = attitude.rotationMatrix
    // Column 3 of the rotation matrix is the device's +z axis expressed in
    // the reference frame — the direction the object faces the phone from.
    let x = rotation.m13
    let y = rotation.m23
    let z = rotation.m33
    let length = (x * x + y * y + z * z).squareRoot()
    guard length > 0.0001 else {
      return nil
    }
    return SIMD3<Float>(
      Float(x / length),
      Float(y / length),
      Float(z / length)
    )
  }

  /// Angle between two directions, in radians.
  ///
  /// Written out rather than using the `simd` helpers: `simd_angle_between`
  /// is not in scope for `SIMD3<Float>` on this SDK (build failure, 2026-09-18),
  /// and the arithmetic is three multiplications.
  private static func angle(
    between lhs: SIMD3<Float>,
    and rhs: SIMD3<Float>
  ) -> Float {
    let dot = lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
    // Both sides are unit vectors, so the dot is the cosine — clamped, or a
    // rounding error past 1 would make acos return NaN.
    return acos(min(max(dot, -1), 1))
  }

  /// The current direction, but only when it is far enough from the last one
  /// reported as a kept frame. Nil means "nothing new to report".
  func nextUnreportedDirection() -> SIMD3<Float>? {
    guard let direction = surfaceDirection else {
      return nil
    }
    if let last = lastKeptDirection,
       Self.angle(between: last, and: direction) <
       Self.minSeparationDegrees * .pi / 180 {
      return nil
    }
    lastKeptDirection = direction
    return direction
  }
}
