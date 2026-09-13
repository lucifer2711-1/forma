import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:forma/core/errors/forma_error.dart';
import 'package:forma/core/models/scan.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/design_system/haptics/app_haptics.dart';
import 'package:forma/platform/native_bridge/capture_state.dart';
import 'package:forma/platform/native_bridge/native_bridge.dart';

/// Immutable UI state for the capture flow.
class CaptureUiState {
  const CaptureUiState({
    this.phase,
    this.feedback = CaptureFeedbackType.none,
    this.isReconstructing = false,
    this.reconstructionProgress = 0,
    this.isCompleted = false,
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

  /// User-facing error message; null when healthy.
  final String? error;

  bool get isIdle => phase == null && !isReconstructing && error == null;

  CaptureUiState copyWith({
    CapturePhase? phase,
    CaptureFeedbackType? feedback,
    bool? isReconstructing,
    double? reconstructionProgress,
    bool? isCompleted,
    String? error,
  }) {
    return CaptureUiState(
      phase: phase ?? this.phase,
      feedback: feedback ?? this.feedback,
      isReconstructing: isReconstructing ?? this.isReconstructing,
      reconstructionProgress:
          reconstructionProgress ?? this.reconstructionProgress,
      isCompleted: isCompleted ?? this.isCompleted,
      error: error ?? this.error,
    );
  }
}

/// Drives the capture screen through the [NativeBridge] and persists the
/// finished scan.
class CaptureViewModel extends Notifier<CaptureUiState> {
  late NativeBridge _bridge;
  final _subs = <StreamSubscription<dynamic>>[];
  String? _scanId;

  @override
  CaptureUiState build() {
    _bridge = ref.read(nativeBridgeProvider);
    ref.onDispose(() {
      for (final sub in _subs) {
        unawaited(sub.cancel());
      }
    });
    _listen();
    return const CaptureUiState();
  }

  void _listen() {
    _subs
      ..add(_bridge.phaseUpdates.listen((phase) {
        AppHaptics.stateChange();
        if (phase == CapturePhase.failed) {
          state = state.copyWith(
            isReconstructing: false,
            error: 'Something went wrong. Please try again.',
          );
          return;
        }
        state = state.copyWith(phase: phase);
      }))
      ..add(_bridge.feedbackUpdates.listen((feedback) {
        state = state.copyWith(feedback: feedback.type);
      }))
      ..add(_bridge.reconstructionProgressUpdates.listen((value) {
        state = state.copyWith(
          isReconstructing: true,
          reconstructionProgress: value,
        );
      }))
      ..add(_bridge.reconstructionCompleteUpdates.listen(_onComplete))
      ..add(_bridge.errorUpdates.listen((error) {
        AppHaptics.error();
        state = state.copyWith(
          isReconstructing: false,
          error: 'Something went wrong. Please try again.',
        );
      }));
  }

  Future<void> _onComplete(String modelPath) async {
    AppHaptics.success();
    final id = _scanId;
    if (id == null) {
      return;
    }
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
  }

  /// Starts a new capture session.
  Future<void> start() async {
    if (_scanId != null) {
      return;
    }
    try {
      _scanId = await _bridge.startCapture();
    } on FormaError catch (e) {
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
}

/// Riverpod provider for the capture flow.
final captureViewModelProvider =
    NotifierProvider<CaptureViewModel, CaptureUiState>(CaptureViewModel.new);
