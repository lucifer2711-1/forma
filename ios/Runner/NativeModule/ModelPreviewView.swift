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
    for viewer in viewers.values.compactMap(\.viewer) {
      viewer.resetView()
    }
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
final class ModelPreviewRenderer: NSObject {
  private let arView: ARView
  private let statusLabel: UILabel

  /// Rotating node holding the model, centred on its own origin.
  private let modelNode = Entity()

  /// Non-rotating node holding the lights, kept at the model's depth.
  private let rigNode = Entity()

  /// Half-extent of the loaded model; drives framing and zoom limits.
  private var modelRadius: Float = 0.5

  private var distance: Float = 1.5
  private var yaw: Float = 0
  private var pitch: Float = 0

  private static let radiansPerPoint: Float = 0.01
  private static let maxPitch: Float = 1.2

  init(frame: CGRect) {
    arView = ARView(
      frame: frame,
      cameraMode: .nonAR,
      automaticallyConfigureSession: false
    )
    arView.backgroundColor = .black
    arView.environment.background = .color(.black)
    arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

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

    arView.addGestureRecognizer(
      UIPanGestureRecognizer(target: self, action: #selector(handlePan))
    )
    arView.addGestureRecognizer(
      UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
    )
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
    distance = modelRadius * 2.6
    applyTransform()
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
    gesture.scale = 1
    guard scale > 0, scale != 1 else {
      return
    }
    distance = min(
      max(distance / scale, modelRadius * 1.4),
      modelRadius * 8
    )
    applyTransform()
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
      ModelPreviewRenderer(frame: frame)
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
