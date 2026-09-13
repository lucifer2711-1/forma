import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Drift table backing the scan library.
@DataClassName('ScanRow')
class ScanTable extends Table {
  /// Stable uuid, also used as the on-disk folder name.
  TextColumn get id => text()();

  /// User-visible name.
  TextColumn get name => text()();

  /// Creation timestamp.
  DateTimeColumn get createdAt => dateTime()();

  /// Last modification timestamp.
  DateTimeColumn get updatedAt => dateTime()();

  /// Draft, processing, ready, or failed.
  IntColumn get statusIndex => integer()();

  /// Optional absolute path to the thumbnail image.
  TextColumn get thumbnailPath => text().nullable()();

  /// Optional absolute path to the exported model file.
  TextColumn get modelPath => text().nullable()();

  /// On-disk size of the scan folder.
  IntColumn get bytes => integer()();

  /// Whether the user favorited this scan.
  BoolColumn get isFavorite => boolean()();

  /// Comma-separated tags (library filtering, Phase 3).
  TextColumn get tags => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The Forma local database (drift/SQLite, fully on-device).
///
/// `driftDatabase` from drift_flutter resolves the correct per-platform
/// storage directory (app documents on iOS, app data on Windows).
@DriftDatabase(tables: [ScanTable])
class FormaDatabase extends _$FormaDatabase {
  FormaDatabase() : super(_open());

  /// Creates an in-memory instance for tests.
  FormaDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _open() => driftDatabase(name: 'forma');
}
