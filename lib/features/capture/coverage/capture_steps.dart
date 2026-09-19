import 'dart:math' as math;

import 'package:forma/platform/native_bridge/capture_state.dart';

/// The sides the guided walk asks for, in the order it asks for them.
///
/// The order is the one a person actually works in: the side facing them
/// first, then around their own body's right, then back down the left, then
/// the top, and the underside last because it is the one that needs the
/// object turned over (user request 2026-09-20).
enum CaptureStepId { front, right, back, left, top, underside }

/// Where one requested side stands.
enum CaptureStepStatus {
  /// A frame has been kept from this side.
  captured,

  /// The user skipped it (the underside of something that cannot be turned).
  skipped,

  /// The side being asked for right now.
  current,

  /// Still to come.
  pending,
}

/// One side of the object, named in terms of where the *user* stands.
///
/// The name is deliberately about the user's own body ("turn to your right")
/// rather than the object's anatomy: nobody can tell which side of an
/// anonymous object is its "right", but everybody knows which way their right
/// is. Guidance that says "the object's right" is guidance the user has to
/// translate, and this project has already been burned once by guidance that
/// pointed the wrong way (gotcha 21).
class CaptureStep {
  /// Creates a step.
  const CaptureStep({required this.id, required this.target});

  /// Which side this is.
  final CaptureStepId id;

  /// The object-facing direction a frame has to be kept from, in the
  /// direction recorder's gravity-aligned frame (z is up).
  final ScanDirection target;
}

/// The six named sides of a scan, tracked against the frames really kept.
///
/// This is the "one side at a time" walk. It exists because walking a free
/// circle is the slowest way to scan: the user has to hold a whole lap in
/// their head, re-cover sides they already have, and decide for themselves
/// when to stop. Naming one side, watching for the frame, and moving on turns
/// that into six short steps with an obvious end
/// (user request 2026-09-20: "show right side, left and all of it, then
/// capture them one by one, making it faster and easier").
///
/// Nothing here is simulated: a side counts as captured only when the session
/// really kept a frame from that direction, which is the same signal the
/// coverage globe is drawn from.
class CaptureStepPlan {
  const CaptureStepPlan._(
    this.steps,
    this._kept,
    this.skipped,
    this.focused,
    this._flipKeptCount,
  );

  /// Builds the walk from the frames kept so far.
  ///
  /// [kept] must be the directions the session actually stored a frame for;
  /// live aiming samples are not coverage and are ignored by the caller.
  /// [flipKeptCount] is how many frames had been kept when the object was
  /// flipped over, or null before any flip — it is what makes the underside
  /// countable (see [_isCaptured]).
  factory CaptureStepPlan.from({
    required List<ScanDirection> kept,
    Set<CaptureStepId> skipped = const {},
    CaptureStepId? focused,
    int? flipKeptCount,
  }) {
    final anchor = _anchorOf(kept);
    if (anchor == null) {
      // No frame has been kept from a usable angle yet, so there is no way to
      // name a side: "right" is meaningless until we know which way "front"
      // is. The plan stays empty and the caller asks for the front first.
      return CaptureStepPlan._(const [], kept, skipped, focused, flipKeptCount);
    }
    final steps = [
      CaptureStep(id: CaptureStepId.front, target: anchor),
      // Rotating the anchor by +90° is the user's right. Verified concretely,
      // because the sign is not guessable: standing at -y facing +y with +z
      // up, the user's right hand points to +x, so walking right moves the
      // phone to +x and the object-facing direction becomes (1, 0, 0) — which
      // is indeed rotate((0, -1, 0), +90°).
      CaptureStep(
        id: CaptureStepId.right,
        target: _rotateHorizontal(anchor, 90),
      ),
      CaptureStep(
        id: CaptureStepId.back,
        target: _rotateHorizontal(anchor, 180),
      ),
      CaptureStep(
        id: CaptureStepId.left,
        target: _rotateHorizontal(anchor, -90),
      ),
      const CaptureStep(
        id: CaptureStepId.top,
        target: ScanDirection(x: 0, y: 0, z: 1),
      ),
      const CaptureStep(
        id: CaptureStepId.underside,
        target: ScanDirection(x: 0, y: 0, z: -1),
      ),
    ];
    return CaptureStepPlan._(steps, kept, skipped, focused, flipKeptCount);
  }

  /// The walk, or empty while no side can be named yet.
  final List<CaptureStep> steps;

  final List<ScanDirection> _kept;
  final Set<CaptureStepId> skipped;

  /// A side the user tapped to do out of order, if any.
  final CaptureStepId? focused;

  /// Frames already kept when the object was flipped, or null before a flip.
  final int? _flipKeptCount;

  /// How close a kept frame has to be to a side to count for it, in degrees.
  ///
  /// 40° is generous enough that the user does not have to be exact, and
  /// still under the 45° that would let one frame tick two adjacent sides —
  /// which would make the checklist claim a side nobody ever pointed at.
  static const double toleranceDegrees = 40;

  /// Whether the sides can be named yet.
  bool get isAnchored => steps.isNotEmpty;

  /// The side being asked for: the one the user tapped, else the next
  /// unfinished one, else null when there is nothing left to ask for.
  CaptureStepId? get currentId {
    if (steps.isEmpty) {
      return null;
    }
    final wanted = focused;
    if (wanted != null && !_isDone(wanted)) {
      return wanted;
    }
    for (final step in steps) {
      if (!_isDone(step.id)) {
        return step.id;
      }
    }
    return null;
  }

  /// Where [id] stands.
  CaptureStepStatus statusOf(CaptureStepId id) {
    if (!isAnchored || _stepFor(id) == null) {
      return CaptureStepStatus.pending;
    }
    if (isCaptured(id)) {
      return CaptureStepStatus.captured;
    }
    if (skipped.contains(id)) {
      return CaptureStepStatus.skipped;
    }
    return id == currentId
        ? CaptureStepStatus.current
        : CaptureStepStatus.pending;
  }

  /// Whether a frame was really kept from this side.
  bool isCaptured(CaptureStepId id) {
    final step = _stepFor(id);
    return step != null && _isCaptured(step);
  }

  /// Whether the walk is finished with [id] — captured, or deliberately
  /// skipped.
  ///
  /// Deliberately does not consult [currentId], which is built from this:
  /// having the two call each other is an infinite loop, and that is exactly
  /// how this shipped for one build (the whole plan overflowed the stack the
  /// moment anything asked for a side's status).
  bool _isDone(CaptureStepId id) => isCaptured(id) || skipped.contains(id);

  /// The side being asked for, or null when there is nothing to ask for.
  CaptureStep? get currentStep {
    final id = currentId;
    return id == null ? null : _stepFor(id);
  }

  /// How many sides have a frame.
  int get capturedCount => steps.where(_isCaptured).length;

  /// Every side has either been captured or deliberately skipped.
  ///
  /// An unanchored plan is "complete" on purpose: when the phone is not
  /// reporting directions there is nothing to guide with, and an empty
  /// checklist must not become a checklist that can never be satisfied —
  /// which is exactly the trap that made scans take twenty minutes
  /// (gotcha 35).
  bool get isComplete {
    if (steps.isEmpty) {
      return true;
    }
    return steps.every((step) => _isDone(step.id));
  }

  /// Whether every side was actually captured, with nothing skipped. The
  /// honest version of "you have all of it".
  bool get isFullyCaptured => steps.isNotEmpty && steps.every(_isCaptured);

  /// The sides still to ask for, for a compact readout.
  List<CaptureStepId> get remaining => [
        for (final step in steps)
          if (!_isDone(step.id)) step.id,
      ];

  bool _isCaptured(CaptureStep step) {
    final flipKeptCount = _flipKeptCount;
    if (step.id == CaptureStepId.underside && flipKeptCount != null) {
      // After a flip the underside is no longer "down" in the phone's
      // gravity-aligned frame: the user has physically turned the object over
      // so its bottom faces them, which makes the direction it would be shot
      // from horizontal — the (0, 0, -1) target can never be met again.
      //
      // So the flip *is* the signal. A second pass exists for exactly one
      // reason, which is the side nobody could reach, and it only ever runs
      // because the user asked for it. A frame kept in it is that side.
      return _kept.length > flipKeptCount;
    }
    final threshold = math.cos(toleranceDegrees * math.pi / 180);
    return _kept.any(
      (direction) =>
          direction.isUsable && step.target.dot(direction) >= threshold,
    );
  }

  CaptureStep? _stepFor(CaptureStepId id) {
    for (final step in steps) {
      if (step.id == id) {
        return step;
      }
    }
    return null;
  }

  /// The front bearing: the first kept frame taken from a roughly level angle.
  ///
  /// A frame shot while looking almost straight down carries no bearing to
  /// name sides from, so it cannot anchor the walk — it is skipped rather
  /// than normalised into nonsense.
  static ScanDirection? _anchorOf(List<ScanDirection> kept) {
    for (final direction in kept) {
      final horizontal = math.sqrt(
        direction.x * direction.x + direction.y * direction.y,
      );
      if (horizontal >= 0.5) {
        return ScanDirection(
          x: direction.x / horizontal,
          y: direction.y / horizontal,
          z: 0,
        );
      }
    }
    return null;
  }

  /// Rotates a level direction around the vertical axis.
  static ScanDirection _rotateHorizontal(ScanDirection from, double degrees) {
    final radians = degrees * math.pi / 180;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return ScanDirection(
      x: from.x * cos - from.y * sin,
      y: from.x * sin + from.y * cos,
      z: 0,
    );
  }
}
