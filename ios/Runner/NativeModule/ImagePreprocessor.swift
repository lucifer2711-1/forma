import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Prepares a finished capture's photos for reconstruction: fewer of them,
/// smaller, in the order they were shot.
///
/// This is the stage that actually makes a scan fast. RealityKit's
/// reconstruction cost is driven by how many pixels it has to decode, mask,
/// match and texture-map, and Object Capture hands over full-sensor frames —
/// up to ~150 of them at 12 MP, which is roughly two gigapixels of work for a
/// coffee-cup-sized object.
///
/// Nothing here is a simulation and nothing leaves the phone: it is plain
/// on-device image processing (ImageIO + Core Graphics), and the one decision
/// it makes — which frames are worth keeping — is a sharpness measurement,
/// which is real and cheap. The expensive stage downstream then has an order
/// of magnitude less to chew through.
enum ImagePreprocessor {
  /// What a preparation run did, so the build log records the real numbers.
  struct Result {
    /// Where the prepared images were written.
    let directory: URL

    /// How many frames the capture produced.
    let inputCount: Int

    /// How many frames were handed to reconstruction.
    let outputCount: Int

    /// Longest edge of every prepared image.
    let maxDimension: CGFloat
  }

  /// Longest edge of the thumbnail the sharpness score is measured on.
  ///
  /// Small on purpose: the score only has to rank frames against each other,
  /// and a 256 px grayscale buffer makes that nearly free next to decoding a
  /// full frame.
  private static let scoreDimension = 256

  /// Below this many frames nothing is dropped, however blurry.
  ///
  /// A scan that lost its coverage to a quality filter would have to be
  /// redone, which is slower end to end than a slightly soft model.
  private static let minimumKept = 24

  /// Fraction of preparation spent scoring frames; the rest is writing them.
  private static let scoreShare = 0.4

  /// JPEG quality for the prepared frames. Visually lossless at these sizes,
  /// and far cheaper to decode than the source HEICs.
  private static let jpegQuality: CGFloat = 0.9

  /// Extensions Object Capture writes, plus the obvious neighbours.
  private static let imageExtensions: Set<String> = [
    "heic", "heif", "jpg", "jpeg", "png", "tiff",
  ]

  /// Rewrites [imagesDirectory] into [outputDirectory] at the profile's size,
  /// dropping the blurriest frames if there are more than the profile allows.
  ///
  /// [onProgress] is called with 0…1 as the work proceeds.
  static func prepare(
    imagesDirectory: URL,
    profile: ScanProfile,
    outputDirectory: URL,
    onProgress: (Double) -> Void
  ) throws -> Result {
    let sources = try imageFiles(in: imagesDirectory)
    guard !sources.isEmpty else {
      throw FormaNativeError(
        domain: .reconstruct,
        code: 2004,
        message: "No captured images to reconstruct"
      )
    }

    let selected = select(
      sources: sources,
      profile: profile,
      onProgress: onProgress
    )

    try? FileManager.default.removeItem(at: outputDirectory)
    try FileManager.default.createDirectory(
      at: outputDirectory,
      withIntermediateDirectories: true
    )

    var written = 0
    for (index, source) in selected.enumerated() {
      let destination = outputDirectory
        .appendingPathComponent(String(format: "%05d.jpg", index))
      do {
        try downscale(
          source,
          to: profile.maxImageDimension,
          writing: destination
        )
        written += 1
      } catch {
        // One unreadable frame must not cost the whole scan. A frame that
        // cannot be decoded cannot be matched either, so skipping it is the
        // same decision the reconstruction would have made.
        CameraDebugLogger.reconstruct.error(
          "skipping frame \(source.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
        )
      }
      onProgress(
        scoreShare + (1 - scoreShare) * Double(index + 1) / Double(selected.count)
      )
    }

    guard written > 0 else {
      throw FormaNativeError(
        domain: .reconstruct,
        code: 2005,
        message: "None of the captured images could be prepared"
      )
    }

    return Result(
      directory: outputDirectory,
      inputCount: sources.count,
      outputCount: written,
      maxDimension: profile.maxImageDimension
    )
  }

  // MARK: Frame selection

  /// Picks the frames to reconstruct from, in capture order.
  ///
  /// The capture is already bounded by the profile's frame budget, so this
  /// normally returns everything. It only earns its keep when a session
  /// somehow overran that budget — and then the frames it drops are the
  /// blurriest ones, which are the frames that contribute the least and cost
  /// the most, because a blurred frame also has to be matched and rejected
  /// downstream. The survivors keep their original order so
  /// `sampleOrdering: .sequential` stays true.
  private static func select(
    sources: [URL],
    profile: ScanProfile,
    onProgress: (Double) -> Void
  ) -> [URL] {
    let budget = max(profile.maxShots, minimumKept)
    guard sources.count > budget else {
      // Nothing to decide, and no reason to make the user wait for a
      // measurement that would not change anything.
      onProgress(scoreShare)
      return sources
    }

    var scores: [(index: Int, score: Double)] = []
    scores.reserveCapacity(sources.count)
    for (index, source) in sources.enumerated() {
      scores.append((index, sharpness(of: source)))
      onProgress(scoreShare * Double(index + 1) / Double(sources.count))
    }

    let kept = scores
      .sorted { $0.score > $1.score }
      .prefix(budget)
      .map(\.index)
      .sorted()
    CameraDebugLogger.reconstruct.info(
      "frame budget \(budget) hit — kept the sharpest \(kept.count) of \(sources.count) frames"
    )
    return kept.map { sources[$0] }
  }

  /// Variance of the Laplacian of a small grayscale copy of the frame.
  ///
  /// The standard cheap focus measure: an in-focus frame has crisp edges and
  /// therefore a large second derivative, a motion-blurred one has almost
  /// none. It is only ever used to *rank* frames against each other, never as
  /// an absolute threshold — how sharp "sharp enough" is depends on the
  /// object's own texture, not on us.
  private static func sharpness(of url: URL) -> Double {
    guard let gray = grayscaleThumbnail(of: url) else {
      return 0
    }
    let width = gray.width
    let height = gray.height
    guard width > 2, height > 2 else {
      return 0
    }
    var total = 0.0
    var totalSquared = 0.0
    var count = 0.0
    for y in 1..<(height - 1) {
      for x in 1..<(width - 1) {
        let center = Double(gray.pixels[y * width + x])
        let laplacian = 4 * center
          - Double(gray.pixels[(y - 1) * width + x])
          - Double(gray.pixels[(y + 1) * width + x])
          - Double(gray.pixels[y * width + x - 1])
          - Double(gray.pixels[y * width + x + 1])
        total += laplacian
        totalSquared += laplacian * laplacian
        count += 1
      }
    }
    guard count > 0 else {
      return 0
    }
    let mean = total / count
    return totalSquared / count - mean * mean
  }

  /// One-byte-per-pixel grayscale copy of a frame, at [scoreDimension].
  private struct Grayscale {
    let pixels: [UInt8]
    let width: Int
    let height: Int
  }

  private static func grayscaleThumbnail(of url: URL) -> Grayscale? {
    guard
      let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let image = CGImageSourceCreateThumbnailAtIndex(
        source,
        0,
        thumbnailOptions(maxDimension: scoreDimension) as CFDictionary
      )
    else {
      return nil
    }
    let width = image.width
    let height = image.height
    guard width > 0, height > 0 else {
      return nil
    }
    var pixels = [UInt8](repeating: 0, count: width * height)
    // The context is built inside `withUnsafeMutableBytes` so it can never
    // outlive the buffer it draws into.
    let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
      guard
        let context = CGContext(
          data: buffer.baseAddress,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: width,
          space: CGColorSpaceCreateDeviceGray(),
          bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
      else {
        return false
      }
      context.draw(
        image,
        in: CGRect(x: 0, y: 0, width: width, height: height)
      )
      return true
    }
    guard drawn else {
      return nil
    }
    return Grayscale(pixels: pixels, width: width, height: height)
  }

  // MARK: Writing

  /// Writes [url] to [destination] at most [maxDimension] pixels on its
  /// longest edge, with its orientation baked into the pixels.
  ///
  /// `kCGImageSourceCreateThumbnailWithTransform` is the important part:
  /// Object Capture writes some frames as landscape pixels plus a rotation
  /// flag, and reconstruction reads raw pixels — a frame that reached it
  /// rotated would not align with its neighbours.
  private static func downscale(
    _ url: URL,
    to maxDimension: CGFloat,
    writing destination: URL
  ) throws {
    guard
      let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let image = CGImageSourceCreateThumbnailAtIndex(
        source,
        0,
        thumbnailOptions(maxDimension: maxDimension) as CFDictionary
      )
    else {
      throw FormaNativeError(
        domain: .reconstruct,
        code: 2005,
        message: "Could not read \(url.lastPathComponent)"
      )
    }
    guard
      let handle = CGImageDestinationCreateWithURL(
        destination as CFURL,
        UTType.jpeg.identifier as CFString,
        1,
        nil
      )
    else {
      throw FormaNativeError(
        domain: .reconstruct,
        code: 2005,
        message: "Could not write \(destination.lastPathComponent)"
      )
    }
    CGImageDestinationAddImage(
      handle,
      image,
      [kCGImageDestinationLossyCompressionQuality: jpegQuality] as CFDictionary
    )
    guard CGImageDestinationFinalize(handle) else {
      throw FormaNativeError(
        domain: .reconstruct,
        code: 2005,
        message: "Could not write \(destination.lastPathComponent)"
      )
    }
  }

  /// Options shared by the scoring thumbnail and the written frame.
  private static func thumbnailOptions(maxDimension: CGFloat) -> [CFString: Any] {
    [
      // `FromImageAlways` rather than `IfAbsent`: Object Capture's HEICs do
      // carry embedded thumbnails, and using one would silently reconstruct
      // from a postage stamp.
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension),
      kCGImageSourceShouldCacheImmediately: true,
    ]
  }

  // MARK: Input

  /// Every image file in [directory], in capture order.
  private static func imageFiles(in directory: URL) throws -> [URL] {
    let contents = try FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil
    )
    return contents
      .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
      // Object Capture numbers its frames in capture order, so sorting by
      // name preserves the walk — which is what sequential reconstruction
      // needs to stay an optimisation instead of a wrong assumption.
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
  }
}
