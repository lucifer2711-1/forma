import Flutter
import Foundation

/// Registers Forma's method + event channels and routes Dart calls to the
/// native services. The wire contract must match `IosNativeBridge` (Dart):
///
/// MethodChannel `com.forma.app/native`:
/// `isScanSupported`, `hasLiDAR`, `startCapture`, `finishCapture{scanId}`,
/// `cancelCapture{scanId}`, `startReconstruction{scanId}`,
/// `exportModel{scanId, format}`.
///
/// EventChannel `com.forma.app/capture_events` — see `FormaEventSink`.
final class FormaChannelHandler: NSObject, FlutterPlugin {
  private let events: FormaEventSink
  private let captureService: CaptureService
  private let reconstructionService: ReconstructionService
  private let exportService: ExportService

  private init(events: FormaEventSink, exportService: ExportService) {
    self.events = events
    self.exportService = exportService
    self.captureService = CaptureService(events: events)
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
    let handler = FormaChannelHandler(events: events, exportService: exportService)
    eventChannel.setStreamHandler(events)
    registrar.addMethodCallDelegate(handler, channel: methodChannel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isScanSupported":
      result(CapabilityChecker.isScanSupported)
    case "hasLiDAR":
      result(CapabilityChecker.hasLiDAR)
    case "startCapture":
      startCapture(result)
    case "finishCapture":
      withScanId(call, result, domain: .capture) { scanId in
        try captureService.finish(scanId: scanId)
        result(nil)
      }
    case "cancelCapture":
      withScanId(call, result, domain: .capture) { scanId in
        captureService.cancel(scanId: scanId)
        reconstructionService.cancel(scanId: scanId)
        result(nil)
      }
    case "startReconstruction":
      withScanId(call, result, domain: .reconstruct) { scanId in
        reconstructionService.start(scanId: scanId, capture: captureService)
        result(nil)
      }
    case "exportModel":
      exportModel(call, result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startCapture(_ result: @escaping FlutterResult) {
    do {
      result(try captureService.start())
    } catch let error as FormaNativeError {
      result(FlutterError.forma(error))
    } catch {
      result(FlutterError(code: FormaErrorDomain.capture.rawValue, message: "\(error)", details: nil))
    }
  }

  private func exportModel(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let scanId = arguments["scanId"] as? String,
      let format = arguments["format"] as? String
    else {
      result(FlutterError(code: FormaErrorDomain.export.rawValue, message: "Missing arguments", details: nil))
      return
    }
    do {
      let url = try exportService.export(scanId: scanId, format: format)
      result(url.path)
    } catch let error as FormaNativeError {
      result(FlutterError.forma(error))
    } catch {
      result(FlutterError(code: FormaErrorDomain.export.rawValue, message: "\(error)", details: nil))
    }
  }

  private func withScanId(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult,
    domain: FormaErrorDomain,
    body: (String) throws -> Void
  ) {
    guard
      let arguments = call.arguments as? [String: Any],
      let scanId = arguments["scanId"] as? String
    else {
      result(FlutterError(code: domain.rawValue, message: "Missing scanId", details: nil))
      return
    }
    do {
      try body(scanId)
    } catch let error as FormaNativeError {
      result(FlutterError.forma(error))
    } catch {
      result(FlutterError(code: domain.rawValue, message: "\(error)", details: nil))
    }
  }
}
