import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:forma/design_system/tokens/app_colors.dart';
import 'package:forma/design_system/tokens/motion.dart';

/// Circular progress ring — 3pt accent stroke, rounded caps.
///
/// Per design.md §3.4: animates between values with an eased curve.
class ProgressRing extends StatelessWidget {
  /// Creates a progress ring. [progress] must be between 0 and 1.
  const ProgressRing({
    required this.progress,
    this.size = 96,
    this.strokeWidth = 3,
    this.trackColor,
    super.key,
  }) : assert(progress >= 0 && progress <= 1, 'progress must be 0..1');

  /// Completion fraction from 0 to 1.
  final double progress;

  /// Diameter of the ring.
  final double size;

  /// Stroke thickness.
  final double strokeWidth;

  /// Background track color; defaults to a dimmed accent.
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final colors = FormaColors.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: Motion.smooth,
      curve: Motion.curve,
      builder: (context, animatedValue, _) {
        return CustomPaint(
          size: Size.square(size),
          painter: _RingPainter(
            progress: animatedValue,
            strokeColor: colors.accent,
            trackColor: trackColor ?? colors.accent.withValues(alpha: 0.15),
            strokeWidth: strokeWidth,
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.strokeColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color strokeColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);

    if (progress > 0) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = strokeColor;
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.trackColor != trackColor;
}
