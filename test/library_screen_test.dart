import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:forma/core/models/scan.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/core/strings.dart';
import 'package:forma/design_system/theme.dart';
import 'package:forma/features/capture/capture_view_model.dart';
import 'package:forma/features/library/library_screen.dart';

import 'native_channel_mock.dart';
import 'scan_repository_memory.dart';

/// Capture VM that never touches platform channels — the navigation test
/// must not arm real watchdog/timeout timers against the real bridge
/// (a pending timer trips flutter_test's teardown invariant).
class _NoopCaptureViewModel extends CaptureViewModel {
  @override
  CaptureUiState build() => CaptureUiState();

  @override
  Future<void> start() async {}
}

Scan _scan(String id, String name) => Scan(
      id: id,
      name: name,
      createdAt: DateTime(2026, 3, 15),
      status: ScanStatus.ready,
    );

Future<void> _pump(
  WidgetTester tester, {
  required MemoryScanRepository repo,
  required bool supported,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        scanRepositoryProvider.overrideWithValue(repo),
        scanSupportProvider.overrideWithValue(
          supported
              ? const AsyncValue.data(true)
              : const AsyncValue.data(false),
        ),
        captureViewModelProvider.overrideWith(_NoopCaptureViewModel.new),
      ],
      child: MaterialApp(
        theme: buildFormaTheme(Brightness.light),
        home: const LibraryScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows scan cards from the repository', (tester) async {
    final repo = MemoryScanRepository();
    await repo.save(_scan('a', 'Mug'));
    await repo.save(_scan('b', 'Figurine'));
    await _pump(tester, repo: repo, supported: true);

    expect(find.text('Mug'), findsOneWidget);
    expect(find.text('Figurine'), findsOneWidget);
    expect(find.text(Strings.libraryTitle), findsOneWidget);
  });

  testWidgets('shows empty state when there are no scans', (tester) async {
    await _pump(tester, repo: MemoryScanRepository(), supported: true);

    expect(find.text(Strings.emptyTitle), findsOneWidget);
    expect(find.text(Strings.startScan), findsOneWidget);
  });

  testWidgets('scan CTA opens the capture screen on supported devices',
      (tester) async {
    await _pump(tester, repo: MemoryScanRepository(), supported: true);

    await tester.tap(find.text(Strings.startScan));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(Strings.scanCta), findsOneWidget);
  });

  testWidgets('scan CTA opens the unsupported screen elsewhere',
      (tester) async {
    await _pump(tester, repo: MemoryScanRepository(), supported: false);

    await tester.tap(find.text(Strings.startScan));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(Strings.unsupportedTitle), findsOneWidget);
    expect(find.text(Strings.scanCta), findsNothing);
  });

  testWidgets('tapping a finished scan opens its 360° model viewer',
      (tester) async {
    // Synchronous on purpose: real async file I/O never completes inside
    // flutter_test's fake-async zone, so `createTemp()` would hang the test
    // (gotcha 23).
    final directory = Directory.systemTemp.createTempSync('forma-viewer');
    addTearDown(() => directory.deleteSync(recursive: true));
    final model = File('${directory.path}/Model.usdz')
      ..writeAsStringSync('usdz');

    final repo = MemoryScanRepository();
    await repo.save(
      Scan(
        id: 'a',
        name: 'Mug',
        createdAt: DateTime(2026, 3, 15),
        status: ScanStatus.ready,
        modelPath: model.path,
      ),
    );
    await _pump(tester, repo: repo, supported: true);

    await tester.tap(find.text('Mug'));
    await tester.pumpAndSettle();

    // The viewer opens. This host cannot render RealityKit, so it says so
    // instead of showing the black screen a model test would otherwise
    // report as "the model exists but is not viewable".
    expect(find.text(Strings.modelViewerIosOnly), findsOneWidget);
  });

  testWidgets('the viewer offers zoom controls that reach the native view',
      (tester) async {
    // The viewer's chrome only exists where the native view can, and the
    // test host is not iOS — so the platform is overridden for this test.
    // It must be restored inside the test body: the binding asserts that no
    // foundation debug variable is left changed, and `addTearDown` runs
    // after that check (gotcha 23).
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    final zoomScales = <double>[];
    mockFormaEventChannel();
    mockFormaMethods((call) async {
      if (call.method == 'zoomModelView') {
        final args = call.arguments as Map<Object?, Object?>?;
        zoomScales.add((args?['scale'] as double?) ?? 0);
      }
      return null;
    });
    addTearDown(clearFormaChannelMocks);

    final directory = Directory.systemTemp.createTempSync('forma-zoom');
    addTearDown(() => directory.deleteSync(recursive: true));
    final model = File('${directory.path}/Model.usdz')
      ..writeAsStringSync('usdz');

    final repo = MemoryScanRepository();
    await repo.save(
      Scan(
        id: 'a',
        name: 'Mug',
        createdAt: DateTime(2026, 3, 15),
        status: ScanStatus.ready,
        modelPath: model.path,
      ),
    );
    await _pump(tester, repo: repo, supported: true);

    await tester.tap(find.text('Mug'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();

    // Pinch is the primary gesture, but a zoom that depends entirely on a
    // platform gesture being delivered left the user unable to zoom at all
    // (device-test finding 2026-09-18). The step is deliberately large: the
    // old 1.25 step ran into the old zoom stop after two taps, which is why
    // the buttons read as "not working" when they were working.
    expect(zoomScales, [1.4, closeTo(1 / 1.4, 1e-9)]);

    // The level readout follows what native reports, not what Dart asked for:
    // that is what separates a pinch native ignored from one the app never
    // delivered.
    expect(find.text(Strings.zoomLevel(1)), findsOneWidget);
    await tester.runAsync(
      () => emitFormaEvent({'type': 'model_zoom', 'value': 2.5}),
    );
    await tester.pump();
    expect(find.text(Strings.zoomLevel(2.5)), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a scan with no model does not open a viewer',
      (tester) async {
    final repo = MemoryScanRepository();
    await repo.save(_scan('a', 'Mug'));
    await _pump(tester, repo: repo, supported: true);

    await tester.tap(find.text('Mug'));
    await tester.pump();

    expect(find.text(Strings.scanStillBuilding), findsOneWidget);
  });

  testWidgets('a scan whose model file is gone says so', (tester) async {
    final repo = MemoryScanRepository();
    await repo.save(
      Scan(
        id: 'a',
        name: 'Mug',
        createdAt: DateTime(2026, 3, 15),
        status: ScanStatus.ready,
        modelPath: '${Directory.systemTemp.path}/forma-missing/Model.usdz',
      ),
    );
    await _pump(tester, repo: repo, supported: true);

    await tester.tap(find.text('Mug'));
    await tester.pumpAndSettle();

    expect(find.text(Strings.modelMissingSubtitle), findsOneWidget);
  });
}
