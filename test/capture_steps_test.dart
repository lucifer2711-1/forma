import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:forma/features/capture/coverage/capture_steps.dart';
import 'package:forma/platform/native_bridge/capture_state.dart';

/// A level direction [degrees] around the vertical axis (z is up).
ScanDirection bearing(double degrees) {
  final radians = degrees * math.pi / 180;
  return ScanDirection(x: math.cos(radians), y: math.sin(radians), z: 0);
}

ScanDirection vertical(double z) => ScanDirection(x: 0, y: 0, z: z);

void main() {
  test('an empty walk asks for nothing and cannot block anyone', () {
    final plan = CaptureStepPlan.from(kept: const []);

    expect(plan.isAnchored, isFalse);
    expect(plan.steps, isEmpty);
    expect(plan.currentId, isNull);
    // The important one: with no directions to guide by there is nothing to
    // ask for, and an empty checklist must never become an unsatisfiable one
    // (gotcha 35).
    expect(plan.isComplete, isTrue);
  });

  test('the first level frame names the front', () {
    final plan = CaptureStepPlan.from(kept: [bearing(0)]);

    expect(plan.isAnchored, isTrue);
    expect(plan.isCaptured(CaptureStepId.front), isTrue);
    expect(plan.currentId, CaptureStepId.right);
  });

  test('"right" is the side you reach by turning right', () {
    // Standing at -y facing +y with +z up, the user's right hand points to
    // +x, so walking right puts the phone at +x and the object-facing
    // direction becomes (1, 0, 0). Pinned here because the sign is not
    // guessable and this project has already shipped inverted guidance once
    // (gotcha 21).
    final plan = CaptureStepPlan.from(
      kept: [const ScanDirection(x: 0, y: -1, z: 0)],
    );

    ScanDirection targetOf(CaptureStepId id) =>
        plan.steps.firstWhere((step) => step.id == id).target;

    expect(targetOf(CaptureStepId.right).x, closeTo(1, 1e-9));
    expect(targetOf(CaptureStepId.right).y, closeTo(0, 1e-9));
    expect(targetOf(CaptureStepId.left).x, closeTo(-1, 1e-9));
    expect(targetOf(CaptureStepId.back).y, closeTo(1, 1e-9));
  });

  test('a frame kept from a side ticks it and moves the walk on', () {
    final plan = CaptureStepPlan.from(kept: [bearing(0), bearing(90)]);

    expect(plan.isCaptured(CaptureStepId.front), isTrue);
    expect(plan.isCaptured(CaptureStepId.right), isTrue);
    expect(plan.isCaptured(CaptureStepId.back), isFalse);
    expect(plan.currentId, CaptureStepId.back);
    expect(plan.isComplete, isFalse);
  });

  test('one frame cannot claim two adjacent sides', () {
    // The 40° tolerance against sides 90° apart: a frame aimed between two of
    // them is 45° from each, so it ticks neither instead of both — which is
    // what stops the walk claiming a side nobody pointed at.
    final plan = CaptureStepPlan.from(kept: [bearing(0), bearing(45)]);

    expect(plan.isCaptured(CaptureStepId.right), isFalse);
    expect(plan.isCaptured(CaptureStepId.back), isFalse);
  });

  test('the top is a real side, captured by aiming down', () {
    final plan = CaptureStepPlan.from(kept: [bearing(0), vertical(1)]);

    expect(plan.isCaptured(CaptureStepId.top), isTrue);
    expect(plan.isCaptured(CaptureStepId.underside), isFalse);
  });

  test('the underside is counted from the flip, not from a direction', () {
    // Before a flip, the underside means shooting up from underneath.
    final before = CaptureStepPlan.from(kept: [bearing(0), vertical(-1)]);
    expect(before.isCaptured(CaptureStepId.underside), isTrue);

    // After a flip the object has been turned over, so its bottom faces the
    // user and no frame can ever come from (0, 0, -1) again. The flip is the
    // signal: the second pass exists for exactly one side, and it only ever
    // runs because the user asked for it.
    final flipped = CaptureStepPlan.from(
      kept: [bearing(0), bearing(180)],
      flipKeptCount: 2,
    );
    expect(flipped.isCaptured(CaptureStepId.underside), isFalse);

    final afterFlip = CaptureStepPlan.from(
      kept: [bearing(0), bearing(180), bearing(10)],
      flipKeptCount: 2,
    );
    expect(afterFlip.isCaptured(CaptureStepId.underside), isTrue);
  });

  test('skipping a side finishes the walk without claiming it was shot', () {
    final plan = CaptureStepPlan.from(
      kept: [bearing(0), bearing(90), bearing(180), bearing(-90), vertical(1)],
      skipped: {CaptureStepId.underside},
    );

    expect(plan.isComplete, isTrue);
    expect(plan.isFullyCaptured, isFalse);
    expect(plan.currentId, isNull);
    expect(plan.statusOf(CaptureStepId.underside), CaptureStepStatus.skipped);
    expect(plan.remaining, isEmpty);
  });

  test('a side the user taps is asked for next', () {
    final plan = CaptureStepPlan.from(
      kept: [bearing(0)],
      focused: CaptureStepId.underside,
    );

    expect(plan.currentId, CaptureStepId.underside);
    expect(plan.statusOf(CaptureStepId.underside), CaptureStepStatus.current);
    // The order it was already going to ask for is still tracked, so handing
    // the walk back to its own order resumes where it left off.
    expect(plan.statusOf(CaptureStepId.right), CaptureStepStatus.pending);
  });

  test('a steep frame cannot name the sides', () {
    // A frame shot while looking almost straight down carries no bearing to
    // name sides from, so it must not be normalised into a nonsense front.
    final plan = CaptureStepPlan.from(
      kept: [const ScanDirection(x: 0.1, y: 0, z: 0.99)],
    );

    expect(plan.isAnchored, isFalse);
    expect(plan.isComplete, isTrue);
  });
}
