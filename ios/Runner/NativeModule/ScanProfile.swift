import CoreGraphics
import Foundation
import RealityKit

/// How hard a scan is allowed to work — the single knob behind "make a scan
/// take two minutes instead of twenty".
///
/// A profile decides three things, and every one of them is a real cost:
///
/// 1. how many frames the capture session may keep,
/// 2. how large the images handed to reconstruction are,
/// 3. how hard the reconstruction looks for features.
///
/// It exists because on-device reconstruction is, measurably, a pixel-count
/// problem — and Apple's API offers almost nothing to trade away.
/// `Request.Detail` is `.reduced`-only on iOS and `useTrainedModels` does not
/// exist, so the only lever left is *which and how many* images go in.
/// `ImagePreprocessor` is what acts on this; this type is the policy.
enum ScanProfile: String, CaseIterable {
  /// Pay for speed: a small object, a phone screen, a quick turnaround.
  case quick

  /// The default — a good model without a long wait.
  case balanced

  /// Pay for detail: texture-rich objects that reward a closer look.
  case detail

  /// Resolves a wire value, falling back to [defaultProfile].
  ///
  /// Never throws: an unknown profile means Dart and Swift disagree about the
  /// vocabulary, and the right answer to that is a working scan at the
  /// default speed, not a refused capture.
  static func named(_ name: String?) -> ScanProfile {
    guard let name, let profile = ScanProfile(rawValue: name) else {
      return defaultProfile
    }
    return profile
  }

  /// The speed a scan gets when nobody has chosen one.
  ///
  /// `quick` on purpose: the product promise is that scanning anything takes
  /// a couple of minutes, and a user who wants more detail can say so on the
  /// capture screen before they start (user request 2026-09-20).
  static let defaultProfile = ScanProfile.quick

  /// The frame count at which the scan is considered to have enough.
  ///
  /// A *target*, not a cap: it drives the guidance and the "Build model now"
  /// nudge. Reaching it is the point where another lap costs the user time
  /// and buys nothing.
  var targetShots: Int {
    switch self {
    case .quick: return 35
    case .balanced: return 60
    case .detail: return 100
    }
  }

  /// The frame count at which the capture ends by itself.
  ///
  /// A hard bound is the only thing that makes capture time predictable: the
  /// session will keep shooting for as long as the user keeps walking, and
  /// every extra frame costs reconstruction time as well. It is set well past
  /// the target so it can only ever truncate over-scanning — never a scan
  /// that is still filling in.
  var maxShots: Int {
    switch self {
    case .quick: return 70
    case .balanced: return 120
    case .detail: return 200
    }
  }

  /// Longest edge of the images handed to reconstruction, in pixels.
  ///
  /// Object Capture writes full-sensor frames (4032×3024 on a 12 MP iPhone)
  /// and reconstruction cost scales with their pixels, so this is the one
  /// number that changes a build from minutes to tens of seconds. 1536 is
  /// still several times a phone's on-screen resolution for an object that
  /// fills the frame, which is why `quick` can be this cheap without looking
  /// soft.
  var maxImageDimension: CGFloat {
    switch self {
    case .quick: return 1536
    case .balanced: return 2048
    case .detail: return 3072
    }
  }

  /// How hard the reconstruction looks for matching features.
  ///
  /// `.high` finds more features on low-contrast or low-texture objects at a
  /// real cost in time, so it only earns its place in `detail`.
  var featureSensitivity: PhotogrammetrySession.Configuration.FeatureSensitivity {
    switch self {
    case .quick, .balanced: return .normal
    case .detail: return .high
    }
  }

  /// The reconstruction configuration this profile describes.
  var configuration: PhotogrammetrySession.Configuration {
    var configuration = PhotogrammetrySession.Configuration()
    // Object Capture writes its frames in the order the user walked, so
    // declaring the samples ordered lets the session skip the exhaustive
    // pairwise matching it otherwise does for unordered input.
    // `ImagePreprocessor` preserves that order when it rewrites the frames.
    configuration.sampleOrdering = .sequential
    // Masking stays on for every profile, including `quick`: it is what keeps
    // the turntable and the room out of the model, and a fast model that has
    // to be re-scanned is slower than a slow one.
    configuration.isObjectMaskingEnabled = true
    configuration.featureSensitivity = featureSensitivity
    return configuration
  }
}
