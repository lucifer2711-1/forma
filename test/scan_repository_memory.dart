import 'dart:async';

import 'package:forma/core/models/scan.dart';
import 'package:forma/core/repositories/scan_repository.dart';

/// In-memory [ScanRepository] for tests — exercises repository consumers
/// without drift or native storage.
class MemoryScanRepository implements ScanRepository {
  final _scans = <String, Scan>{};
  final _controller = StreamController<List<Scan>>.broadcast();

  @override
  Stream<List<Scan>> watchAll() async* {
    yield _snapshot();
    yield* _controller.stream;
  }

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

  List<Scan> _snapshot() {
    final items = _scans.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  void _notify() {
    _controller.add(_snapshot());
  }

  /// Closes the underlying stream.
  void dispose() => _controller.close();
}
