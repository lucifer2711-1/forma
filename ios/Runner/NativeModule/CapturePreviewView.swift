import Flutter
import Foundation
import RealityKit
import SwiftUI
import UIKit

/// The SwiftUI content that renders a live `ObjectCaptureSession` camera
/// feed via Apple's `ObjectCaptureView` (iOS 17 SDK signature: the session
/// is passed directly, not as a binding).
///
/// `CapturePreviewContent` is only ever built for a session the session's
/// owner still holds — `ObjectCaptureView` cannot build a feed for a
/// released session, and draws Apple's own "Cannot make a view for a
/// deinitialized ObjectCaptureSession" message instead.
///
/// In `showsPointCloud` mode it renders the session's **point cloud**
/// instead: the geometry captured so far. That is the honest answer to
/// "what has it actually captured?" — holes in the cloud are the sides still
/// missing — and it is Apple's own live 3D, not a mock-up of one.
///
/// `showShotLocations()` is deliberately NOT used. It draws a line between
/// every shot taken, which over a real scan becomes a hairball laid over the
/// geometry: the object stops being readable and the lines say nothing the
/// dots do not (device-test finding 2026-09-18: "everything is messy, the
/// connections look disorganised"). Which sides are done is answered by the
/// coverage globe, which we draw ourselves.
struct CapturePreviewContent: View {
  let session: ObjectCaptureSession

  /// Whether to show the captured point cloud instead of the camera feed.
  var showsPointCloud = false

  var body: some View {
    Group {
      if showsPointCloud {
        ObjectCapturePointCloudView(session: session)
      } else {
        ObjectCaptureView(session: session)
      }
    }
    .ignoresSafeArea()
  }
}

/// What the `ScanViewportController` stores — insulates it from UIKit types.
@MainActor
protocol CapturePreviewRenderer: AnyObject {
  /// Shows `session` in the hosted preview.
  func bind(session: ObjectCaptureSession)

  /// Blanks the preview (no active session).
  func unbind()

  /// Switches between the live camera feed ([enabled] false) and the
  /// captured point cloud (`true`) — the coverage review.
  func setReviewMode(_ enabled: Bool)
}

/// The plain `UIView` Flutter embeds. It exists to solve two problems that
/// a bare `UIHostingController.view` cannot:
///
/// 1. **Sizing** — Flutter sets the platform view's frame, but nothing
///    resizes the hosted SwiftUI view inside it. A zero-sized host renders
///    nothing at all (black), so `layoutSubviews` keeps the content matched
///    to the container's bounds.
/// 2. **Activation** — SwiftUI only starts rendering when its hosting view
///    joins a window, which happens *after* the platform view is created.
///    `didMoveToWindow` re-drives the appearance lifecycle at that moment.
@MainActor
final class CapturePreviewContainerView: UIView {
  /// Notified when the view joins a window so the renderer can activate
  /// its SwiftUI content. Weak: the renderer owns this view.
  weak var lifecycleDelegate: CapturePreviewRendererImpl?

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil {
      lifecycleDelegate?.kickLifecycle()
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    for subview in subviews where subview.frame != bounds {
      subview.frame = bounds
    }
  }
}

/// Hosts `CapturePreviewContent` in a `UIHostingController` whose root view
/// is swapped when a session binds or unbinds.
///
/// The hosting controller is a stored property on purpose: `UIHostingController`
/// is NOT retained by its own view, so a released controller leaves the
/// SwiftUI content permanently inert — a black preview even while the
/// capture session is alive and feeding frames (device-test finding
/// 2026-09-17: CoreOC logged `processVideoData()` at 30 Hz while the screen
/// stayed black).
@MainActor
final class CapturePreviewRendererImpl: CapturePreviewRenderer {
  private let host: UIHostingController<AnyView>
  private let container: CapturePreviewContainerView

  /// The session this preview is currently rendering, held strongly on
  /// purpose. `UIHostingController` only references it through the view
  /// tree, so without this a session could be released while a view for it
  /// was still installed — which RealityKit reports by drawing "Cannot make
  /// a view for a deinitialized ObjectCaptureSession" over a black feed
  /// (device-test finding 2026-09-18).
  private var boundSession: ObjectCaptureSession?

  /// Whether the hosted content shows the point cloud instead of the feed.
  private var reviewMode = false

  init() {
    host = UIHostingController(rootView: AnyView(Color.black))
    host.view.backgroundColor = .black
    container = CapturePreviewContainerView()
    container.backgroundColor = .black
    container.addSubview(host.view)
    host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    container.lifecycleDelegate = self
  }

  /// The UIKit view Flutter embeds. Only read on the main thread.
  var view: UIView { container }

  func bind(session: ObjectCaptureSession) {
    // A new session starts on the camera feed, never mid-review.
    reviewMode = false
    guard boundSession !== session else {
      return
    }
    boundSession = session
    render()
    CameraDebugLogger.capture.info("preview bound to live capture session")
    kickLifecycle()
  }

  func unbind() {
    guard boundSession != nil else {
      return
    }
    CameraDebugLogger.capture.info("preview unbound (no renderable session)")
    boundSession = nil
    reviewMode = false
    host.rootView = AnyView(Color.black)
  }

  func setReviewMode(_ enabled: Bool) {
    guard reviewMode != enabled else {
      return
    }
    reviewMode = enabled
    CameraDebugLogger.capture.info(
      "preview review mode \(enabled ? "on (point cloud)" : "off (camera)", privacy: .public)"
    )
    render()
    kickLifecycle()
  }

  /// Swaps the hosted SwiftUI content for the current mode.
  private func render() {
    guard let session = boundSession else {
      host.rootView = AnyView(Color.black)
      return
    }
    host.rootView = AnyView(
      CapturePreviewContent(
        session: session,
        showsPointCloud: reviewMode
      )
    )
  }

  /// SwiftUI never sees the appearance callbacks it needs under a Flutter
  /// platform view (the hosting controller has no parent view controller),
  /// so fire them manually once the container is actually on screen.
  func kickLifecycle() {
    guard container.window != nil else {
      // Not on screen yet — `didMoveToWindow` will call back once it is.
      return
    }
    host.beginAppearanceTransition(true, animated: false)
    host.endAppearanceTransition()
    container.setNeedsLayout()
    container.layoutIfNeeded()
  }
}

/// FlutterPlatformView embedding the preview renderer's UIKit view.
///
/// Flutter creates platform views on the main thread, so the MainActor
/// hops below are `assumeIsolated` — synchronous by design.
final class CapturePreviewPlatformView: NSObject, FlutterPlatformView {
  /// Held strongly (and not only by the weak viewport reference) so the
  /// hosting controller survives for as long as the preview is on screen.
  private let renderer: CapturePreviewRendererImpl
  private let controller: ScanViewportController
  private let embeddedView: UIView

  init(
    frame: CGRect,
    viewId: Int64,
    controller: ScanViewportController
  ) {
    let renderer = MainActor.assumeIsolated { CapturePreviewRendererImpl() }
    self.renderer = renderer
    self.controller = controller
    embeddedView = MainActor.assumeIsolated {
      let embedded = renderer.view
      // Size the hosted view to Flutter's layout and keep it tracking
      // resizes — otherwise the SwiftUI content renders at zero size
      // (black screen) even though the session is live.
      embedded.frame = frame
      embedded.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      controller.setPreview(renderer)
      return embedded
    }
  }

  deinit {
    // Flutter disposes platform views on the platform (main) thread. The
    // renderer must stop being a bind target and let go of its session, or
    // a later session swap would leave it rendering a released one.
    let renderer = self.renderer
    let controller = self.controller
    guard Thread.isMainThread else {
      return
    }
    MainActor.assumeIsolated {
      controller.removePreview(renderer)
      renderer.unbind()
    }
  }

  func view() -> UIView {
    embeddedView
  }
}

/// Factory registering the native capture preview under the
/// `com.forma.app/capture_preview` view type (must match CameraPreview.dart).
final class CapturePreviewViewFactory: NSObject, FlutterPlatformViewFactory {
  private let controller: ScanViewportController

  init(controller: ScanViewportController) {
    self.controller = controller
    super.init()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    MainActor.assumeIsolated {
      CapturePreviewPlatformView(
        frame: frame,
        viewId: viewId,
        controller: controller
      )
    }
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}
