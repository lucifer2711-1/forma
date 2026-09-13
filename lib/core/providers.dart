import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:forma/core/errors/forma_error.dart';
import 'package:forma/core/models/scan.dart';
import 'package:forma/core/repositories/scan_repository.dart';
import 'package:forma/data/database/database.dart';
import 'package:forma/platform/native_bridge/ios_native_bridge.dart';
import 'package:forma/platform/native_bridge/native_bridge.dart';

/// The native bridge: real platform channels to the Swift NativeModule.
final nativeBridgeProvider = Provider<NativeBridge>((ref) {
  final bridge = IosNativeBridge();
  ref.onDispose(bridge.dispose);
  return bridge;
});

/// Whether this device can scan (LiDAR + OS support).
///
/// False whenever the native module is absent or the hardware cannot
/// scan — the honest answer, never a simulation.
final scanSupportProvider = FutureProvider<bool>((ref) async {
  try {
    return await ref.watch(nativeBridgeProvider).isScanSupported();
  } on FormaError {
    return false;
  }
});

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
