import 'dart:async';

import 'package:forma/platform/native_bridge/capture_state.dart';
import 'package:forma/platform/native_bridge/native_bridge.dart';

/// A pure-Dart simulation of the native capture pipeline.
///
/// Lets the entire app run, be demoed, and be tested on any platform
/// (Windows included) with realistic timing — no iOS device required.
class FakeNativeBridge implements NativeBridge {
  final _phaseController = StreamController<CapturePhase>.broadcast();
  final _feedbackController = StreamController<CaptureFeedback>.broadcast();
  final _progressController = StreamController<double>.broadcast();
  final _completeController = StreamController<String>.broadcast();
  final _errorController = StreamController<BridgeError>.broadcast();

  int _scanCounter = 0;

  @override
  Future<bool> isScanSupported() async => true;

  @override
  Future<String> startCapture() async {
    _scanCounter++;
    unawaited(_simulateCaptureFlow());
    return 'fake-scan-$_scanCounter';
  }

  Future<void> _simulateCaptureFlow() async {
    await _emit(_phaseController, CapturePhase.initializing);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await _emit(_phaseController, CapturePhase.ready);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _emit(_phaseController, CapturePhase.detecting);
    await _emit(
      _feedbackController,
      const CaptureFeedback(CaptureFeedbackType.objectTooFar),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _emit(
      _feedbackController,
      const CaptureFeedback(CaptureFeedbackType.none),
    );
    await _emit(_phaseController, CapturePhase.capturing);
  }

  @override
  Future<void> finishCapture(String scanId) async {
    await _emit(_phaseController, CapturePhase.finishing);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await _emit(_phaseController, CapturePhase.completed);
    }

  @override
  Future<void> startReconstruction(String scanId) async {
    for (var i = 0; i <= 20; i++) {
      await _emit(_progressController, i / 20);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await _emit(_completeController, '/fake/scans/$scanId/model.usdz');
  }

  @override
  Future<void> cancelCapture(String scanId) async {
    await _emit(_phaseController, CapturePhase.ready);
  }

  @override
  Future<String> exportModel(String scanId, ExportFormat format) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return '/fake/scans/$scanId/model.${format.name}';
  }

  Future<void> _emit<T>(StreamController<T> controller, T value) {
    controller.add(value);
    return Future.value();
  }

  @override
  Stream<CapturePhase> get phaseUpdates => _phaseController.stream;

  @override
  Stream<CaptureFeedback> get feedbackUpdates => _feedbackController.stream;

  @override
  Stream<double> get reconstructionProgressUpdates =>
      _progressController.stream;

  @override
  Stream<String> get reconstructionCompleteUpdates =>
      _completeController.stream;

  @override
  Stream<BridgeError> get errorUpdates => _errorController.stream;

  @override
  void dispose() {
    unawaited(_phaseController.close());
    unawaited(_feedbackController.close());
    unawaited(_progressController.close());
    unawaited(_completeController.close());
    unawaited(_errorController.close());
  }
}
