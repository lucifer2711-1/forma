import Flutter
import Foundation
import RealityKit
import UIKit

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

  /// Returns every mounted viewer to its framing position.
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
/// `ARView` in `.nonAR` camera mode with `enableCameraControls` provides the
/// orbit/pinch/pan gestures, so 360° inspection needs no hand-rolled gesture
/// math. Lighting is three directional lights on purpose: an image-based
/// lighting environment requires a bundled HDR asset, and a PBR model with no
/// light renders as a black silhouette — which is exactly what a viewer must
/// never look like.
@MainActor
final class ModelPreviewRenderer {
  private let arView: ARView
  private let statusLabel: UILabel

  /// Half-extent used to place the camera; set from the loaded model so an
  /// object scanned at any scale fills the screen.
  private var modelRadius: Float = 0.5

  init(frame: CGRect) {
    arView = ARView(
      frame: frame,
      cameraMode: .nonAR,
      automaticallyConfigureSession: false
    )
    arView.backgroundColor = .black
    arView.environment.background = .color(.black)
    arView.enableCameraControls = true
    arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    statusLabel = UILabel(frame: .zero)
    statusLabel.textColor = .white
    statusLabel.font = .preferredFont(forTextStyle: .callout)
    statusLabel.textAlignment = .center
    statusLabel.numberOfLines = 0
    statusLabel.translatesAutoresizingMaskIntoConstraints = false
    statusLabel.isHidden = true
    arView.addSubview(statusLabel)
    NSLayoutConstraint.activate([
      statusLabel.centerXAnchor.constraint(equalTo: arView.centerXAnchor),
      statusLabel.centerYAnchor.constraint(equalTo: arView.centerYAnchor),
      statusLabel.leadingAnchor.constraint(
        greaterThanOrEqualTo: arView.leadingAnchor,
        constant: 32
      ),
    ])
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

  /// Returns the camera to a framing position showing the whole model.
  func resetView() {
    let radius = modelRadius
    var transform = Transform(pitch: -0.12, yaw: 0, roll: 0)
    transform.translation = SIMD3<Float>(0, radius * 0.35, radius * 2.6)
    arView.cameraTransform = transform
  }

  private func present(_ entity: Entity) {
    arView.scene.anchors.removeAll()

    // Centre the model on the origin: the built-in camera controls orbit the
    // scene origin, so an off-centre model would swing out of frame.
    let bounds = entity.visualBounds(relativeTo: nil)
    modelRadius = max(bounds.boundingRadius, 0.01)
    entity.position -= bounds.center

    let holder = Entity()
    holder.addChild(entity)
    holder.addChild(makeLightRig(radius: modelRadius))

    let anchor = AnchorEntity(world: .zero)
    anchor.addChild(holder)
    arView.scene.addAnchor(anchor)

    resetView()
    statusLabel.isHidden = true
    CameraDebugLogger.capture.info("model viewer ready")
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
