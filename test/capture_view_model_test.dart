import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:forma/core/providers.dart';
import 'package:forma/core/strings.dart';
import 'package:forma/features/capture/capture_view_model.dart';

import 'native_channel_mock.dart';
import 'scan_repository_memory.dart';

/// Capture view model with a short watchdog so tests stay fast.
class TestCaptureViewModel extends CaptureViewModel {
  TestCaptureViewModel()
      : super(
          watchdogTimeout: const Duration(milliseconds: 120),
          startCaptureTimeout: const Duration(milliseconds: 200),
        );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryScanRepository repo;
  late ProviderContainer container;
  late List<String> calls;

  setUp(() {
    calls = [];
    mockFormaEventChannel();
    mockFormaMethods((call) async {
      calls.add(call.method);
      if (call.method == 'startCapture') {
        return 'scan-1';
      }
      return null;
    });
    repo = MemoryScanRepository();
    container = ProviderContainer(
      overrides: [scanRepositoryProvider.overrideWithValue(repo)],
    );
  });

  tearDown(() {
    container.dispose();
    clearFormaChannelMocks();
  });

  test('start/beginCapturing/finish/complete persists the scan', () async {
    final vm = container.read(captureViewModelProvider.notifier);

    await vm.start();
    expect(vm.state.phase, isNull);

    // Object Capture only accepts a capture request from its .detecting
    // state.
    await emitFormaEvent({'type': 'phase', 'value': 'detecting'});
    await pumpEventQueue();

    await vm.beginCapturing();
    expect(calls, contains('beginCapturing'));

    await vm.finish();
    expect(vm.state.isReconstructing, isTrue);

    await emitFormaEvent({
      'type': 'reconstruction_complete',
      'value': '/Scans/scan-1/Model.usdz',
    });
    await pumpEventQueue();

    expect(vm.state.isCompleted, isTrue);
    final saved = await repo.byId('scan-1');
    expect(saved, isNotNull);
    expect(saved!.modelPath, '/Scans/scan-1/Model.usdz');
  });

  test('error event surfaces a safe message without technical detail',
      () async {
    final vm = container.read(captureViewModelProvider.notifier);

    await vm.start();
    await emitFormaEvent({
      'type': 'error',
      'value': {'code': 2001, 'message': 'os_error 0xdeadbeef'},
    });
    await pumpEventQueue();

    expect(vm.state.error, 'Something went wrong. Please try again.');
    expect(vm.state.error, isNot(contains('0xdeadbeef')));
  });

  test('failed phase surfaces an error', () async {
    final vm = container.read(captureViewModelProvider.notifier);

    await vm.start();
    await emitFormaEvent({'type': 'phase', 'value': 'failed'});
    await pumpEventQueue();

    expect(vm.state.error, 'Something went wrong. Please try again.');
  });

  test('storage error event shows the storage message', () async {
    final vm = container.read(captureViewModelProvider.notifier);

    await vm.start();
    await emitFormaEvent({
      'type': 'error',
      'value': {'code': 1007, 'message': 'insufficientStorage'},
    });
    await pumpEventQueue();

    expect(vm.state.error, Strings.storageFull);
  });

  test('failed phase does not overwrite a specific error', () async {
    final vm = container.read(captureViewModelProvider.notifier);

    await vm.start();
    await emitFormaEvent({
      'type': 'error',
      'value': {'code': 1007, 'message': 'insufficientStorage'},
    });
    await emitFormaEvent({'type': 'phase', 'value': 'failed'});
    await pumpEventQueue();

    expect(vm.state.error, Strings.storageFull);
  });

  test('cancel resets to idle', () async {
    final vm = container.read(captureViewModelProvider.notifier);

    await vm.start();
    await vm.cancel();

    expect(vm.state.isIdle, isTrue);
    expect(vm.state.phase, isNull);
  });

  test('phase events mark the camera live and a live probe keeps it',
      () async {
    mockFormaMethods((call) async {
      if (call.method == 'getSessionState') {
        return 'ready';
      }
      if (call.method == 'startCapture') {
        return 'scan-1';
      }
      return null;
    });
    final testContainer = ProviderContainer(
      overrides: [
        scanRepositoryProvider.overrideWithValue(repo),
        captureViewModelProvider.overrideWith(TestCaptureViewModel.new),
      ],
    );
    addTearDown(testContainer.dispose);

    final vm = testContainer.read(captureViewModelProvider.notifier);
    await vm.start();
    expect(vm.state.isSessionStarting, isTrue);
    expect(vm.state.isCameraLive, isFalse);

    await emitFormaEvent({'type': 'phase', 'value': 'ready'});
    await pumpEventQueue();

    expect(vm.state.isCameraLive, isTrue);
    expect(vm.state.isSessionStarting, isFalse);

    // Outlast the short watchdog: the session probe says alive, so no
    // error may surface and the camera stays live.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await pumpEventQueue();

    expect(vm.state.error, isNull);
    expect(vm.state.isCameraLive, isTrue);
  });

  test('watchdog surfaces an honest camera-dead error', () async {
    mockFormaMethods((call) async {
      if (call.method == 'getSessionState') {
        return 'none';
      }
      if (call.method == 'startCapture') {
        return 'scan-1';
      }
      return null;
    });
    final testContainer = ProviderContainer(
      overrides: [
        scanRepositoryProvider.overrideWithValue(repo),
        captureViewModelProvider.overrideWith(TestCaptureViewModel.new),
      ],
    );
    addTearDown(testContainer.dispose);

    final vm = testContainer.read(captureViewModelProvider.notifier);
    await vm.start();

    // No phase event ever arrives; the watchdog probes the session and
    // finds it gone.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await pumpEventQueue();

    expect(vm.state.isCameraLive, isFalse);
    expect(vm.state.error, Strings.cameraDead);
  });

  test('watchdog shows tracking guidance while session is initializing',
      () async {
    mockFormaMethods((call) async {
      if (call.method == 'getSessionState') {
        return 'initializing';
      }
      if (call.method == 'startCapture') {
        return 'scan-1';
      }
      return null;
    });
    final testContainer = ProviderContainer(
      overrides: [
        scanRepositoryProvider.overrideWithValue(repo),
        captureViewModelProvider.overrideWith(TestCaptureViewModel.new),
      ],
    );
    addTearDown(testContainer.dispose);

    final vm = testContainer.read(captureViewModelProvider.notifier);
    await vm.start();

    // Session alive but ARKit tracking hasn't locked — guidance, not an
    // error (device log 2026-09-17: frames flowing, tracking not normal).
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await pumpEventQueue();

    expect(vm.state.isTrackingInitializing, isTrue);
    expect(vm.state.isSessionStarting, isFalse);
    expect(vm.state.error, isNull);
  });

  test('startCapture timeout surfaces an honest wedged-camera error',
      () async {
    mockFormaMethods((call) async {
      if (call.method == 'startCapture') {
        // Dropped reply: never completes.
        await Completer<void>().future;
      }
      return null;
    });
    final testContainer = ProviderContainer(
      overrides: [
        scanRepositoryProvider.overrideWithValue(repo),
        captureViewModelProvider.overrideWith(TestCaptureViewModel.new),
      ],
    );
    addTearDown(testContainer.dispose);

    final vm = testContainer.read(captureViewModelProvider.notifier);
    unawaited(vm.start());

    // Outlast the injected 200 ms start timeout.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await pumpEventQueue();

    expect(vm.state.isSessionStarting, isFalse);
    expect(vm.state.error, Strings.cameraDidNotStart);
  });

  test('an early capture tap is queued until the session is detecting',
      () async {
    mockFormaMethods((call) async {
      calls.add(call.method);
      if (call.method == 'getSessionState') {
        return 'initializing';
      }
      if (call.method == 'startCapture') {
        return 'scan-1';
      }
      return null;
    });
    final testContainer = ProviderContainer(
      overrides: [
        scanRepositoryProvider.overrideWithValue(repo),
        captureViewModelProvider.overrideWith(TestCaptureViewModel.new),
      ],
    );
    addTearDown(testContainer.dispose);

    final vm = testContainer.read(captureViewModelProvider.notifier);
    await vm.start();

    // Tapped while the camera is still warming up — the tap must be kept,
    // not turned into a "Capture failed." error.
    await vm.beginCapturing();
    await pumpEventQueue();

    expect(calls, isNot(contains('beginCapturing')));
    expect(vm.state.error, isNull);

    // The moment the session is ready, the queued capture starts.
    await emitFormaEvent({'type': 'phase', 'value': 'detecting'});
    await pumpEventQueue();

    expect(calls, contains('beginCapturing'));
    expect(vm.state.error, isNull);
  });

  test('a native not-ready rejection is retried instead of surfaced',
      () async {
    var beginCalls = 0;
    mockFormaMethods((call) async {
      if (call.method == 'getSessionState') {
        return 'detecting';
      }
      if (call.method == 'startCapture') {
        return 'scan-1';
      }
      if (call.method == 'beginCapturing') {
        beginCalls++;
        if (beginCalls == 1) {
          // Native guard: session not in .detecting yet (code 1006).
          throw PlatformException(code: 'CAPTURE', details: 1006);
        }
        return null;
      }
      return null;
    });
    final testContainer = ProviderContainer(
      overrides: [
        scanRepositoryProvider.overrideWithValue(repo),
        captureViewModelProvider.overrideWith(TestCaptureViewModel.new),
      ],
    );
    addTearDown(testContainer.dispose);

    final vm = testContainer.read(captureViewModelProvider.notifier);
    await vm.start();
    await emitFormaEvent({'type': 'phase', 'value': 'detecting'});
    await pumpEventQueue();

    await vm.beginCapturing();
    await pumpEventQueue();
    expect(vm.state.error, isNull);

    // The queued retry fires and the capture starts after all.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await pumpEventQueue();

    expect(beginCalls, 2);
    expect(vm.state.error, isNull);
  });

  test('a second start() while one is in flight is ignored', () async {
    var startCalls = 0;
    mockFormaMethods((call) async {
      if (call.method == 'startCapture') {
        startCalls++;
        // Hold the first call open long enough for a second tap.
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return 'scan-1';
      }
      return null;
    });
    final testContainer = ProviderContainer(
      overrides: [
        scanRepositoryProvider.overrideWithValue(repo),
        captureViewModelProvider.overrideWith(TestCaptureViewModel.new),
      ],
    );
    addTearDown(testContainer.dispose);

    final vm = testContainer.read(captureViewModelProvider.notifier);
    await Future.wait([vm.start(), vm.start()]);
    await pumpEventQueue();

    expect(startCalls, 1);
    // Exactly one native session must exist; the second tap changed
    // nothing. isSessionStarting stays true until the first phase event
    // arrives (the feed is not confirmed live yet) — that's by design.
    expect(vm.state.error, isNull);
  });
}
