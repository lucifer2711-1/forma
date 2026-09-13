import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forma/core/models/scan.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/core/repositories/scan_repository.dart';
import 'package:forma/features/library/library_screen.dart';

class _FakeRepo implements ScanRepository {
  _FakeRepo(this._scans);

  final List<Scan> _scans;

  @override
  Stream<List<Scan>> watchAll() {
    return Stream.value(List.of(_scans)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  @override
  Future<Scan?> byId(String id) async =>
      _scans.where((s) => s.id == id).firstOrNull;

  @override
  Future<void> save(Scan scan) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> setFavorite(String id, {required bool isFavorite}) async {}
}

Scan _scan(String id, String name) => Scan(
      id: id,
      name: name,
      createdAt: DateTime(2026, 3, 15),
      status: ScanStatus.ready,
    );

Future<void> _pump(WidgetTester tester, _FakeRepo repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [scanRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: LibraryScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows scan cards from the repository', (tester) async {
    await _pump(
      tester,
      _FakeRepo([_scan('a', 'Mug'), _scan('b', 'Figurine')]),
    );
    expect(find.text('Mug'), findsOneWidget);
    expect(find.text('Figurine'), findsOneWidget);
    expect(find.text('Forma'), findsOneWidget);
  });

  testWidgets('shows empty state when there are no scans', (tester) async {
    await _pump(tester, _FakeRepo(const []));
    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('Start scanning'), findsOneWidget);
  });
}
