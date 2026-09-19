import 'dart:async';

import 'package:flutter/services.dart';

import 'package:forma/core/errors/forma_error.dart';
import 'package:forma/platform/native_bridge/capture_state.dart';
import 'package:forma/platform/native_bridge/native_bridge.dart';

/// The real iOS implementation of [NativeBridge].
///
/// Protocol (must match FormaChannelHandler.swift — see architecture.md §3):
/// - MethodChannel `com.forma.app/native`: command → result or FlutterError.
/// - EventChannel `com.forma.app/capture_events`: maps
///   `{"type": "phase", "value": "capturing"}` etc.
///
/// Event types: `phase` (CapturePhase name), `feedback` (CaptureFeedbackType
/// name), `capture_progress` ({shots, passComplete, targetShots, maxShots,
/// budgetReached}), `scan_direction` ({x, y, z, kept}), `model_zoom`
/// (double), `reconstruction_progress` (double), `reconstruction_stage`
/// ({stage, remainingSeconds?}), `reconstruction_complete` (model file path),
/// `error` ({code, message}).
class IosNativeBridge implements NativeBridge {
  IosNativeBridge({MethodChannel? commands, EventChannel? events})
      : _commands = commands ?? const MethodChannel('com.forma.app/native'),
        _events = events ?? const EventChannel('com.forma.app/capture_events');

  final MethodChannel _commands;
  final EventChannel _events;

  final _phaseController = StreamController<CapturePhase>.broadcast();
  final _feedbackController = StreamController<CaptureFeedback>.broadcast();
  final _captureProgressController =
      StreamController<CaptureProgress>.broadcast();
  final _directionController = StreamController<ScanDirection>.broadcast();
  final _modelZoomController = StreamController<double>.broadcast();
  final _progressController = StreamController<double>.broadcast();
  final _stageController = StreamController<ReconstructionStage>.broadcast();
  final _completeController = StreamController<String>.broadcast();
  final _errorController = StreamController<BridgeError>.broadcast();

  StreamSubscription<dynamic>? _eventSub;
  bool _disposed = false;

  void _ensureSubscribed() {
    if (_eventSub != null || _disposed) {
      return;
    }
    _eventSub = _events.receiveBroadcastStream().listen(
          _onEvent,
          onError: (Object e) => _errorController.add(
            BridgeError(code: -1, message: e.toString()),
          ),
        );
  }

  void _onEvent(dynamic event) {
    if (event is! Map || !event.containsKey('type')) {
      return;
    }
    switch (event['type'] as String) {
      case 'phase':
        final value = event['value'] as String?;
        _phaseController.add(_parsePhase(value));
      case 'feedback':
        final value = event['value'] as String?;
        _feedbackController.add(CaptureFeedback(_parseFeedback(value)));
      case 'capture_progress':
        final payload = event['value'];
        _captureProgressController.add(
          CaptureProgress(
            shots: (payload is Map ? payload['shots'] : null) as int? ?? 0,
            passComplete:
                (payload is Map ? payload['passComplete'] : null) as bool? ??
                    false,
            targetShots:
                (payload is Map ? payload['targetShots'] : null) as int? ?? 0,
            maxShots:
                (payload is Map ? payload['maxShots'] : null) as int? ?? 0,
            budgetReached:
                (payload is Map ? payload['budgetReached'] : null) as bool? ??
                    false,
          ),
        );
      case 'scan_direction':
        final payload = event['value'];
        if (payload is Map) {
          final direction = ScanDirection(
            x: (payload['x'] as num?)?.toDouble() ?? 0,
            y: (payload['y'] as num?)?.toDouble() ?? 0,
            z: (payload['z'] as num?)?.toDouble() ?? 0,
            isKept: payload['kept'] as bool? ?? true,
          );
          if (direction.isUsable) {
            _directionController.add(direction);
          }
        }
      case 'model_zoom':
        _modelZoomController.add((event['value'] as num?)?.toDouble() ?? 1);
      case 'reconstruction_progress':
        _progressController.add((event['value'] as num?)?.toDouble() ?? 0);
      case 'reconstruction_stage':
        final payload = event['value'];
        if (payload is Map && payload['stage'] is String) {
          _stageController.add(
            ReconstructionStage(
              stage: payload['stage'] as String,
              remainingSeconds:
                  (payload['remainingSeconds'] as num?)?.round(),
            ),
          );
        }
      case 'reconstruction_complete':
        final value = event['value'] as String?;
        if (value != null) {
          _completeController.add(value);
        }
      case 'error':
        final payload = event['value'];
        _errorController.add(
          BridgeError(
            code: (payload is Map ? payload['code'] : null) as int? ?? -1,
            message: (payload is Map ? payload['message'] : null) as String? ??
                'Unknown native error',
          ),
        );
    }
  }

  CapturePhase _parsePhase(String? value) => CapturePhase.values.firstWhere(
        (p) => p.name == value,
        orElse: () => CapturePhase.failed,
      );

  CaptureFeedbackType _parseFeedback(String? value) =>
      CaptureFeedbackType.values.firstWhere(
        (f) => f.name == value,
        orElse: () => CaptureFeedbackType.none,
      );

  Future<T?> _invoke<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      return await _commands.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw _mapError(e);
    } on MissingPluginException {
      // No native handler (non-iOS host or module not registered).
      throw const UnsupportedDeviceError('Native module not registered');
    }
  }

  FormaError _mapError(PlatformException e) {
    final debug = '${e.code}: ${e.message ?? ''} ${e.details ?? ''}';
    // Native error detail carries the numeric code — specific codes get
    // specific, actionable messages (rules.md §7 honesty).
    final nativeCode = e.details is int ? e.details as int : null;
    return switch (e.code) {
      'UNSUPPORTED' => UnsupportedDeviceError(debug),
      'CAPTURE' when nativeCode == 1002 || nativeCode == 1004 =>
        ScanSessionEndedError(debug),
      'CAPTURE' when nativeCode == 1005 => CameraPermissionError(debug),
      'CAPTURE' when nativeCode == 1006 => CaptureNotReadyError(debug),
      'CAPTURE' when nativeCode == 1007 => StorageFullError(debug),
      'CAPTURE' => CaptureError(debug),
      'RECONSTRUCT' => ReconstructionError(debug),
      'EXPORT' => ExportError(debug),
      'STORE' => StoreError(debug),
      _ => UnknownError(debug),
    };
  }

  @override
  Future<bool> isScanSupported() async =>
      await _invoke<bool>('isScanSupported') ?? false;

  @override
  Future<String> startCapture() async {
    final scanId = await _invoke<String>('startCapture');
    if (scanId == null) {
      throw const CaptureError('startCapture returned no scan id');
    }
    return scanId;
  }

  @override
  Future<void> beginCapturing(String scanId) =>
      _invoke<void>('beginCapturing', {'scanId': scanId});

  @override
  Future<void> finishCapture(String scanId) =>
      _invoke<void>('finishCapture', {'scanId': scanId});

  @override
  Future<void> cancelCapture(String scanId) =>
      _invoke<void>('cancelCapture', {'scanId': scanId});

  @override
  Future<void> startReconstruction(String scanId) =>
      _invoke<void>('startReconstruction', {'scanId': scanId});

  @override
  Future<String> exportModel(String scanId, ExportFormat format) async {
    final path = await _invoke<String>(
      'exportModel',
      {'scanId': scanId, 'format': format.name},
    );
    if (path == null) {
      throw const ExportError('exportModel returned no file path');
    }
    return path;
  }

  @override
  Stream<CapturePhase> get phaseUpdates {
    _ensureSubscribed();
    return _phaseController.stream;
  }

  @override
  Stream<CaptureFeedback> get feedbackUpdates {
    _ensureSubscribed();
    return _feedbackController.stream;
  }

  @override
  Stream<CaptureProgress> get captureProgressUpdates {
    _ensureSubscribed();
    return _captureProgressController.stream;
  }

  @override
  Stream<double> get reconstructionProgressUpdates {
    _ensureSubscribed();
    return _progressController.stream;
  }

  @override
  Stream<ReconstructionStage> get reconstructionStageUpdates {
    _ensureSubscribed();
    return _stageController.stream;
  }

  @override
  Stream<String> get reconstructionCompleteUpdates {
    _ensureSubscribed();
    return _completeController.stream;
  }

  @override
  Stream<BridgeError> get errorUpdates {
    _ensureSubscribed();
    return _errorController.stream;
  }

  @override
  Future<String> getSessionState() async =>
      await _invoke<String>('getSessionState') ?? 'none';

  @override
  Future<void> resetModelView() => _invoke<void>('resetModelView');

  @override
  Future<void> zoomModelView(double scale) =>
      _invoke<void>('zoomModelView', {'scale': scale});

  @override
  Future<void> setCaptureReviewMode({required bool enabled}) =>
      _invoke<void>('setCaptureReviewMode', {'enabled': enabled});

  @override
  Future<void> setTorch({required bool enabled}) =>
      _invoke<void>('setTorch', {'enabled': enabled});

  @override
  Future<void> setScanProfile(ScanProfile profile) =>
      _invoke<void>('setScanProfile', {'profile': profile.name});

  @override
  Future<void> deleteScan(String scanId) =>
      _invoke<void>('deleteScan', {'scanId': scanId});

  @override
  Stream<double> get modelZoomUpdates {
    _ensureSubscribed();
    return _modelZoomController.stream;
  }

  @override
  Stream<ScanDirection> get scanDirectionUpdates {
    _ensureSubscribed();
    return _directionController.stream;
  }

  @override
  Future<bool> hasActiveCaptureSession() async {
    try {
      return await _commands.invokeMethod<bool>('hasActiveCaptureSession') ??
          false;
    } on PlatformException catch (e) {
      throw _mapError(e);
    } on MissingPluginException {
      throw const UnsupportedDeviceError('Native module not registered');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_eventSub?.cancel());
    unawaited(_phaseController.close());
    unawaited(_feedbackController.close());
    unawaited(_captureProgressController.close());
    unawaited(_directionController.close());
    unawaited(_modelZoomController.close());
    unawaited(_progressController.close());
    unawaited(_stageController.close());
    unawaited(_completeController.close());
    unawaited(_errorController.close());
  }
}
