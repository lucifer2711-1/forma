import 'package:drift/drift.dart';
import 'package:forma/core/models/scan.dart';
import 'package:forma/data/database/database.dart';

/// Local persistence for the scan library.
abstract interface class ScanRepository {
  /// Live list of all scans, newest first.
  Stream<List<Scan>> watchAll();

  /// A single scan by id, or null.
  Future<Scan?> byId(String id);

  /// Insert or update.
  Future<void> save(Scan scan);

  /// Permanently deletes the scan row (files are deleted by the data layer).
  Future<void> delete(String id);

  /// Favorites toggle.
  Future<void> setFavorite(String id, {required bool isFavorite});
}

/// Drift-backed [ScanRepository].
class DriftScanRepository implements ScanRepository {
  DriftScanRepository(this._db);

  final FormaDatabase _db;

  @override
  Stream<List<Scan>> watchAll() {
    final query = _db.select(_db.scanTable)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map(_mapRows);
  }

  @override
  Future<Scan?> byId(String id) async {
    final query = _db.select(_db.scanTable)..where((t) => t.id.equals(id));
    final rows = await query.getSingleOrNull();
    return rows == null ? null : _mapRow(rows);
  }

  @override
  Future<void> save(Scan scan) {
    return _db.into(_db.scanTable).insertOnConflictUpdate(
          ScanTableCompanion.insert(
            id: scan.id,
            name: scan.name,
            createdAt: scan.createdAt,
            updatedAt: DateTime.now(),
            statusIndex: scan.status.index,
            thumbnailPath: Value(scan.thumbnailPath),
            modelPath: Value(scan.modelPath),
            bytes: scan.bytes,
            isFavorite: scan.isFavorite,
            tags: scan.tags.join(','),
          ),
        );
  }

  @override
  Future<void> delete(String id) {
    return (_db.delete(_db.scanTable)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> setFavorite(String id, {required bool isFavorite}) {
    return (_db.update(_db.scanTable)..where((t) => t.id.equals(id)))
        .write(ScanTableCompanion(isFavorite: Value(isFavorite)));
  }

  List<Scan> _mapRows(List<ScanRow> rows) =>
      rows.map(_mapRow).toList(growable: false);

  Scan _mapRow(ScanRow row) => Scan(
        id: row.id,
        name: row.name,
        createdAt: row.createdAt,
        status: ScanStatus.values[row.statusIndex],
        thumbnailPath: row.thumbnailPath,
        modelPath: row.modelPath,
        bytes: row.bytes,
        isFavorite: row.isFavorite,
        tags: row.tags.isEmpty ? const [] : row.tags.split(','),
      );
}
