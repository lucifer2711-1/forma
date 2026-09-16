import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:forma/app.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/core/strings.dart';

import 'native_channel_mock.dart';
import 'scan_repository_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FormaApp renders the library and navigates to capture',
      (tester) async {
    mockFormaEventChannel();
    mockFormaMethods((call) async {
      switch (call.method) {
        case 'isScanSupported':
          return true;
        case 'startCapture':
          return 'scan-test';
        default:
          return null;
    }
    });

    final repo = MemoryScanRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [scanRepositoryProvider.overrideWithValue(repo)],
        child: const FormaApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Library is the home screen.
    expect(find.text(Strings.libraryTitle), findsOneWidget);
    expect(find.text(Strings.emptyTitle), findsOneWidget);

    // Scan CTA navigates into the capture flow.
    await tester.tap(find.text(Strings.startScan));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The session is still warming up, so the capture CTA is deliberately
    // not offered yet — tapping it there used to fail natively with a bare
    // "Capture failed." (device-test finding 2026-09-17).
    expect(find.text(Strings.gettingReady), findsOneWidget);
    expect(find.text(Strings.scanCta), findsNothing);

    // Once Object Capture reports it is detecting, the CTA appears.
    // (runAsync: the event helper awaits a real timer, which the test's
    // fake clock would otherwise never fire.)
    await tester.runAsync(
      () => emitFormaEvent({'type': 'phase', 'value': 'detecting'}),
    );
    await tester.pump();
    expect(find.text(Strings.scanCta), findsOneWidget);
    expect(find.text(Strings.gettingReady), findsNothing);

    clearFormaChannelMocks();
  });
}
