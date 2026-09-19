import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:forma/app.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/core/strings.dart';
import 'package:forma/features/capture/widgets/coverage_globe.dart';
import 'package:forma/features/capture/widgets/coverage_panel.dart';

import 'native_channel_mock.dart';
import 'scan_repository_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FormaApp renders the library and navigates to capture',
      (tester) async {    mockFormaEventChannel();
    final calls = <String>[];
    Map<Object?, Object?>? reviewArgs;
    Map<Object?, Object?>? torchArgs;
    Map<Object?, Object?>? profileArgs;
    mockFormaMethods((call) async {
      calls.add(call.method);
      if (call.method == 'setCaptureReviewMode') {
        reviewArgs = call.arguments as Map<Object?, Object?>?;
      }
      if (call.method == 'setTorch') {
        torchArgs = call.arguments as Map<Object?, Object?>?;
      }
      if (call.method == 'setScanProfile') {
        profileArgs = call.arguments as Map<Object?, Object?>?;
      }
      switch (call.method) {
        case 'isScanSupported':
          return true;
        case 'startCapture':
          return 'scan-test';
        default:
          return null;
      }
    });

    final repo = MemoryScanRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [scanRepositoryProvider.overrideWithValue(repo)],
        child: const FormaApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Library is the home screen.
    expect(find.text(Strings.libraryTitle), findsOneWidget);
    expect(find.text(Strings.emptyTitle), findsOneWidget);

    // Scan CTA navigates into the capture flow.
    await tester.tap(find.text(Strings.startScan));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The capture CTA is offered straight away — the native session decides
    // whether it can accept a capture, so the tap is never a dead end.
    expect(find.text(Strings.scanCta), findsOneWidget);

    // The flow is shown as steps, not just a phase: a scan is a loop around
    // the object, and the user needs to know where they are in it.
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel(Strings.captureStepLabel(1)), findsOneWidget);

    // The scan speed is chosen here, before the capture starts, because it is
    // the decision the user is actually making at that moment — "how long is
    // this going to take?" — and the honest answer to "why is scanning slow?"
    // is to let them trade detail for time up front (user request 2026-09-20).
    expect(find.text(Strings.profileQuickLabel), findsOneWidget);
    expect(find.text(Strings.profileBalancedLabel), findsOneWidget);
    expect(find.text(Strings.profileDetailLabel), findsOneWidget);
    await tester.tap(find.text(Strings.profileQuickLabel));
    await tester.pump();
    expect(profileArgs, {'profile': 'quick'});

    // Once the session is live, the guidance names the current step — and the
    // middle of the screen stays free for Object Capture's own AR guidance.
    await tester.runAsync(
      () => emitFormaEvent({'type': 'phase', 'value': 'detecting'}),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(Strings.detectingHint), findsOneWidget);

    // A tap shows that the request is in flight rather than appearing to do
    // nothing (device-test finding 2026-09-17: "button not responsive").
    await tester.tap(find.text(Strings.scanCta));
    await tester.pump();
    expect(find.text(Strings.gettingReady), findsOneWidget);

    // Once the session confirms it is capturing, the CTA becomes Finish.
    // (runAsync: the event helper awaits a real timer, which the test's
    // fake clock would otherwise never fire.)
    await tester.runAsync(
      () => emitFormaEvent({'type': 'phase', 'value': 'capturing'}),
    );
    await tester.pump();
    expect(find.text(Strings.finishCapture), findsOneWidget);
    expect(find.text(Strings.gettingReady), findsNothing);

    // Frames are landing: the speed is no longer a choice to make, and the
    // bottom of the screen belongs to the shutter.
    expect(find.text(Strings.profileQuickLabel), findsNothing);

    // The torch is a real control, not a placeholder: the button reaches
    // native and lights up, which is what makes it usable in a dim room
    // (user request 2026-09-18: turn on the flash feature).
    await tester.tap(find.bySemanticsLabel(Strings.torchLabel));
    await tester.pump();
    expect(torchArgs, {'enabled': true});
    expect(find.byIcon(Icons.flashlight_on), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(Strings.torchLabel));
    await tester.pump();
    expect(torchArgs, {'enabled': false});
    expect(find.byIcon(Icons.flashlight_off_outlined), findsOneWidget);

    // While capturing, the guidance states the coverage loop and the pointer
    // moves to step 2.
    expect(find.text(Strings.capturingHint), findsOneWidget);
    expect(find.bySemanticsLabel(Strings.captureStepLabel(2)), findsOneWidget);

    // Low light is reported instead of silently ignored — the session sends
    // this feedback, and dropping it left scans that never progressed with no
    // reason given.
    await tester.runAsync(
      () => emitFormaEvent(
        {'type': 'feedback', 'value': 'environmentLowLight'},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(Strings.lowLightHint), findsOneWidget);

    // Guidance must point the way the session actually needs. An object that
    // is too close means backing the camera away — these were inverted, so
    // the app told users to move closer when they needed to move back.
    // The hint pill crossfades, so each change needs a frame to apply and
    // another to let the outgoing hint finish animating out.
    await tester.runAsync(
      () => emitFormaEvent({'type': 'feedback', 'value': 'objectTooClose'}),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(Strings.moveFarther), findsOneWidget);
    expect(find.text(Strings.moveCloser), findsNothing);

    await tester.runAsync(
      () => emitFormaEvent({'type': 'feedback', 'value': 'objectTooFar'}),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(Strings.moveCloser), findsOneWidget);
    expect(find.text(Strings.moveFarther), findsNothing);

    // Coverage progress: the session reports the frames it has kept, which
    // is the user's proof that walking around is actually building a scan.
    await tester.runAsync(
      () => emitFormaEvent({'type': 'feedback', 'value': 'none'}),
    );
    await tester.runAsync(
      () => emitFormaEvent({
        'type': 'capture_progress',
        'value': {
          'shots': 42,
          'passComplete': false,
          'targetShots': 60,
          'maxShots': 120,
          'budgetReached': false,
        },
      }),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    // Against the profile's frame target, so "how much longer?" has an answer
    // from the first frame instead of a count that only ever grows.
    expect(find.text(Strings.shotsOfTarget(42, 60)), findsOneWidget);
    expect(find.text(Strings.capturingHint), findsOneWidget);

    // Once the session says a full pass is captured, asking for another lap
    // would waste the user's time — the guidance moves on to the sides a
    // single circle always misses.
    await tester.runAsync(
      () => emitFormaEvent({
        'type': 'capture_progress',
        'value': {'shots': 88, 'passComplete': true},
      }),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(Strings.passCompleteHint), findsOneWidget);
    expect(find.text(Strings.capturingHint), findsNothing);

    // Directions mark which sides of the object are done: the session reports
    // one per frame it keeps, and the share of the globe they cover is the
    // honest "how far along am I" number.
    await tester.runAsync(
      () => emitFormaEvent({
        'type': 'scan_direction',
        'value': {'x': 0.0, 'y': 1.0, 'z': 0.0, 'kept': true},
      }),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('scanned'), findsOneWidget);

    // The coverage globe opens purely locally — checking coverage must never
    // disturb a running capture.
    await tester.tap(find.text(Strings.coveragePillLabel));
    await tester.pump();
    expect(find.text(Strings.coverageTitle), findsOneWidget);
    expect(find.text(Strings.coverageBandTop), findsOneWidget);
    expect(find.text(Strings.coverageBandSides), findsOneWidget);
    expect(find.text(Strings.coverageBandBottom), findsOneWidget);
    expect(find.textContaining('of the object captured'), findsOneWidget);
    expect(find.byType(CoverageGlobe), findsOneWidget);
    // The sides still missing are named here, so the user knows where to walk.
    // Scoped to the panel because the live hint behind it names the same gap
    // (both read from one shared helper, which is the point). The underside is
    // deliberately absent from the advice: the user cannot walk to it, and
    // asking for it is what kept them circling a finished scan.
    expect(
      find.descendant(
        of: find.byType(CoveragePanel),
        matching: find.textContaining(Strings.coverageNameTop),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(CoveragePanel),
        matching: find.textContaining(Strings.coverageNameBottom),
      ),
      findsNothing,
    );

    // Closing it returns to the live feed.
    await tester.tap(find.bySemanticsLabel(Strings.backToCamera));
    await tester.pump();
    expect(find.text(Strings.coverageTitle), findsNothing);

    // The geometry check swaps the live feed for the captured point cloud:
    // holes in the geometry are the sides still missing, so the user stops
    // re-scanning sides that are already done.
    await tester.tap(find.text(Strings.geometryPillLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(Strings.geometryHint), findsOneWidget);
    expect(find.text(Strings.backToCamera), findsOneWidget);
    expect(calls, contains('setCaptureReviewMode'));
    expect(reviewArgs, {'enabled': true});

    // A failed capture must not trap the user on a dead camera: the error
    // layer replaces the live chrome, so it carries its own way back to the
    // library (user request 2026-09-18).
    await tester.runAsync(
      () => emitFormaEvent({
        'type': 'error',
        'value': {'code': 1007, 'message': 'insufficientStorage'},
      }),
    );
    await tester.pump();
    expect(find.text(Strings.storageFull), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    semantics.dispose();
    clearFormaChannelMocks();
  });
}
