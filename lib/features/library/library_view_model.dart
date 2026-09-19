import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:forma/core/errors/forma_error.dart';
import 'package:forma/core/models/scan.dart';
import 'package:forma/core/providers.dart';

/// Removes a scan from the library — its files first, then its row.
///
/// Kept out of the widget so the widget only handles the outcome (rules.md:
/// async work belongs in a view model, not a widget).
class ScanDeleter {
  /// Creates the deleter over the app's providers.
  ScanDeleter(this._ref);

  final Ref _ref;

  /// Deletes [scan] from disk and from the library.
  ///
  /// Order matters. Files go first, through native: a row removed while its
  /// model stayed on disk would strand hundreds of megabytes nothing points
  /// at, whereas a file deleted before its row leaves a row the library can
  /// still show — and the user can simply delete again.
  ///
  /// Native cleanup is best-effort. On a host without the module (dev machine,
  /// widget tests) there is nothing to delete, and that must never stop the
  /// row from going away.
  Future<void> delete(Scan scan) async {
    try {
      await _ref.read(nativeBridgeProvider).deleteScan(scan.id);
    } on FormaError catch (e) {
      debugPrint('[forma] scan file cleanup failed: ${e.debugMessage}');
    }
    await _ref.read(scanRepositoryProvider).delete(scan.id);
  }
}

/// Provides the scan deleter.
final scanDeleterProvider = Provider<ScanDeleter>(ScanDeleter.new);
