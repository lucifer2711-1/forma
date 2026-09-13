import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:forma/core/models/scan.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/core/strings.dart';
import 'package:forma/design_system/theme.dart';
import 'package:forma/features/library/library_screen.dart';

import 'scan_repository_memory.dart';

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
}
