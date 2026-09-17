/// User-facing strings, centralized (rules.md §2).
///
/// Replaced by flutter_localizations (ARB) in Phase 5.
abstract final class Strings {
  static const appName = 'Forma';
  static const libraryTitle = 'Forma';
  static const emptyTitle = 'Nothing here yet';
  static const emptySubtitle = 'Scan your first object to turn it into 3D.';
  static const startScan = 'Start scanning';
  static const scanCta = 'Start Capture';
  static const finishCapture = 'Finish';
  static const cancel = 'Cancel';
  static const retry = 'Try again';
  static const loadFailedTitle = 'Something went wrong';
  static const loadFailedSubtitle = 'Could not load your library.';
  static const aimHint = 'Aim at your object';
  static const detectingHint = 'Line the object up inside the box';
  static const capturingHint =
      'Walk a full circle around the object — keep every side in view';
  static const lowLightHint =
      'It is too dark to scan. Move somewhere brighter.';
  static const objectNotDetectedHint =
      'Point at the object and hold steady.';
  static const finishingHint = 'Finishing up';
  static const reconstructing = 'Reconstructing';
  static const modelReady = 'Model ready!';
  static const moveCloser = 'Move closer to the object';
  static const moveFarther = 'Move a bit farther away';
  static const slowDown = 'Slow down';
  static const keepInView = 'Keep the object in view';
  static const unsupportedTitle = 'Forma needs a Pro iPhone';
  static const unsupportedBody =
      '3D scanning uses the LiDAR sensor, available on iPhone Pro models '
      '(12 Pro and newer) with iOS 17 or later.';
  static const unsupportedCta = 'Learn more about supported devices';
  static const close = 'Close';
  static const unsupportedDevicesTitle = 'Devices that can scan';
  static const unsupportedDevicesBody =
      'iPhone 12 Pro and newer Pro models, and iPad Pro (2020 or later) — '
      'any device with a LiDAR scanner.';
  static const cameraUnavailable =
      'Camera preview unavailable. Check camera permission in Settings.';
  static const errorTitle = 'Something went wrong';
  static const errorBody = 'Please try again.';
  static const genericError = 'Something went wrong. Please try again.';
  static const cameraPermissionDenied =
      'Forma needs camera access to scan. Enable it in Settings.';
  static const storageFull =
      'Not enough free space to scan. Free up at least 4 GB and try again.';
  static const gettingReady = 'Getting ready…';
  static const captureNotReady =
      'The scan is still warming up. Hold the phone steady for a moment and '
      'tap again.';
  static const cameraDead =
      'The camera stopped responding. Please check camera permission in '
      'Settings and try again.';
  static const scanFailed =
      'The scan stopped unexpectedly. Please try again.';
  static const scanFull =
      'This scan has all the photos it can hold. Tap Finish to build it.';
  static const cameraSensorFailed =
      'The camera reported a problem. Close the app, reopen it, and try '
      'again.';
  static const trackingLost =
      'The camera lost track of the scene. Move to a brighter spot with more '
      'detail and try again.';
  static const scanSessionEnded =
      'The scan session ended. Close and reopen the capture screen.';
  static const reconstructionFailed =
      'Could not build the 3D model. Try again with more coverage of the '
      'object.';
  static const captureIncomplete =
      'The scan stopped before its photos were saved. Please scan again.';
  static const cameraStarting = 'Starting camera…';
  static const cameraDidNotStart =
      'The camera did not start. Close and reopen the app, then try again.';
  static const trackingInitializing =
      'Point at a well-lit, textured surface — the camera is warming up.';
  static const torchLabel = 'Flashlight';
  static const torchComingSoon = 'Torch arrives in the next build';

  /// Accessibility label for the capture step indicator.
  static String captureStepLabel(int step) => 'Step $step of 3';

  // 360° model viewer.
  static const modelViewerHint = 'Drag to rotate · pinch to zoom';
  static const resetView = 'Reset view';
  static const modelMissingTitle = 'Model not available';
  static const modelMissingSubtitle =
      'The 3D file for this scan is missing. Scan the object again to '
      'rebuild it.';
  static const modelViewerIosOnly =
      'The 360° viewer runs on iPhone. Open this scan there to see the model.';
  static const scanStillBuilding =
      'This scan is still being built. It will appear here when it is ready.';

  /// Build stamp injected at compile time by CI via `--dart-define`
  /// (`FORMA_BUILD`). Empty on local/dev builds, in which case nothing
  /// is shown.
  ///
  /// Device-test finding 2026-09-17: a stale IPA was reinstalled over a fixed
  /// one, so every fix looked like it had failed. The stamp makes the build
  /// actually running on the phone visible without a USB connection.
  static const buildStamp = String.fromEnvironment('FORMA_BUILD');
}
