import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:forma/core/errors/forma_error.dart';
import 'package:forma/core/models/scan.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/core/strings.dart';
import 'package:forma/design_system/haptics/app_haptics.dart';
import 'package:forma/platform/native_bridge/capture_state.dart';
import 'package:forma/platform/native_bridge/native_bridge.dart';

/// How long the capture session may stay silent before the view model
/// probes (and later declares dead) the native camera preview.
const _cameraWatchdogTimeout = Duration(seconds: 8);

/// How long startCapture() may take before the session is declared wedged.
/// Without this, a dropped method-channel reply leaves the screen on
/// "Starting camera…" forever with no way to recover (device-test finding
/// 2026-09-16: update-install retest).
const _startCaptureTimeout = Duration(seconds: 20);

/// How long to wait before retrying a capture request that the native
/// session rejected as "not ready yet".
const _captureRetryDelay = Duration(milliseconds: 300);

/// How many times a capture request may be retried while the session warms
/// up (~2 s) before the refusal is reported.
const _maxCaptureRetries = 6;

/// Immutable UI state for the capture flow.
class CaptureUiState {
  const CaptureUiState({
    this.phase,
    this.feedback = CaptureFeedbackType.none,
    this.isReconstructing = false,
    this.reconstructionProgress = 0,
    this.isCompleted = false,
    this.isCameraLive = false,
    this.isSessionStarting = false,
    this.isTrackingInitializing = false,
    this.isCapturePending = false,
    this.error,
  });

  /// Latest bridge capture phase; null until capture starts.
  final CapturePhase? phase;

  /// Latest guidance feedback.
  final CaptureFeedbackType feedback;

  /// Reconstruction is running.
  final bool isReconstructing;

  /// Reconstruction progress 0..1.
  final double reconstructionProgress;

  /// Model finished and saved; the screen should pop.
  final bool isCompleted;

  /// Whether the native camera feed is confirmed alive. True once any
  /// phase event arrives and the watchdog has not fired.
  final bool isCameraLive;

  /// True between startCapture() and the first phase event — used to
  /// distinguish "starting camera" from "camera dead".
  final bool isSessionStarting;

  /// True when the native session exists but ARKit tracking hasn't locked
  /// yet (poor lighting/texture). Guidance case — not an error.
  final bool isTrackingInitializing;

  /// A capture tap has been sent but the session has not confirmed it yet.
  /// Keeps a tap visible in the UI while it is being retried.
  final bool isCapturePending;

  /// User-facing error message; null when healthy.
  final String? error;

  bool get isIdle =>
      phase == null && !isReconstructing && error == null && !isCameraLive;

  CaptureUiState copyWith({
    CapturePhase? phase,
    CaptureFeedbackType? feedback,
    bool? isReconstructing,
    double? reconstructionProgress,
    bool? isCompleted,
    bool? isCameraLive,
    bool? isSessionStarting,
    bool? isTrackingInitializing,
    bool? isCapturePending,
    String? error,
    bool clearError = false,
  }) {
    return CaptureUiState(
      phase: phase ?? this.phase,
      feedback: feedback ?? this.feedback,
      isReconstructing: isReconstructing ?? this.isReconstructing,
      reconstructionProgress:
          reconstructionProgress ?? this.reconstructionProgress,
      isCompleted: isCompleted ?? this.isCompleted,
      isCameraLive: isCameraLive ?? this.isCameraLive,
      isSessionStarting: isSessionStarting ?? this.isSessionStarting,
      isTrackingInitializing:
          isTrackingInitializing ?? this.isTrackingInitializing,
      isCapturePending: isCapturePending ?? this.isCapturePending,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Drives the capture screen through the [NativeBridge] and persists the
/// finished scan.
class CaptureViewModel extends Notifier<CaptureUiState> {
  CaptureViewModel({
    this.watchdogTimeout = _cameraWatchdogTimeout,
    this.startCaptureTimeout = _startCaptureTimeout,
  });

  /// How long the session may stay silent before the camera-health probe
  /// runs. Tests inject a short value to keep them fast.
  final Duration watchdogTimeout;

  /// How long startCapture() may run before it is declared wedged. Tests
  /// inject a short value to keep them fast.
  final Duration startCaptureTimeout;

  late NativeBridge _bridge;
  final _subs = <StreamSubscription<dynamic>>[];
  Timer? _watchdog;
  Timer? _captureRetry;
  String? _scanId;
  bool _capturingRequested = false;
  bool _startingSession = false;
  bool _disposed = false;
  int _sessionStartGeneration = 0;

  @override
  CaptureUiState build() {
    _bridge = ref.read(nativeBridgeProvider);
    ref.onDispose(() {
      _disposed = true;
      _watchdog?.cancel();
      _captureRetry?.cancel();
      for (final sub in _subs) {
        unawaited(sub.cancel());
      }
    });
    _listen();
    return const CaptureUiState();
  }

  void _listen() {
    _subs
      ..add(_bridge.phaseUpdates.listen(_onPhase))
      ..add(_bridge.feedbackUpdates.listen((feedback) {
        state = state.copyWith(feedback: feedback.type);
      }))
      ..add(_bridge.reconstructionProgressUpdates.listen((value) {
        _resetWatchdog();
        state = state.copyWith(
          isReconstructing: true,
          reconstructionProgress: value,
        );
      }))
      ..add(_bridge.reconstructionCompleteUpdates.listen(_onComplete))
      ..add(_bridge.errorUpdates.listen((error) {
        // Keep the technical detail in logs only — the UI shows the safe
        // message (rules.md §7), but never swallow the diagnostic entirely.
        debugPrint('[forma] bridge error ${error.code}: ${error.message}');
        AppHaptics.error();
        state = state.copyWith(
          isReconstructing: false,
          isSessionStarting: false,
          error: _messageFor(error.code),
        );
      }));
  }

  void _onPhase(CapturePhase phase) {
    _resetWatchdog();
    AppHaptics.stateChange();
    if (phase == CapturePhase.failed) {
      // A specific error event (storage, permission) may already have set
      // the honest reason — don't overwrite it with the generic message.
      state = state.copyWith(
        isReconstructing: false,
        isSessionStarting: false,
        isCameraLive: false,
        error: state.error ?? Strings.genericError,
      );
      return;
    }
    // Any phase event proves the native session is alive — the camera
    // preview runs simultaneously with capture from this point on.
    state = state.copyWith(
      phase: phase,
      isCameraLive: true,
      isSessionStarting: false,
      isTrackingInitializing: false,
      clearError: true,
    );
    if (phase == CapturePhase.capturing) {
      // Capture is running: the CTA becomes Finish and no retry is needed.
      _captureRetry?.cancel();
      state = state.copyWith(isCapturePending: false);
      return;
    }
    if (phase == CapturePhase.completed) {
      _captureRetry?.cancel();
      state = state.copyWith(isCapturePending: false);
      _ensureReconstruction();
      return;
    }
    // A tap made while the session was still warming up starts capturing
    // the moment Object Capture says it is ready.
    _flushPendingCapture();
  }

  /// Hands a finished session to reconstruction exactly once.
  ///
  /// The session can reach `.completed` without the app having driven it on —
  /// a finish that never made it to the reconstruction step, or a phase that
  /// arrived late. Without this the screen dead-ended: no CTA, no progress,
  /// and the scan was never built (device-test finding 2026-09-18).
  void _ensureReconstruction() {
    if (_disposed ||
        _scanId == null ||
        state.isReconstructing ||
        state.isCompleted) {
      return;
    }
    unawaited(_startReconstruction());
  }

  /// Fires a capture tap the user made before the session was ready.
  void _flushPendingCapture() {
    if (!state.isCapturePending || _capturingRequested) {
      return;
    }
    if (state.phase != CapturePhase.detecting) {
      return;
    }
    unawaited(beginCapturing());
  }

  /// Arms the watchdog: if no native event arrives within
  /// [_cameraWatchdogTimeout], probe the session state and react honestly:
  /// - still `.initializing` → tracking hasn't locked (lighting/texture);
  ///   show guidance, NOT an error — the camera is alive (device test
  ///   2026-09-17: frames flowing at 30 Hz, tracking "not normal",
  ///   session parked in .initializing; the old probe called this dead
  ///   and blamed a permission the user had already granted).
  /// - any other live phase → events stalled; mark the camera live.
  /// - no session / failed → surface the honest camera-dead error.
  /// One-shot per arm; every real native event re-arms it.
  void _resetWatchdog() {
    _watchdog?.cancel();
    if (_scanId == null || _disposed) {
      return;
    }
    _watchdog = Timer(watchdogTimeout, () async {
      if (_disposed || _scanId == null) {
        return;
      }
      var stateName = 'none';
      try {
        stateName = await _bridge.getSessionState();
      } on FormaError catch (e) {
        debugPrint('[forma] camera probe failed: ${e.debugMessage}');
      }
      if (_disposed || _scanId == null) {
        return;
      }
      if (stateName == 'initializing') {
        state = state.copyWith(
          isSessionStarting: false,
          isCameraLive: false,
          isTrackingInitializing: true,
        );
        return;
      }
      if (stateName != 'none' && stateName != 'failed') {
        // Session alive in a real phase but the event stream stalled — or a
        // transition fired before Dart was listening. Adopt what the session
        // reports so the UI can never stay stale about what it may offer.
        final probed = _phaseFromName(stateName);
        final isCapturing = probed == CapturePhase.capturing ||
            probed == CapturePhase.finishing ||
            probed == CapturePhase.completed;
        state = state.copyWith(
          phase: probed,
          isCameraLive: true,
          isSessionStarting: false,
          isTrackingInitializing: false,
          // A confirmed capture is never still "pending".
          isCapturePending: isCapturing ? false : null,
          clearError: true,
        );
        if (probed == CapturePhase.completed) {
          // The completion event was missed: build the scan rather than
          // leaving the screen with nothing to tap.
          _ensureReconstruction();
          return;
        }
        _flushPendingCapture();
        return;
      }
      AppHaptics.error();
      state = state.copyWith(
        isCameraLive: false,
        isSessionStarting: false,
        // A specific reason (storage, permission, "not enough light") is
        // never replaced by the generic camera message — the honest error
        // the session already gave stays in front of the user.
        error: state.error ?? Strings.cameraDead,
      );
    });
  }

  Future<void> _onComplete(String modelPath) async {
    final id = _scanId;
    if (id == null) {
      return;
    }
    debugPrint('[forma] scan $id completed → $modelPath');
    _watchdog?.cancel();
    _captureRetry?.cancel();
    final now = DateTime.now();
    await ref.read(scanRepositoryProvider).save(
          Scan(
            id: id,
            name: 'Scan ${now.hour.toString().padLeft(2, '0')}:'
                '${now.minute.toString().padLeft(2, '0')}',
            createdAt: now,
            status: ScanStatus.ready,
            modelPath: modelPath,
          ),
        );
    state = state.copyWith(
      isReconstructing: false,
      isCompleted: true,
      isCapturePending: false,
    );
    // Clear the scan bookkeeping so the NEXT session can start; the UI
    // state itself stays "completed" until the screen pops and start()
    // resets it. (Device-test finding 2026-09-15: reopening capture must
    // never inherit the finished session.)
    _scanId = null;
    _capturingRequested = false;
  }

  /// Starts a new capture session.
  ///
  /// Re-entrancy safe: the native permission dialog blocks startCapture()
  /// for as long as the dialog is on screen, and during that window the
  /// pulsing Start button stays tappable — a second start() here used to
  /// stack a second native session on top of the pending one and wedged
  /// the screen (device-test finding 2026-09-16). Guarded, and the call
  /// itself times out so a dropped reply can never hang the UI forever.
  Future<void> start() async {
    if (_scanId != null || _startingSession) {
      return;
    }
    _startingSession = true;
    // Fresh session — clear any stale phase/feedback/error left over.
    state = const CaptureUiState(isSessionStarting: true);
    final generation = ++_sessionStartGeneration;
    try {
      _capturingRequested = false;
      _scanId = await _bridge.startCapture().timeout(
            startCaptureTimeout,
            onTimeout: () => throw const CameraTimeoutError(
              'startCapture exceeded the start timeout',
            ),
          );
      if (generation != _sessionStartGeneration || _disposed) {
        return; // A newer start()/cancel() superseded this one.
      }
      // Session created natively; if the first phase event never arrives
      // the watchdog will surface an honest "camera dead" error.
      _resetWatchdog();
    } on FormaError catch (e) {
      AppHaptics.error();
      state = state.copyWith(
        isSessionStarting: false,
        error: e.userMessage,
      );
    } finally {
      _startingSession = false;
    }
  }

  /// Starts the session, or advances to capturing if already started.
  Future<void> startOrBegin() async {
    if (_scanId == null) {
      await start();
      return;
    }
    await beginCapturing();
  }

  /// Advances the active session from detection into image capture.
  ///
  /// The native session owns this decision — it is the only thing that knows
  /// its real state, and its guard is what stops `startCapturing()` from
  /// trapping the app. Dart therefore asks and reacts, instead of gating on a
  /// mirrored phase that can be stale (device-test finding 2026-09-17: a
  /// missed startup phase event left every tap a silent no-op).
  ///
  /// "Not ready yet" (native code 1006) is a timing answer, not a failure:
  /// the request is retried briefly, and the CTA shows "Getting ready…" in
  /// the meantime so the tap is never invisible.
  Future<void> beginCapturing({int attempt = 1}) async {
    final id = _scanId;
    if (id == null || _capturingRequested) {
      return;
    }
    try {
      _capturingRequested = true;
      state = state.copyWith(isCapturePending: true, clearError: true);
      await _bridge.beginCapturing(id);
      _resetWatchdog();
    } on CaptureNotReadyError {
      _capturingRequested = false;
      if (attempt < _maxCaptureRetries) {
        _captureRetry?.cancel();
        _captureRetry = Timer(_captureRetryDelay, () {
          if (!_disposed && state.isCapturePending) {
            unawaited(beginCapturing(attempt: attempt + 1));
          }
        });
        return;
      }
      // The session kept refusing: say so instead of pretending the tap
      // was accepted.
      AppHaptics.error();
      state = state.copyWith(
        isCapturePending: false,
        error: Strings.captureNotReady,
      );
    } on FormaError catch (e) {
      _capturingRequested = false;
      AppHaptics.error();
      state = state.copyWith(
        isCapturePending: false,
        error: e.userMessage,
      );
    }
  }

  /// Finishes capture and kicks off reconstruction.
  Future<void> finish() async {
    final id = _scanId;
    if (id == null) {
      return;
    }
    state = state.copyWith(isReconstructing: true);
    try {
      await _bridge.finishCapture(id);
      await _startReconstruction();
    } on FormaError catch (e) {
      AppHaptics.error();
      state = state.copyWith(isReconstructing: false, error: e.userMessage);
    }
  }

  /// Starts reconstruction for the active scan and surfaces its failures.
  Future<void> _startReconstruction() async {
    final id = _scanId;
    if (id == null) {
      return;
    }
    state = state.copyWith(isReconstructing: true, clearError: true);
    try {
      await _bridge.startReconstruction(id);
    } on FormaError catch (e) {
      AppHaptics.error();
      state = state.copyWith(isReconstructing: false, error: e.userMessage);
    }
  }

  /// Cancels the session and resets to idle.
  Future<void> cancel() async {
    final id = _scanId;
    _scanId = null;
    _capturingRequested = false;
    _sessionStartGeneration++;
    _watchdog?.cancel();
    _captureRetry?.cancel();
    if (id != null) {
      unawaited(_bridge.cancelCapture(id));
    }
    state = const CaptureUiState();
  }

  /// Clears an error and starts a fresh session.
  Future<void> retry() async {
    await cancel();
    await start();
  }

  /// Maps a native phase name back to the bridge enum; null when the native
  /// side reports something we have no phase for (e.g. "none").
  static CapturePhase? _phaseFromName(String name) {
    for (final phase in CapturePhase.values) {
      if (phase.name == name) {
        return phase;
      }
    }
    return null;
  }

  /// Honest, actionable message per native error code (rules.md §7).
  ///
  /// Every one of these used to collapse into "Something went wrong. Please
  /// try again.", so a failed scan named no cause — neither to the user nor
  /// to anyone reading the screen (device-test finding 2026-09-18).
  String _messageFor(int code) => switch (code) {
        1001 => Strings.scanFailed,
        1002 || 1004 => Strings.scanSessionEnded,
        1005 => Strings.cameraPermissionDenied,
        1007 => Strings.storageFull,
        1008 => Strings.scanFull,
        1009 => Strings.cameraSensorFailed,
        1010 => Strings.trackingLost,
        2001 || 2002 => Strings.reconstructionFailed,
        2003 => Strings.captureIncomplete,
        _ => Strings.genericError,
      };
}

/// Riverpod provider for the capture flow.
final captureViewModelProvider =
    NotifierProvider<CaptureViewModel, CaptureUiState>(CaptureViewModel.new);
