import Flutter
import Foundation

/// Forma native error domains. Raw values match the `PlatformException`
/// codes the Dart bridge maps to `FormaError` subclasses.
enum FormaErrorDomain: String {
  case unsupported = "UNSUPPORTED"
  case capture = "CAPTURE"
  case reconstruct = "RECONSTRUCT"
  case export = "EXPORT"
  case store = "STORE"
}

/// A native-side error carrying the channel domain and event code.
struct FormaNativeError: Error {
  let domain: FormaErrorDomain
  let code: Int
  let message: String
}

extension FlutterError {
  /// Wraps a [FormaNativeError] for the method channel.
  static func forma(_ error: FormaNativeError) -> FlutterError {
    FlutterError(code: error.domain.rawValue, message: error.message, details: error.code)
  }
}
