import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:forma/core/providers.dart';
import 'package:forma/features/capture/capture_view_model.dart';

import 'native_channel_mock.dart';
import 'scan_repository_memory.dart';

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

  test('cancel resets to idle', () async {
    final vm = container.read(captureViewModelProvider.notifier);

    await vm.start();
    await vm.cancel();

    expect(vm.state.isIdle, isTrue);
    expect(vm.state.phase, isNull);
  });
}
