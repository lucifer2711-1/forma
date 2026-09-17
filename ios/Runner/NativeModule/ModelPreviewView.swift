import Flutter
import Foundation
import RealityKit
import UIKit
import simd

/// Keeps the mounted model viewers addressable so the Dart chrome can drive
/// them (the "reset view" affordance) without knowing about platform views.
///
/// Weak, like the capture viewport's preview registry: a viewer that Flutter
/// has disposed must never be kept alive (or acted on) by this hub.
@MainActor
final class ModelViewerHub {
  private var viewers: [ObjectIdentifier: WeakViewer] = [:]

  /// Called with a viewer's current magnification after every change, so
  /// the Dart chrome can show the zoom level. Without a readout a zoom that
  /// silently did nothing looked identical to one the gestures never
  /// delivered (device-test finding 2026-09-18: "+ / − do not work").
  var onZoomChanged: ((Float) -> Void)?

  /// Nonisolated so plugin registration (a synchronous, nonisolated context)
  /// can create the hub — the same reason `ScanViewportController` does it.
  nonisolated init() {}

  /// Registers a freshly mounted viewer.
  func register(_ viewer: ModelPreviewRenderer) {
    viewers[ObjectIdentifier(viewer)] = WeakViewer(viewer)
    prune()
  }

  /// Forgets a viewer whose platform view was disposed.
  func unregister(_ viewer: ModelPreviewRenderer) {
    viewers.removeValue(forKey: ObjectIdentifier(viewer))
  }

  /// Returns every mounted viewer to its framing position and angle.
  func resetViews() {
    prune()
    guard !viewers.isEmpty else {
      logNoViewer("reset")
      return
    }
    for viewer in viewers.values.compactMap(\.viewer) {
      viewer.resetView()
    }
  }

  /// Multiplies every mounted viewer's zoom by [scale] (> 1 zooms in).
  ///
  /// Driven by the on-screen +/− controls: a pinch is the natural gesture,
  /// but the buttons guarantee a way to zoom on any device/OS build.
  func zoomAll(by scale: Float) {
    prune()
    guard !viewers.isEmpty else {
      // The command arrived with nothing mounted: the platform view never
      // registered (or was disposed). Logged at error level so it reaches
      // the device log — this is the difference between "Dart never called
      // native" and "native ignored it".
      logNoViewer("zoom by \(scale)")
      return
    }
    for viewer in viewers.values.compactMap(\.viewer) {
      viewer.zoom(by: scale)
    }
  }

  /// Reports a viewer's magnification to Dart.
  func reportZoom(_ factor: Float) {
    onZoomChanged?(factor)
  }

  private func logNoViewer(_ what: String) {
    CameraDebugLogger.capture.error(
      "model viewer \(what, privacy: .public): no live viewer registered"
    )
  }

  private func prune() {
    viewers = viewers.filter { $0.value.viewer != nil }
  }
}

@MainActor
private final class WeakViewer {
  weak var viewer: ModelPreviewRenderer?

  init(_ viewer: ModelPreviewRenderer) {
    self.viewer = viewer
  }
}

/// Shows a finished scan's USDZ in a RealityKit view the user can inspect
/// from any side.
///
/// The camera stays fixed and the *model* moves: iOS `ARView` exposes neither
/// camera controls (`enableCameraControls` is macOS-only) nor a settable
/// `cameraTransform` (get-only on iOS), so the 360° interaction is a pan
/// gesture that spins the model and a pinch that changes how far away it sits
/// in front of the camera — the same turntable behaviour, with no reliance on
/// platform-gated API.
///
/// Lighting is three directional lights in a rig that does NOT rotate with
/// the model: an image-based environment needs a bundled HDR asset, and a
/// lamp that spins with the object would keep the shading frozen and hide
/// exactly the shape detail the user is turning the model to see.
@MainActor
final class ModelPreviewRenderer: NSObject, UIGestureRecognizerDelegate {
  private let arView: ARView
  private let statusLabel: UILabel

  /// The hub that reports this viewer's zoom back to Dart.
  private let hub: ModelViewerHub

  /// Rotating node holding the model, centred on its own origin.
  private let modelNode = Entity()

  /// Non-rotating node holding the lights, kept at the model's depth.
  private let rigNode = Entity()

  /// Half-extent of the loaded model; drives framing and zoom limits.
  private var modelRadius: Float = 0.5

  private var distance: Float = 1.5
  private var yaw: Float = 0
  private var pitch: Float = 0

  /// Last magnification reported to Dart, so a pinch does not spam the
  /// event channel once per frame.
  private var reportedZoom: Float = 1

  private static let radiansPerPoint: Float = 0.01
  private static let maxPitch: Float = 1.2

  /// How close the model may come to the camera, and how far it may sit,
  /// as multiples of its own radius.
  ///
  /// These were 1.4 … 8: only a 1.86× magnification was reachable, so the
  /// zoom hit its stop after two taps and a pinch had nowhere to go —
  /// indistinguishable from a zoom that does not work at all (device-test
  /// finding 2026-09-18: "I cannot see the object in more detail"). The
  /// range now runs from right at the surface (0.8 × radius, so the object
  /// overflows the screen and detail is inspectable) out to 20 × radius.
  private static let minDistanceFactor: Float = 0.8
  private static let maxDistanceFactor: Float = 20
  private static let framingDistanceFactor: Float = 2.6

  /// Never let the camera reach the near clip plane on a very small model.
  private static let minAbsoluteDistance: Float = 0.015

  var framingDistance: Float { modelRadius * Self.framingDistanceFactor }

  /// Current magnification relative to the framing view (1 = framed).
  var zoomFactor: Float { framingDistance / max(distance, 0.0001) }

  init(frame: CGRect, hub: ModelViewerHub) {
    self.hub = hub
    arView = ARView(
      frame: frame,
      cameraMode: .nonAR,
      automaticallyConfigureSession: false
    )
    arView.backgroundColor = .black
    arView.environment.background = .color(.black)
    arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    // A pinch recogniser needs two simultaneous touches. Flutter's iOS
    // platform-view wrapper delivers them, but the embedded view must opt
    // in or UIKit reports only the first touch of the sequence.
    arView.isMultipleTouchEnabled = true

    statusLabel = UILabel(frame: .zero)
    statusLabel.textColor = .white
    statusLabel.font = .preferredFont(forTextStyle: .callout)
    statusLabel.textAlignment = .center
    statusLabel.numberOfLines = 0
    statusLabel.translatesAutoresizingMaskIntoConstraints = false

    super.init()

    arView.addSubview(statusLabel)
    NSLayoutConstraint.activate([
      statusLabel.centerXAnchor.constraint(equalTo: arView.centerXAnchor),
      statusLabel.centerYAnchor.constraint(equalTo: arView.centerYAnchor),
      statusLabel.leadingAnchor.constraint(
        greaterThanOrEqualTo: arView.leadingAnchor,
        constant: 32
      ),
    ])

    let anchor = AnchorEntity(world: .zero)
    anchor.addChild(modelNode)
    anchor.addChild(rigNode)
    arView.scene.addAnchor(anchor)

    // Gesture conflict that made pinch-to-zoom dead on device: with a pan
    // that accepts any number of touches (the default) and no simultaneous
    // recognition, the pan claims the two-finger sequence and UIKit refuses
    // to let the pinch begin — so the model orbited but never zoomed
    // (device-test finding 2026-09-18).
    //
    // Fix is twofold: the pan is limited to exactly one finger (a second
    // finger makes it fail, handing the sequence to the pinch), and the
    // delegate below lets the two recognise together, so an orbit can turn
    // straight into a pinch without lifting a finger.
    let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
    pan.minimumNumberOfTouches = 1
    pan.maximumNumberOfTouches = 1
    pan.delegate = self
    arView.addGestureRecognizer(pan)

    let pinch = UIPinchGestureRecognizer(
      target: self,
      action: #selector(handlePinch)
    )
    pinch.delegate = self
    arView.addGestureRecognizer(pinch)
  }

  /// Lets the orbit and the zoom run at the same time — without this, the
  /// first recogniser to begin blocks the other for the whole touch
  /// sequence.
  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    true
  }

  /// The UIKit view Flutter embeds.
  var view: UIView { arView }

  /// Loads the model at [path] and frames it. Failures are stated on screen
  /// rather than leaving a black rectangle.
  func load(path: String) {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: path) else {
      CameraDebugLogger.capture.error(
        "model viewer: no file at \(path, privacy: .public)"
      )
      showStatus("This model file is missing.")
      return
    }
    showStatus("Opening model…")
    Task { [weak self] in
      do {
        let entity = try await Entity.load(contentsOf: url)
        self?.present(entity)
      } catch {
        CameraDebugLogger.capture.error(
          "model viewer: load failed for \(path, privacy: .public) — \(error.localizedDescription, privacy: .public)"
        )
        self?.showStatus("This model could not be opened.")
      }
    }
  }

  /// Returns the model to a framing distance and a straight-on angle.
  func resetView() {
    yaw = 0
    pitch = 0
    distance = framingDistance
    applyTransform()
    reportZoom()
  }

  /// Multiplies the zoom by [scale]: > 1 pulls the model closer, < 1 away.
  ///
  /// Clamped to [minDistanceFactor, maxDistanceFactor] × the model's radius
  /// so the object can neither pass through the camera nor shrink to a dot.
  func zoom(by scale: Float) {
    guard scale > 0, scale != 1 else {
      return
    }
    let minDistance = max(
      modelRadius * Self.minDistanceFactor,
      Self.minAbsoluteDistance
    )
    let maxDistance = modelRadius * Self.maxDistanceFactor
    let previous = distance
    distance = min(max(distance / scale, minDistance), maxDistance)
    applyTransform()
    CameraDebugLogger.capture.info(
      "model viewer zoom ×\(scale, privacy: .public): distance \(previous, privacy: .public) → \(self.distance, privacy: .public) (×\(self.zoomFactor, privacy: .public))"
    )
    reportZoom()
  }

  /// Publishes the magnification when it has actually moved, so the on-screen
  /// readout follows a pinch instead of only the buttons.
  private func reportZoom() {
    let factor = zoomFactor
    guard abs(factor - reportedZoom) >= 0.05 else {
      return
    }
    reportedZoom = factor
    hub.reportZoom(factor)
  }

  // MARK: Gestures

  /// Turntable orbit: horizontal drag spins the model, vertical drag tilts it.
  @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
    let translation = gesture.translation(in: arView)
    gesture.setTranslation(.zero, in: arView)
    yaw -= Float(translation.x) * Self.radiansPerPoint
    pitch -= Float(translation.y) * Self.radiansPerPoint
    pitch = min(max(pitch, -Self.maxPitch), Self.maxPitch)
    applyTransform()
  }

  /// Pinch moves the model closer to or farther from the fixed camera.
  @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
    let scale = Float(gesture.scale)
    // Reset every callback: `scale` is cumulative since the gesture began.
    gesture.scale = 1
    if gesture.state == .began {
      // Logged so a pinch that never reaches the renderer is visible in the
      // device log instead of being guessed at (device-test finding
      // 2026-09-18: the model rotated but never zoomed).
      CameraDebugLogger.capture.info("model viewer pinch began")
    }
    zoom(by: scale)
  }

  private func present(_ entity: Entity) {
    // Centre the model on its own origin so the orbit pivots around the
    // object instead of around a corner of its bounding box.
    let bounds = entity.visualBounds(relativeTo: nil)
    modelRadius = max(bounds.boundingRadius, 0.01)
    entity.position -= bounds.center

    modelNode.children.removeAll()
    modelNode.addChild(entity)

    rigNode.children.removeAll()
    rigNode.addChild(makeLightRig(radius: modelRadius))

    resetView()
    statusLabel.isHidden = true
    CameraDebugLogger.capture.info("model viewer ready")
  }

  private func applyTransform() {
    let offset = SIMD3<Float>(0, 0, -distance)
    modelNode.transform.translation = offset
    modelNode.transform.rotation =
      simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
      * simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
    // Lights travel with the model's depth but never spin with it.
    rigNode.transform.translation = offset
  }

  /// Key, fill and rim lights so every side of a rotating model stays legible.
  private func makeLightRig(radius: Float) -> Entity {
    let rig = Entity()
    let distance = radius * 4

    let key = DirectionalLight()
    key.light.intensity = 6000
    key.look(
      at: .zero,
      from: SIMD3<Float>(distance, distance * 1.4, distance),
      relativeTo: nil
    )
    rig.addChild(key)

    let fill = DirectionalLight()
    fill.light.intensity = 2500
    fill.look(
      at: .zero,
      from: SIMD3<Float>(-distance, distance * 0.4, distance),
      relativeTo: nil
    )
    rig.addChild(fill)

    let rim = DirectionalLight()
    rim.light.intensity = 3000
    rim.look(
      at: .zero,
      from: SIMD3<Float>(0, distance * 0.6, -distance),
      relativeTo: nil
    )
    rig.addChild(rim)

    return rig
  }

  private func showStatus(_ text: String) {
    statusLabel.text = text
    statusLabel.isHidden = false
  }
}

/// FlutterPlatformView embedding the model renderer.
///
/// Flutter creates platform views on the main thread, so the MainActor hop is
/// `assumeIsolated` — synchronous by design.
final class ModelPreviewPlatformView: NSObject, FlutterPlatformView {
  private let renderer: ModelPreviewRenderer
  private let hub: ModelViewerHub
  private let embeddedView: UIView

  init(frame: CGRect, viewId: Int64, hub: ModelViewerHub, path: String?) {
    let renderer = MainActor.assumeIsolated {
      ModelPreviewRenderer(frame: frame, hub: hub)
    }
    self.renderer = renderer
    self.hub = hub
    embeddedView = MainActor.assumeIsolated {
      hub.register(renderer)
      if let path {
        renderer.load(path: path)
      }
      return renderer.view
    }
  }

  deinit {
    // Flutter disposes platform views on the platform (main) thread.
    guard Thread.isMainThread else {
      return
    }
    let renderer = self.renderer
    let hub = self.hub
    MainActor.assumeIsolated {
      hub.unregister(renderer)
    }
  }

  func view() -> UIView {
    embeddedView
  }
}

/// Factory registering the model viewer under `com.forma.app/model_viewer`
/// (must match `ModelPreview.dart`). The model path arrives as the platform
/// view's creation parameter: `{"path": "/…/Model.usdz"}`.
final class ModelPreviewViewFactory: NSObject, FlutterPlatformViewFactory {
  private let hub: ModelViewerHub

  init(hub: ModelViewerHub) {
    self.hub = hub
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let path = (args as? [String: Any])?["path"] as? String
    return MainActor.assumeIsolated {
      ModelPreviewPlatformView(
        frame: frame,
        viewId: viewId,
        hub: hub,
        path: path
      )
    }
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}
