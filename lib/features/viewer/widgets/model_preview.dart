import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Native 360° model viewer (RealityKit `ARView` in non-AR mode) embedded via
/// platform views. Tapping a saved scan opens this.
///
/// On non-iOS hosts the platform view cannot hydrate, so the caller renders
/// its own message instead — see `ModelViewerScreen`.
class ModelPreview extends StatelessWidget {
  /// Creates a viewer for the model file at [modelPath].
  const ModelPreview({required this.modelPath, super.key});

  /// Absolute path to the `.usdz` model inside the app container.
  final String modelPath;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }
    return UiKitView(
      viewType: 'com.forma.app/model_viewer',
      // The native side reads {"path": …} from the creation parameters.
      creationParams: <String, Object?>{'path': modelPath},
      creationParamsCodec: const StandardMessageCodec(),
      // Eager, not the default empty set.
      //
      // With no factory registered, touches reach the platform view only once
      // Flutter's own gesture arena has resolved — and its verdict arrives
      // per pointer sequence, which is why a one-finger orbit began while the
      // second finger of a pinch was still queued and the zoom never fired
      // (device-test finding 2026-09-18: "rotation works, pinch does not").
      // An eager recogniser wins the arena on touch-down, so the native view
      // owns the whole sequence from the first frame.
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
    );
  }
}
