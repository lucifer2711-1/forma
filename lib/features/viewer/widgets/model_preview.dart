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
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
    );
  }
}
