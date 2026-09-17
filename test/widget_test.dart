import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:forma/app.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/core/strings.dart';

import 'native_channel_mock.dart';
import 'scan_repository_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FormaApp renders the library and navigates to capture',
      (tester) async {
    mockFormaEventChannel();
    mockFormaMethods((call) async {
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

    semantics.dispose();
    clearFormaChannelMocks();
  });
}
