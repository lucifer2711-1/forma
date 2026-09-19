import 'package:forma/core/strings.dart';
import 'package:forma/features/capture/coverage/coverage_map.dart';

/// Names a band the way it reads inside a sentence ("the top").
String coverageBandName(CoverageBand band) => switch (band) {
      CoverageBand.top => Strings.coverageNameTop,
      CoverageBand.sides => Strings.coverageNameSides,
      CoverageBand.bottom => Strings.coverageNameBottom,
    };

/// Names a set of bands as a readable list ("the top and the underside").
///
/// Shared by the coverage panel and the live capture hint on purpose: the two
/// answer the same question, and a user who reads "still to scan: the
/// underside" in one place must not be told something different in the other.
String joinCoverageBandNames(List<CoverageBand> bands) {
  final names = bands.map(coverageBandName).toList(growable: false);
  if (names.isEmpty) {
    return '';
  }
  if (names.length == 1) {
    return names.single;
  }
  if (names.length == 2) {
    return '${names.first} and ${names.last}';
  }
  return '${names.take(names.length - 1).join(', ')} and ${names.last}';
}
