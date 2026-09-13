import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:forma/core/errors/forma_error.dart';
import 'package:forma/platform/native_bridge/capture_state.dart';
import 'package:forma/platform/native_bridge/ios_native_bridge.dart';
import 'package:forma/platform/native_bridge/native_bridge.dart';

import 'native_channel_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late IosNativeBridge bridge;
  Object? Function(String method)? responder;

  setUp(() {
    bridge = IosNativeBridge();
    mockFormaEventChannel();
    responder = null;
    mockFormaMethods((call) async => responder?.call(call.method));
  });

  tearDown(() {
    clearFormaChannelMocks();
    bridge.dispose();
  });

  test('isScanSupported returns the native bool', () async {
    responder = (_) => true;
    expect(await bridge.isScanSupported(), isTrue);
  });

  test('isScanSupported defaults to false when native answers null',
      () async {
    responder = (_) => null;
    expect(await bridge.isScanSupported(), isFalse);
  });

  test('startCapture returns the native scan id', () async {
    responder = (_) => 'scan-7';
    expect(await bridge.startCapture(), 'scan-7');
  });

  test('startCapture throws CaptureError when native returns no id',
      () async {
    responder = (_) => null;
    await expectLater(bridge.startCapture(), throwsA(isA<CaptureError>()));
  });

  test('beginCapturing forwards the scan id to native', () async {
    Object? received;
    mockFormaMethods((call) async {
      received = call.arguments;
      return null;
    });
    await bridge.beginCapturing('scan-9');
    final arguments = received! as Map<Object?, Object?>;
    expect(arguments['scanId'], 'scan-9');
  });

  test('PlatformException UNSUPPORTED maps to UnsupportedDeviceError',
      () async {
    mockFormaMethods(
      (call) async => throw PlatformException(
        code: 'UNSUPPORTED',
        message: 'no lidar',
      ),
    );
    await expectLater(
      bridge.isScanSupported(),
      throwsA(isA<UnsupportedDeviceError>()),
    );
  });

  test('PlatformException EXPORT maps to ExportError', () async {
    mockFormaMethods(
      (call) async => throw PlatformException(code: 'EXPORT', message: 'x'),
    );
    await expectLater(
      bridge.exportModel('s', ExportFormat.stl),
      throwsA(isA<ExportError>()),
    );
  });

  test('event stream parses phase, feedback, progress, complete, error',
      () async {
    final phases = <CapturePhase>[];
    final feedback = <CaptureFeedback>[];
    final progress = <double>[];
    final complete = <String>[];
    final errors = <BridgeError>[];
    final subscriptions = [
      bridge.phaseUpdates.listen(phases.add),
      bridge.feedbackUpdates.listen(feedback.add),
      bridge.reconstructionProgressUpdates.listen(progress.add),
      bridge.reconstructionCompleteUpdates.listen(complete.add),
      bridge.errorUpdates.listen(errors.add),
    ];

    await emitFormaEvent({'type': 'phase', 'value': 'capturing'});
    await emitFormaEvent({'type': 'feedback', 'value': 'objectTooFar'});
    await emitFormaEvent({'type': 'reconstruction_progress', 'value': 0.5});
    await emitFormaEvent({
      'type': 'reconstruction_complete',
      'value': '/Scans/scan-1/Model.usdz',
    });
    await emitFormaEvent({
      'type': 'error',
      'value': {'code': 2001, 'message': 'boom'},
    });

    expect(phases, [CapturePhase.capturing]);
    expect(feedback.single.type, CaptureFeedbackType.objectTooFar);
    expect(progress, [0.5]);
    expect(complete, ['/Scans/scan-1/Model.usdz']);
    expect(errors.single.code, 2001);

    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  });

  test('unknown event types are ignored without throwing', () async {
    final errors = <BridgeError>[];
    final subscription = bridge.errorUpdates.listen(errors.add);

    await emitFormaEvent({'type': 'mystery', 'value': 'x'});

    expect(errors, isEmpty);
    await subscription.cancel();
  });
}
