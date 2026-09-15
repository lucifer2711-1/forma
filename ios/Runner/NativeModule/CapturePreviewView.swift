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

/// Hosts `CapturePreviewContent` in a `UIHostingController` whose root view
/// is swapped when a session binds or unbinds.
@MainActor
final class CapturePreviewRendererImpl: CapturePreviewRenderer {
  private let host: UIHostingController<AnyView>

  init() {
    host = UIHostingController(rootView: AnyView(Color.black))
    host.view.backgroundColor = .black
  }

  /// The UIKit view Flutter embeds. Only read on the main thread.
  var view: UIView { host.view }

  func bind(session: ObjectCaptureSession) {
    host.rootView = AnyView(CapturePreviewContent(session: session))
    kickLifecycle()
  }

  func unbind() {
    host.rootView = AnyView(Color.black)
  }

  /// The hosting controller never joins the window hierarchy under a
  /// Flutter platform view, so SwiftUI misses the appearance callbacks
  /// that let content activate. Fire them manually once.
  private func kickLifecycle() {
    host.beginAppearanceTransition(true, animated: false)
    host.endAppearanceTransition()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
  }
}

/// FlutterPlatformView embedding the preview renderer's UIKit view.
///
/// Flutter creates platform views on the main thread, so the MainActor
/// hops below are `assumeIsolated` — synchronous by design.
final class CapturePreviewPlatformView: NSObject, FlutterPlatformView {
  private let embeddedView: UIView

  init(
    frame: CGRect,
    viewId: Int64,
    controller: ScanViewportController
  ) {
    embeddedView = MainActor.assumeIsolated {
      let renderer = CapturePreviewRendererImpl()
      // Size the hosted view to Flutter's layout and keep it tracking
      // resizes — otherwise the SwiftUI content renders at zero size
      // (black screen) even though the session is live.
      renderer.view.frame = frame
      renderer.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      controller.setPreview(renderer)
      return renderer.view
    }
    super.init()
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
