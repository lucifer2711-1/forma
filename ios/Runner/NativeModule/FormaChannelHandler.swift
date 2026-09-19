import Flutter
import Foundation

/// Registers Forma's method + event channels and routes Dart calls to the
/// native services. The wire contract must match `IosNativeBridge` (Dart):
/// see architecture.md §3 and `FormaEventSink` for the event payloads.
final class FormaChannelHandler: NSObject, FlutterPlugin {
  private let events: FormaEventSink
  private let captureService: CaptureService
  private let reconstructionService: ReconstructionService
  private let exportService: ExportService
  private let viewport: ScanViewportController
  private let modelViewerHub: ModelViewerHub

  private init(
    events: FormaEventSink,
    exportService: ExportService,
    viewport: ScanViewportController,
    modelViewerHub: ModelViewerHub
  ) {
    self.events = events
    self.exportService = exportService
    self.viewport = viewport
    self.modelViewerHub = modelViewerHub
    self.captureService = CaptureService(events: events, viewport: viewport)
    let export = exportService
    self.reconstructionService = ReconstructionService(
      events: events,
      onModelReady: { scanId, url in
        export.register(model: url, scanId: scanId)
      }
    )
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(
      name: "com.forma.app/native",
      binaryMessenger: registrar.messenger()
    )
    let eventChannel = FlutterEventChannel(
      name: "com.forma.app/capture_events",
      binaryMessenger: registrar.messenger()
    )
    let events = FormaEventSink()
    let exportService = ExportService()
    let viewport = ScanViewportController(events: events)
    // Replay the live session phase whenever Dart (re)subscribes, so a
    // transition that raced ahead of the listener is not lost for good.
    // The sink is not main-actor isolated; the viewport is.
    events.onListenHandler = { [weak viewport] in
      Task { @MainActor in
        viewport?.replayCurrentPhase()
      }
    }
    let modelViewerHub = ModelViewerHub()
    // The viewer reports every zoom change back to Dart, so the on-screen
    // level readout follows a pinch as well as the +/− buttons. The hub is
    // main-actor isolated and registration is not, and plugin registration
    // already runs on the platform thread — so the hop is `assumeIsolated`.
    MainActor.assumeIsolated {
      modelViewerHub.onZoomChanged = { [weak events] factor in
        events?.emitModelZoom(factor)
      }
    }
    let handler = FormaChannelHandler(
      events: events,
      exportService: exportService,
      viewport: viewport,
      modelViewerHub: modelViewerHub
    )
    eventChannel.setStreamHandler(events)
    registrar.addMethodCallDelegate(handler, channel: methodChannel)
    // Camera preview for the capture screen (CameraPreview.dart).
    registrar.register(
      CapturePreviewViewFactory(controller: viewport),
      withId: "com.forma.app/capture_preview"
    )
    // 360° viewer for finished scans (ModelPreview.dart).
    registrar.register(
      ModelPreviewViewFactory(hub: modelViewerHub),
      withId: "com.forma.app/model_viewer"
    )
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isScanSupported":
      result(CapabilityChecker.isScanSupported)
    case "hasLiDAR":
      result(CapabilityChecker.hasLiDAR)
    case "hasActiveCaptureSession":
      Task { [weak self] in
        guard let self else { return }
        let alive = await self.viewport.hasActiveSession
        self.respond(result, alive)
      }
    case "getSessionState":
      Task { [weak self] in
        guard let self else { return }
        let stateName = await self.viewport.sessionStateName
        self.respond(result, stateName)
      }
    case "startCapture":
      Task { [weak self] in
        guard let self else { return }
        do {
          self.respond(result, try await self.captureService.startAsync())
        } catch let error as FormaNativeError {
          self.respond(result, FlutterError.forma(error))
        } catch {
          self.respond(result, self.flutterError(error, domain: .capture))
        }
      }
    case "beginCapturing":
      withScanId(call, result: result, domain: .capture) { scanId in
        try await self.captureService.beginCapturingAsync(scanId: scanId)
      }
    case "finishCapture":
      withScanId(call, result: result, domain: .capture) { scanId in
        try await self.captureService.finishAsync(scanId: scanId)
      }
    case "cancelCapture":
      withScanId(call, result: result, domain: .capture) { scanId in
        await self.captureService.cancelAsync(scanId: scanId)
      }
    case "startReconstruction":
      withScanId(call, result: result, domain: .reconstruct) { scanId in
        self.reconstructionService.start(
          scanId: scanId,
          capture: self.captureService
        )
      }
    case "resetModelView":
      Task { [weak self] in
        guard let self else { return }
        await self.modelViewerHub.resetViews()
        self.respond(result, nil)
      }
    case "zoomModelView":
      Task { [weak self] in
        guard let self else { return }
        let scale = (call.arguments as? [String: Any])?["scale"] as? Double
        await self.modelViewerHub.zoomAll(by: Float(scale ?? 1))
        self.respond(result, nil)
      }
    case "setCaptureReviewMode":
      Task { [weak self] in
        guard let self else { return }
        let enabled =
          (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
        await self.viewport.setReviewMode(enabled)
        self.respond(result, nil)
      }
    case "setTorch":
      Task { [weak self] in
        guard let self else { return }
        let enabled =
          (call.arguments as? [String: Any])?["enabled"] as? Bool ?? false
        await self.captureService.setTorchAsync(enabled: enabled)
        self.respond(result, nil)
      }
    case "setScanProfile":
      Task { [weak self] in
        guard let self else { return }
        let profile = (call.arguments as? [String: Any])?["profile"] as? String
        await self.captureService.setScanProfileAsync(profile)
        self.respond(result, nil)
      }
    case "deleteScan":
      guard
        let scanId = (call.arguments as? [String: Any])?["scanId"] as? String
      else {
        result(flutterError(
          FormaNativeError(
            domain: .store,
            code: 4001,
            message: "Missing scanId"
          ),
          domain: .store
        ))
        return
      }
      // Files first, then the row is removed by the caller: a crash in
      // between leaves an orphaned row pointing at a missing model, which
      // the library already reports honestly — the reverse order would leave
      // hundreds of megabytes on disk with nothing referencing them.
      FormaStorage.deleteScanFiles(scanId: scanId)
      result(nil)
    case "exportModel":
      exportModel(call, result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func exportModel(
    _ call: FlutterMethodCall,
    _ result: @escaping FlutterResult
  ) {
    guard
      let arguments = call.arguments as? [String: Any],
      let scanId = arguments["scanId"] as? String,
      let format = arguments["format"] as? String
    else {
      result(flutterError(
        FormaNativeError(
          domain: .export,
          code: 3004,
          message: "Missing arguments"
        ),
        domain: .export
      ))
      return
    }
    do {
      let url = try exportService.export(scanId: scanId, format: format)
      result(url.path)
    } catch let error as FormaNativeError {
      result(FlutterError.forma(error))
    } catch {
      result(flutterError(error, domain: .export))
    }
  }

  private func withScanId(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult,
    domain: FormaErrorDomain,
    body: @escaping (String) async throws -> Void
  ) {
    guard
      let arguments = call.arguments as? [String: Any],
      let scanId = arguments["scanId"] as? String
    else {
      result(flutterError(
        FormaNativeError(
          domain: domain,
          code: 0000,
          message: "Missing scanId"
        ),
        domain: domain
      ))
      return
    }
    Task { [weak self] in
      guard let self else { return }
      do {
        try await body(scanId)
        self.respond(result, nil)
      } catch let error as FormaNativeError {
        self.respond(result, FlutterError.forma(error))
      } catch {
        self.respond(result, self.flutterError(error, domain: domain))
      }
    }
  }

  /// Sends a method-channel reply on the platform thread.
  ///
  /// Async handler continuations resume on the Swift concurrent executor,
  /// NOT the main thread — and Flutter requires replies on the platform
  /// thread. Off-main replies are silently dropped, leaving the Dart future
  /// hanging forever (device-test finding 2026-09-16: startCapture never
  /// resolved, so the capture screen sat on "Starting camera…").
  private func respond(_ result: @escaping FlutterResult, _ value: Any?) {
    if Thread.isMainThread {
      result(value)
    } else {
      DispatchQueue.main.async { result(value) }
    }
  }

  private func flutterError(
    _ error: Error,
    domain: FormaErrorDomain
  ) -> FlutterError {
    FlutterError(code: domain.rawValue, message: "\(error)", details: nil)
  }
}
