import 'package:flutter_test/flutter_test.dart';
import 'package:forma/platform/native_bridge/capture_state.dart';
import 'package:forma/platform/native_bridge/fake_native_bridge.dart';
import 'package:forma/platform/native_bridge/native_bridge.dart';

void main() {
  test('full capture flow emits phases in order and completes', () async {
    final bridge = FakeNativeBridge();
    final phases = <CapturePhase>[];
    final sub = bridge.phaseUpdates.listen(phases.add);

    final scanId = await bridge.startCapture();
    expect(scanId, isNotEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 1300));
    expect(phases, containsAllInOrder([
      CapturePhase.initializing,
      CapturePhase.ready,
      CapturePhase.detecting,
      CapturePhase.capturing,
    ]));

    await bridge.finishCapture(scanId);
    expect(phases, contains(CapturePhase.finishing));
    expect(phases.last, CapturePhase.completed);
    await sub.cancel();
  });

  test('reconstruction emits progress 0..1 then completes', () async {
    final bridge = FakeNativeBridge();
    final scanId = await bridge.startCapture();

    final progress = <double>[];
    final sub = bridge.reconstructionProgressUpdates.listen(progress.add);
    final completeFuture =
        bridge.reconstructionCompleteUpdates.first.timeout(
              const Duration(seconds: 5),
            );

    await bridge.startReconstruction(scanId);
    expect(progress.first, 0);
    expect(progress.last, 1);

    final modelPath = await completeFuture;
    expect(modelPath, contains(scanId));
    await sub.cancel();
  });

  test('exportModel returns a path with the requested extension', () async {
    final bridge = FakeNativeBridge();
    final path = await bridge.exportModel('scan-1', ExportFormat.stl);
    expect(path, endsWith('.stl'));
    bridge.dispose();
  });

  test('cancelCapture resets phase to ready', () async {
    final bridge = FakeNativeBridge();
    final phaseFuture = bridge.phaseUpdates.first;
    await bridge.cancelCapture('scan-x');
    expect(await phaseFuture, CapturePhase.ready);
    bridge.dispose();
  });
}
