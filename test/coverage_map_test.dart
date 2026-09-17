import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:forma/features/capture/coverage/coverage_map.dart';
import 'package:forma/platform/native_bridge/capture_state.dart';

/// A direction from spherical angles: [polarDegrees] from the top,
/// [azimuthDegrees] around it.
ScanDirection direction({
  required double polarDegrees,
  double azimuthDegrees = 0,
  bool isKept = true,
}) {
  final polar = polarDegrees * math.pi / 180;
  final azimuth = azimuthDegrees * math.pi / 180;
  return ScanDirection(
    x: math.sin(polar) * math.cos(azimuth),
    y: math.sin(polar) * math.sin(azimuth),
    z: math.cos(polar),
    isKept: isKept,
  );
}

void main() {
  test('the sector lattice is evenly spread and unit length', () {
    final sectors = CoverageMap.sectorDirections;
    expect(sectors, hasLength(CoverageMap.sectorCount));
    for (final sector in sectors) {
      expect(sector.squaredLength, closeTo(1, 1e-9));
    }
    // A Fibonacci lattice points as many sectors up as down — a lat/long grid
    // would clump at the poles and overstate the top and bottom bands.
    final up = sectors.where((sector) => sector.z > 0.9).length;
    final down = sectors.where((sector) => sector.z < -0.9).length;
    expect(up, down);
  });

  test('a captured direction covers its side, not the far one', () {
    final map = CoverageMap.from([direction(polarDegrees: 0)]);

    expect(map.hasData, isTrue);
    expect(map.fraction, greaterThan(0));
    expect(map.fraction, lessThan(0.2));

    final front = map.sectors.firstWhere((sector) => sector.direction.z > 0.95);
    final back = map.sectors.firstWhere((sector) => sector.direction.z < -0.95);
    expect(front.covered, isTrue);
    expect(back.covered, isFalse);
  });

  test('coverage grows as more of the object is scanned', () {
    final one = CoverageMap.from([direction(polarDegrees: 90)]);
    final half = CoverageMap.from([
      direction(polarDegrees: 90),
      direction(polarDegrees: 90, azimuthDegrees: 90),
      direction(polarDegrees: 90, azimuthDegrees: 180),
      direction(polarDegrees: 90, azimuthDegrees: 270),
    ]);
  final full = CoverageMap.from([
    for (var polar = 30.0; polar <= 150; polar += 30)
      for (var azimuth = 0.0; azimuth < 360; azimuth += 45)
        direction(polarDegrees: polar, azimuthDegrees: azimuth),
  ]);

    expect(one.fraction, lessThan(half.fraction));
    expect(half.fraction, lessThan(full.fraction));
    expect(full.fraction, 1.0);
  });

  test('bands separate the top, the sides and the underside', () {
    // Aimed down at the object from above, a few times around: the practical
    // way a user covers the top — and it has to be enough to satisfy the
    // checklist, or "the top" could never be ticked off.
    final top = CoverageMap.from([
      for (var azimuth = 0.0; azimuth < 360; azimuth += 30)
        direction(polarDegrees: 20, azimuthDegrees: azimuth),
    ]);
    final bands = {for (final band in top.bands) band.band: band};

    expect(bands[CoverageBand.top]!.coveredCount, greaterThan(0));
    expect(bands[CoverageBand.bottom]!.coveredCount, 0);
    expect(bands[CoverageBand.top]!.isComplete, isTrue);
    expect(bands[CoverageBand.bottom]!.isComplete, isFalse);

    // A waist-high lap fills the sides and leaves the top and the underside,
    // which is exactly the "why is my model imprecise?" case.
    final lap = CoverageMap.from([
      for (var azimuth = 0.0; azimuth < 360; azimuth += 20)
        direction(polarDegrees: 90, azimuthDegrees: azimuth),
    ]);
    expect(lap.missingBands, [CoverageBand.top, CoverageBand.bottom]);
  });

  test('an empty globe asks for everything and claims nothing', () {
    expect(CoverageMap.empty.hasData, isFalse);
    expect(CoverageMap.empty.fraction, 0);
    expect(CoverageMap.empty.missingBands, CoverageBand.values);
  });

  test('live directions are not coverage', () {
    // Where the phone happens to be pointing is not a captured side.
    final map = CoverageMap.from([
      direction(polarDegrees: 45, isKept: false),
    ]);
    expect(map.hasData, isFalse);
    expect(map.fraction, 0);
  });
}
