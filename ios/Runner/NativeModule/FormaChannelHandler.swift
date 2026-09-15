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

  private init(
    events: FormaEventSink,
    exportService: ExportService,
    viewport: ScanViewportController
  ) {
    self.events = events
    self.exportService = exportService
    self.viewport = viewport
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
    let handler = FormaChannelHandler(
      events: events,
      exportService: exportService,
      viewport: viewport
    )
    eventChannel.setStreamHandler(events)
    registrar.addMethodCallDelegate(handler, channel: methodChannel)
    // Camera preview for the capture screen (CameraPreview.dart).
    registrar.register(
      CapturePreviewViewFactory(controller: viewport),
      withId: "com.forma.app/capture_preview"
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
        result(self.viewport.hasActiveSession)
      }
    case "startCapture":
      Task { [weak self] in
        guard let self else { return }
        do {
          result(try await self.captureService.startAsync())
        } catch let error as FormaNativeError {
          result(FlutterError.forma(error))
        } catch {
          result(self.flutterError(error, domain: .capture))
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
        result(nil)
      } catch let error as FormaNativeError {
        result(FlutterError.forma(error))
      } catch {
        result(self.flutterError(error, domain: domain))
      }
    }
  }

  private func flutterError(
    _ error: Error,
    domain: FormaErrorDomain
  ) -> FlutterError {
    FlutterError(code: domain.rawValue, message: "\(error)", details: nil)
  }
}
