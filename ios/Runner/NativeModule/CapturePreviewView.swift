import Flutter
import Foundation
import RealityKit
import SwiftUI
import UIKit

/// The SwiftUI content that renders a live `ObjectCaptureSession` camera
/// feed via Apple's `ObjectCaptureView` (iOS 17 SDK signature: the session
/// is passed directly, not as a binding).
struct CapturePreviewContent: View {
  let session: ObjectCaptureSession

  var body: some View {
    ObjectCaptureView(session: session)
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
    host.rootView = AnyView(CapturePreviewContent(session: session))
    kickLifecycle()
  }

  func unbind() {
    host.rootView = AnyView(Color.black)
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
  private let embeddedView: UIView

  init(
    frame: CGRect,
    viewId: Int64,
    controller: ScanViewportController
  ) {
    let renderer = MainActor.assumeIsolated { CapturePreviewRendererImpl() }
    self.renderer = renderer
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
