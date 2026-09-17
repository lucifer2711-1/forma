import 'dart:math' as math;

import 'package:forma/platform/native_bridge/capture_state.dart';

/// Which slice of the object a globe sector belongs to.
///
/// The bands are gravity-aligned because that is how a user thinks about a
/// scan: the top, the sides you walk around, and the underside. A single
/// waist-high lap fills the sides and leaves the other two, which is exactly
/// what a finished-but-imprecise scan looks like.
enum CoverageBand {
  /// Facing up (native's z is gravity-up).
  top,

  /// Around the object's waist — the band a walk-around covers.
  sides,

  /// Facing down.
  bottom,
}

/// One direction on the coverage globe, and whether a frame was kept for it.
class CoverageSector {
  /// Creates a sector.
  const CoverageSector({required this.direction, required this.covered});

  /// Unit direction of the object's surface this sector represents.
  final ScanDirection direction;

  /// Whether a kept frame covers this direction.
  final bool covered;

  /// The band this sector sits in.
  CoverageBand get band {
    if (direction.z > bandEdgeZ) {
      return CoverageBand.top;
    }
    if (direction.z < -bandEdgeZ) {
      return CoverageBand.bottom;
    }
    return CoverageBand.sides;
  }

  /// Height above/below which a sector counts as top/bottom rather than side.
  ///
  /// 0.5 puts the boundary at 60°, which is where "the top" starts to read as
  /// the top of an object rather than its upper sides. The same value drives
  /// the rings the globe draws, so the checklist and the globe can never
  /// disagree about where the bands are.
  static const double bandEdgeZ = 0.5;
}

/// How much of one band has been captured.
class CoverageBandStatus {
  /// Creates a band status.
  const CoverageBandStatus({
    required this.band,
    required this.coveredCount,
    required this.total,
  });

  /// Which band.
  final CoverageBand band;

  /// Sectors in this band that a kept frame covers.
  final int coveredCount;

  /// Sectors in this band in total.
  final int total;

  /// 0..1 coverage of this band.
  double get fraction => total == 0 ? 0 : coveredCount / total;

  /// Whether this band can be called done. Short of perfection on purpose:
  /// demanding every sector of a rough scan would keep the user circling.
  bool get isComplete => fraction >= 0.7;
}

/// Maps the directions a scan was captured from onto a globe, so the user can
/// see which sides are done and which are still missing.
///
/// This is our own measurement, computed from the frames Object Capture
/// actually kept (each kept frame is a direction native recorded), rather
/// than Apple's opaque point cloud — the point cloud showed that *something*
/// had been captured, but the shot-location overlay drew a hairball of
/// connecting lines that made it impossible to read (device-test finding
/// 2026-09-18).
class CoverageMap {
  const CoverageMap._(this.sectors);

  /// Builds the globe from the directions a scan was captured from.
  ///
  /// Only kept directions count as coverage; live ones are where the phone
  /// happens to be pointing.
  factory CoverageMap.from(List<ScanDirection> directions) {
    final kept = directions
        .where((direction) => direction.isKept && direction.isUsable)
        .toList(growable: false);
    final threshold = _cosine(toleranceDegrees);
    final sectors = <CoverageSector>[
      for (final sector in sectorDirections)
        CoverageSector(
          direction: sector,
          covered: kept.any((direction) => sector.dot(direction) >= threshold),
        ),
    ];
    return CoverageMap._(sectors);
  }

  /// Every sector of the globe, covered or not.
  final List<CoverageSector> sectors;

  /// The number of sectors on the globe.
  ///
  /// A Fibonacci lattice is used rather than a lat/long grid: lat/long
  /// clumps points at the poles, which would make the top and bottom bands
  /// look far more covered than they are.
  static const int sectorCount = 96;

  /// How close a kept frame must be to a sector to fill it, in degrees.
  ///
  /// A kept frame sees a swath of the object, not the one point it is aimed
  /// at, so the tolerance is generous — but not so generous that a couple of
  /// shots from one side paint the whole object. 32° also makes a band
  /// reachable: a handful of shots aimed down at the object have to be able to
  /// finish "the top", or the checklist can never be satisfied.
  static const double toleranceDegrees = 32;

  /// The empty globe, before anything has been captured.
  static final empty = CoverageMap.from(const []);

  /// The globe's lattice: evenly spread unit directions, z up.
  static final List<ScanDirection> sectorDirections = _fibonacciSphere(
    sectorCount,
  );

  /// Sectors a kept frame covers.
  int get coveredCount =>
      sectors.where((sector) => sector.covered).length;

  /// 0..1 of the object's directions that have been captured.
  double get fraction =>
      sectors.isEmpty ? 0 : coveredCount / sectors.length;

  /// Whether anything has been captured at all.
  bool get hasData => coveredCount > 0;

  /// Per-band coverage, in the order a user works: top, sides, bottom.
  List<CoverageBandStatus> get bands => [
        for (final band in CoverageBand.values)
          CoverageBandStatus(
            band: band,
            coveredCount: sectors
                .where((sector) => sector.band == band && sector.covered)
                .length,
            total: sectors.where((sector) => sector.band == band).length,
          ),
      ];

  /// The bands still worth scanning — what the guidance tells the user to do
  /// next, rather than asking for another full lap.
  List<CoverageBand> get missingBands => [
        for (final status in bands)
          if (!status.isComplete) status.band,
      ];

  static List<ScanDirection> _fibonacciSphere(int count) {
    // Golden-angle increments give the most even spacing for a given count.
    final goldenAngle = math.pi * (3 - math.sqrt(5));
    return List<ScanDirection>.generate(count, (index) {
      final z = 1 - 2 * (index + 0.5) / count;
      final radius = math.sqrt(math.max(0, 1 - z * z));
      final theta = goldenAngle * index;
      return ScanDirection(
        x: math.cos(theta) * radius,
        y: math.sin(theta) * radius,
        z: z,
      );
    });
  }

  static double _cosine(double degrees) =>
      math.cos(degrees * math.pi / 180);
}
