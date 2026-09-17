import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:forma/design_system/tokens/app_colors.dart';
import 'package:forma/features/capture/coverage/coverage_map.dart';
import 'package:forma/platform/native_bridge/capture_state.dart';

/// A globe direction projected onto the screen.
@immutable
class _Projected {
  const _Projected(this.offset, this.depth);

  /// Screen position.
  final Offset offset;

  /// −1 in front of the globe (facing the viewer), +1 behind it.
  final double depth;

  /// 0 behind, 1 in front — drives dot size and opacity.
  double get nearness => (1 - depth) / 2;
}

/// Shows which sides of the object have been captured, on a globe the user
/// can turn.
///
/// Dots, never lines. Apple's own point-cloud overlay draws a line between
/// every shot it has taken, and over a real scan that becomes a hairball that
/// hides the object it is meant to explain — the shape of a scan is already
/// encoded in *where* the dots are, so drawing the connections adds nothing
/// but noise (device-test finding 2026-09-18: "the connections look messy,
/// everything is disorganised").
///
/// The globe is gravity-aligned: native's reference frame has z pointing up,
/// so the top of the globe is the top of the object and the user's own sense
/// of "the underside still needs doing" maps straight onto it.
class CoverageGlobe extends StatefulWidget {
  /// Creates a coverage globe for [map].
  const CoverageGlobe({
    required this.map,
    this.currentDirection,
    this.diameter = 264,
    this.semanticsLabel,
    super.key,
  });

  /// The coverage model to draw.
  final CoverageMap map;

  /// Where the phone is pointed right now, drawn as a marker.
  final ScanDirection? currentDirection;

  /// Rendered width/height of the globe.
  final double diameter;

  /// Screen-reader summary of what the globe shows.
  final String? semanticsLabel;

  @override
  State<CoverageGlobe> createState() => _CoverageGlobeState();
}

class _CoverageGlobeState extends State<CoverageGlobe> {
  /// Turn of the globe around its vertical axis.
  double _yaw = 0;

  /// Tilt of the globe toward/away from the viewer.
  double _pitch = 0.28;

  /// Whether the first covered direction has been used to orient the globe.
  bool _autoOriented = false;

  @override
  void initState() {
    super.initState();
    _autoOrient();
  }

  @override
  void didUpdateWidget(CoverageGlobe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.map.coveredCount != oldWidget.map.coveredCount) {
      _autoOrient();
    }
  }

  /// Turns the side already captured to face the viewer.
  ///
  /// The globe's horizontal axes are honestly arbitrary — native's yaw is
  /// relative to whenever the scan started — so the useful default is "show me
  /// what I have", not an empty back hemisphere.
  void _autoOrient() {
    if (_autoOriented || !widget.map.hasData) {
      return;
    }
    var sumX = 0.0;
    var sumY = 0.0;
    for (final sector in widget.map.sectors) {
      if (!sector.covered) {
        continue;
      }
      sumX += sector.direction.x;
      sumY += sector.direction.y;
    }
    if (sumX == 0 && sumY == 0) {
      return;
    }
    _autoOriented = true;
    // Rotate so the covered centroid lands centred and facing the viewer
    // (+π puts it on the near side rather than the far one).
    _yaw = math.atan2(sumX, sumY) + math.pi;
  }

  void _onDrag(DragUpdateDetails details) {
    setState(() {
      _yaw -= details.delta.dx * 0.01;
      _pitch = (_pitch - details.delta.dy * 0.008).clamp(-1.2, 1.2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = FormaColors.of(context);
    return Semantics(
      label: widget.semanticsLabel,
      child: GestureDetector(
        // A drag turns the globe; nothing else competes for the gesture, so
        // every degree of movement lands on the model.
        onPanUpdate: _onDrag,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: widget.diameter,
          height: widget.diameter,
          child: CustomPaint(
            painter: _GlobePainter(
              map: widget.map,
              currentDirection: widget.currentDirection,
              yaw: _yaw,
              pitch: _pitch,
              colors: colors,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlobePainter extends CustomPainter {
  _GlobePainter({
    required this.map,
    required this.currentDirection,
    required this.yaw,
    required this.pitch,
    required this.colors,
  });

  final CoverageMap map;
  final ScanDirection? currentDirection;
  final double yaw;
  final double pitch;
  final FormaColors colors;

  /// Fraction of the globe radius the object itself occupies.
  static const double _objectScale = 0.6;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;

    _paintHorizon(canvas, center, radius);
    _paintBandRings(canvas, center, radius);

    // Far dots first, then the object, then the near dots: the depth ordering
    // is what makes a flat lattice read as a ball.
    final covered = <_Projected>[
      for (final sector in map.sectors)
        if (sector.covered) _project(sector.direction, center, radius),
    ];

    for (final point in covered.where((point) => point.depth > 0)) {
      _paintSectorDot(canvas, point, covered: true, behind: true);
    }

    _paintObject(canvas, center, radius);

    for (final point in covered.where((point) => point.depth <= 0)) {
      _paintSectorDot(canvas, point, covered: true, behind: false);
    }

    for (final sector in map.sectors.where((sector) => !sector.covered)) {
      final point = _project(sector.direction, center, radius);
      // Only the front half of the lattice is drawn: a full sphere of grey
      // dots is exactly the noise this view is meant to remove.
      if (point.depth > 0.35) {
        continue;
      }
      _paintSectorDot(canvas, point, covered: false, behind: point.depth > 0);
    }

    _paintUpMarker(canvas, center, radius);
    _paintCurrentDirection(canvas, center, radius);
  }

  void _paintHorizon(Canvas canvas, Offset center, double radius) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final body = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.02),
          Colors.white.withValues(alpha: 0.08),
        ],
      ).createShader(rect);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.14);
    canvas
      ..drawCircle(center, radius, body)
      ..drawCircle(center, radius, rim);
  }

  /// Draws the two latitude rings that separate the top, sides and underside
  /// bands, so the globe's "up" is not something the user has to infer.
  void _paintBandRings(Canvas canvas, Offset center, double radius) {
    const edges = [CoverageSector.bandEdgeZ, -CoverageSector.bandEdgeZ];
    for (final z in edges) {
      final front = Path();
      final back = Path();
      const steps = 72;
      final ring = math.sqrt(math.max(0, 1 - z * z));
      for (var step = 0; step <= steps; step++) {
        final angle = step / steps * 2 * math.pi;
        final point = _project(
          ScanDirection(
            x: math.cos(angle) * ring,
            y: math.sin(angle) * ring,
            z: z,
          ),
          center,
          radius,
        );
        final path = point.depth <= 0 ? front : back;
        if (step == 0) {
          path.moveTo(point.offset.dx, point.offset.dy);
        } else {
          path.lineTo(point.offset.dx, point.offset.dy);
        }
      }
      final backStroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.05);
      final frontStroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.13);
      canvas
        ..drawPath(back, backStroke)
        ..drawPath(front, frontStroke);
    }
  }

  /// The object the globe belongs to: a soft ball at the centre.
  void _paintObject(Canvas canvas, Offset center, double radius) {
    final objectRadius = radius * _objectScale;
    final rect = Rect.fromCircle(center: center, radius: objectRadius);
    final body = Paint()
      ..shader = RadialGradient(
        colors: [
          colors.accentSoft.withValues(alpha: 0.30),
          colors.accentSoft.withValues(alpha: 0.05),
        ],
      ).createShader(rect);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = colors.accent.withValues(alpha: 0.35);
    canvas
      ..drawCircle(center, objectRadius, body)
      ..drawCircle(center, objectRadius, rim);
  }

  void _paintSectorDot(
    Canvas canvas,
    _Projected point, {
    required bool covered,
    required bool behind,
  }) {
    final nearness = point.nearness.clamp(0, 1);
    if (covered) {
      final size = 2.4 + 2.8 * nearness;
      if (!behind) {
        // A soft halo on the near side: the finished sides are the thing the
        // user came to this screen to check.
        canvas.drawCircle(
          point.offset,
          size * 2.1,
          Paint()..color = colors.accent.withValues(alpha: 0.16 * nearness),
        );
      }
      canvas.drawCircle(
        point.offset,
        size,
        Paint()
          ..color = colors.accent.withValues(
            alpha: (behind ? 0.30 : 0.55) + 0.4 * nearness,
          ),
      );
      return;
    }
    canvas.drawCircle(
      point.offset,
      1.3 + 1.4 * nearness,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10 + 0.22 * nearness),
    );
  }

  /// Marks the globe's vertical axis (the object's top).
  void _paintUpMarker(Canvas canvas, Offset center, double radius) {
    final top = _project(
      const ScanDirection(x: 0, y: 0, z: 1),
      center,
      radius,
    );
    final core = Paint()..color = Colors.white.withValues(alpha: 0.55);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.25);
    canvas
      ..drawCircle(top.offset, 3, core)
      ..drawCircle(top.offset, 6, ring);
  }

  /// Rings the direction the phone is pointing at right now.
  void _paintCurrentDirection(Canvas canvas, Offset center, double radius) {
    final current = currentDirection;
    if (current == null || !current.isUsable) {
      return;
    }
    final point = _project(current, center, radius);
    final opacity = 0.35 + 0.55 * point.nearness.clamp(0, 1);
    final marker = colors.textPrimary.withValues(alpha: opacity);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = marker;
    canvas
      ..drawCircle(point.offset, 13, ring)
      ..drawCircle(point.offset, 4, Paint()..color = marker);
  }

  /// Rotates a unit direction by the globe's yaw and pitch, then projects it
  /// orthographically. `depth` comes back as the view axis.
  _Projected _project(
    ScanDirection direction,
    Offset center,
    double radius,
  ) {
    final cosYaw = math.cos(yaw);
    final sinYaw = math.sin(yaw);
    final x = direction.x * cosYaw - direction.y * sinYaw;
    final y = direction.x * sinYaw + direction.y * cosYaw;
    final z = direction.z;

    final cosPitch = math.cos(pitch);
    final sinPitch = math.sin(pitch);
    final depth = y * cosPitch - z * sinPitch;
    final up = y * sinPitch + z * cosPitch;

    return _Projected(
      center + Offset(x * radius, -up * radius),
      depth,
    );
  }

  @override
  bool shouldRepaint(_GlobePainter oldDelegate) =>
      oldDelegate.map != map ||
      oldDelegate.currentDirection != currentDirection ||
      oldDelegate.yaw != yaw ||
      oldDelegate.pitch != pitch ||
      oldDelegate.colors != colors;
}
