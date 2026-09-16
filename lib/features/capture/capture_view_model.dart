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
      clearError: true,
    );
  }

  /// Arms the watchdog: if no native event arrives within
  /// [_cameraWatchdogTimeout], probe the session and surface an honest
  /// "camera dead" error instead of a frozen black preview.
  ///
  /// One-shot by design: every real native event re-arms it, and a
  /// successful probe means the session is alive (self re-arming would
  /// create an endless timer chain). If the probe errors — bridge
  /// unavailable — treat the camera as dead, honestly.
  void _resetWatchdog() {
    _watchdog?.cancel();
    if (_scanId == null || _disposed) {
      return;
    }
    _watchdog = Timer(watchdogTimeout, () async {
      if (_disposed || _scanId == null) {
        return;
      }
      var alive = false;
      try {
        alive = await _bridge.hasActiveCaptureSession();
      } on FormaError catch (e) {
        debugPrint('[forma] camera probe failed: ${e.debugMessage}');
      }
      if (_disposed || _scanId == null || alive) {
        return;
      }
      AppHaptics.error();
      state = state.copyWith(
        isCameraLive: false,
        isSessionStarting: false,
        error: Strings.cameraDead,
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
    state = state.copyWith(isReconstructing: false, isCompleted: true);
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
  Future<void> beginCapturing() async {
    final id = _scanId;
    if (id == null || _capturingRequested) {
      return;
    }
    try {
      _capturingRequested = true;
      await _bridge.beginCapturing(id);
      _resetWatchdog();
    } on FormaError catch (e) {
      _capturingRequested = false;
      AppHaptics.error();
      state = state.copyWith(error: e.userMessage);
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

  /// Honest, actionable message per native error code (rules.md §7).
  String _messageFor(int code) => switch (code) {
        1005 => Strings.cameraPermissionDenied,
        1007 => Strings.storageFull,
        _ => Strings.genericError,
      };
}

/// Riverpod provider for the capture flow.
final captureViewModelProvider =
    NotifierProvider<CaptureViewModel, CaptureUiState>(CaptureViewModel.new);
