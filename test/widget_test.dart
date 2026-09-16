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
    expect(find.text(Strings.scanCta), findsOneWidget);

    clearFormaChannelMocks();
  });
}
