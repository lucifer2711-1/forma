import 'package:freezed_annotation/freezed_annotation.dart';

part 'scan.freezed.dart';

/// Lifecycle of a scan in the local library.
enum ScanStatus { draft, processing, ready, failed }

/// A user's 3D scan — the central domain object.
@freezed
abstract class Scan with _$Scan {
  const factory Scan({
    required String id,
    required String name,
    required DateTime createdAt,
    @Default(ScanStatus.draft) ScanStatus status,
    String? thumbnailPath,
    String? modelPath,
    @Default(0) int bytes,
    @Default(false) bool isFavorite,
    @Default(<String>[]) List<String> tags,
  }) = _Scan;
}
