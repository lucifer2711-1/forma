import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma/core/models/scan.dart';
import 'package:forma/core/repositories/scan_repository.dart';
import 'package:forma/data/database/database.dart';
import 'package:forma/platform/native_bridge/fake_native_bridge.dart';
import 'package:forma/platform/native_bridge/native_bridge.dart';

/// The active native bridge. Swap to the iOS channel bridge on device.
final nativeBridgeProvider =
    Provider<NativeBridge>((ref) => FakeNativeBridge());

/// The scan database.
final databaseProvider = Provider<FormaDatabase>((ref) {
  final db = FormaDatabase();
  ref.onDispose(db.close);
  return db;
});

/// The scan repository.
final scanRepositoryProvider = Provider<ScanRepository>(
  (ref) => DriftScanRepository(ref.watch(databaseProvider)),
);

/// All saved scans, newest first.
final scanListProvider = StreamProvider<List<Scan>>(
  (ref) => ref.watch(scanRepositoryProvider).watchAll(),
);
