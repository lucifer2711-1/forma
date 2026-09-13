import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:forma/core/models/scan.dart';
import 'package:forma/core/repositories/scan_repository.dart';

/// Minimal in-memory [ScanRepository] mirroring the Drift implementation's
/// contract. Keeps tests hermetic — the Drift database itself is exercised
/// on device and CI (Phase 1).
class InMemoryScanRepository implements ScanRepository {
  final _scans = <String, Scan>{};
  final _controller = StreamController<List<Scan>>.broadcast();

  void _notify() {
    final items = _scans.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _controller.add(items);
  }

  @override
  Stream<List<Scan>> watchAll() => _controller.stream;

  @override
  Future<Scan?> byId(String id) async => _scans[id];

  @override
  Future<void> save(Scan scan) async {
    _scans[scan.id] = scan;
    _notify();
  }

  @override
  Future<void> delete(String id) async {
    _scans.remove(id);
    _notify();
  }

  @override
  Future<void> setFavorite(String id, {required bool isFavorite}) async {
    final scan = _scans[id];
    if (scan != null) {
      _scans[id] = scan.copyWith(isFavorite: isFavorite);
      _notify();
    }
  }
}

void main() {
  test('save, watch, favorite, and delete round-trip', () async {
    final repo = InMemoryScanRepository();
    final emissions = <List<Scan>>[];
    final sub = repo.watchAll().listen(emissions.add);

    final scan = Scan(
      id: 's1',
      name: 'Test Mug',
      createdAt: DateTime(2026, 3, 15),
      status: ScanStatus.ready,
    );
    await repo.save(scan);

    final fetched = await repo.byId('s1');
    expect(fetched?.name, 'Test Mug');

    await repo.setFavorite('s1', isFavorite: true);
    expect((await repo.byId('s1'))!.isFavorite, isTrue);

    await repo.delete('s1');
    expect(await repo.byId('s1'), isNull);
    expect(emissions.last, isEmpty);

    await sub.cancel();
  });
}
