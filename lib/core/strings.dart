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

  // Reconstruction: what Apple's pipeline is doing, and how long is left.

  /// Stage names for Apple's `ProcessingStage` tokens (see
  /// `ReconstructionService.stageName`). Naming the actual step is the honest
  /// version of "please wait": the user learns the model is being aligned,
  /// then meshed, then textured, instead of watching a number crawl.
  static String reconstructionStageName(String stage) => switch (stage) {
        'preprocessing' => reconstructionStagePreprocessing,
        'aligning' => reconstructionStageAligning,
        'points' => reconstructionStagePoints,
        'mesh' => reconstructionStageMesh,
        'texture' => reconstructionStageTexture,
        'optimizing' => reconstructionStageOptimizing,
        _ => reconstructionWorking,
      };

  static const reconstructionStagePreprocessing = 'Preparing your photos';
  static const reconstructionStageAligning = 'Aligning the photos';
  static const reconstructionStagePoints = 'Building the point cloud';
  static const reconstructionStageMesh = 'Building the mesh';
  static const reconstructionStageTexture = 'Mapping the textures';
  static const reconstructionStageOptimizing = 'Optimising the model';
  static const reconstructionWorking = 'Building your model';

  /// RealityKit's own remaining-time estimate, said the way a person would.
  ///
  /// Rounded hard on purpose: "about 2 minutes" is useful, "1:47" is a
  /// promise the session never made.
  static String timeRemaining(int seconds) {
    if (seconds < 45) {
      return 'Almost done';
    }
    final minutes = (seconds / 60).round();
    return minutes <= 1
        ? 'About a minute left'
        : 'About $minutes minutes left';
  }
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
  /// Accessibility label for the torch toggle; its state is exposed
  /// separately via `Semantics(toggled:)`.
  static const torchLabel = 'Flashlight';

  // Library management: delete + navigation.

  static const back = 'Back';
  static const deleteScan = 'Delete';
  static const deleteScanTitle = 'Delete this scan?';

  /// Names the scan in the confirmation, so a mis-tap on the wrong card is
  /// caught before anything is destroyed.
  static String deleteScanBody(String name) =>
      '“$name” and its 3D model will be removed from this iPhone. '
      'This cannot be undone.';

  /// Accessibility label for the delete button on a card.
  static String deleteScanLabel(String name) => 'Delete $name';
  static const scanDeleted = 'Scan deleted';
  static const deleteFailed =
      'Could not delete this scan. Please try again.';
  static const keep = 'Keep';

  // Capture coverage guidance.

  /// Shown once the session reports a completed 360° pass. The top and the
  /// underside are the sides a single waist-high circle misses, which is
  /// what makes a finished scan look "imprecise".
  static const passCompleteHint =
      'All sides captured. Now aim down at the object from above, then tap '
      'Finish.';

  /// Names exactly what is left once Apple reports a completed pass, instead
  /// of asking for another lap. This is the difference between a scan that
  /// takes two minutes and one that takes five (user request 2026-09-18).
  static String stillToScanHint(String bands) =>
      'Nearly there — now capture $bands.';

  /// The verdict: every side is captured and nothing more is worth waiting
  /// for. Shown with the `buildNow` CTA so the user knows they may stop.
  static const enoughCoverageHint =
      'You have every side of the object. Build it now.';

  /// The Finish CTA once the scan is complete, so stopping reads as the
  /// obvious next step rather than a guess about whether to keep circling.
  static const buildNow = 'Build model now';
  /// Label for the captured-geometry review (Apple's point cloud).
  static const geometryPillLabel = 'Geometry';
  static const backToCamera = 'Back to camera';
  static const geometryHint =
      'Captured geometry — hollow patches are the sides still to scan.';

  // Coverage globe: "which sides are done?".

  /// Label for the coverage globe.
  static const coveragePillLabel = 'Coverage';
  static const coverageTitle = 'Scan coverage';
  static const coverageDragHint = 'Drag to turn the object';
  static const coverageLegendScanned = 'Scanned';
  static const coverageLegendMissing = 'Still to scan';
  static const coverageYouAreHere = 'You are here';
  static const coverageBandTop = 'Top';
  static const coverageBandSides = 'Sides';
  static const coverageBandBottom = 'Underside';

  /// Band names as they read inside a sentence.
  static const coverageNameTop = 'the top';
  static const coverageNameSides = 'the sides';
  static const coverageNameBottom = 'the underside';

  /// How much of the object has been scanned, by direction.
  static String coveragePercent(int percent) =>
      '$percent% of the object captured';

  /// The compact form shown under the viewfinder while capturing.
  static String coverageShort(int percent) => '$percent% scanned';

  /// Names the sides the user still has to walk to.
  static String coverageStillToScan(String bands) =>
      'Still to scan: $bands. Keep circling until the grey dots fill in.';

  static const coverageCompleteHint =
      'Every side is captured. Tap Finish to build the model.';
  static const coverageAlmostHint =
      'Good coverage. Tap Finish now, or keep circling for a sharper model.';
  static const coverageEmptyHint =
      'Walk around the object — the sides you cover fill in here.';

  /// Warns that the direction readout is unavailable, whichever part of it
  /// is missing, instead of showing a confident "0%" that would be a lie.
  static const coverageNoDirections =
      'This phone is not reporting which way it is pointing, so the globe '
      'cannot show where you have scanned from. A full circle — plus the top '
      'and the underside — still builds the model.';

  /// The 360° viewer's magnification readout.
  static String zoomLevel(double factor) => '${factor.toStringAsFixed(1)}×';

  /// Live count of frames the session has kept; quiet proof that scanning
  /// is actually happening while the user walks around.
  static String photosCaptured(int count) =>
      count == 1 ? '1 photo captured' : '$count photos captured';

  /// Accessibility label for the capture step indicator.
  static String captureStepLabel(int step) => 'Step $step of 3';

  // 360° model viewer.
  static const modelViewerHint =
      'Drag to rotate · pinch, or hold + / −, to zoom in on detail';
  static const resetView = 'Reset view';
  static const zoomIn = 'Zoom in';
  static const zoomOut = 'Zoom out';
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
