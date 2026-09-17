# Forma — Project Memory

> Single source of truth for AI agents and engineers. Read this first.
> Full product spec: `MASTER_PROMPT.md` at repo root.

## What We're Building
Forma is a Flutter iOS app that turns photos into 3D models using Apple's
Object Capture and PhotogrammetrySession frameworks, accessed through a
platform-channel bridge to a Swift NativeModule. One-time purchase, no
subscriptions, 100% on-device. Built on a Windows machine; iOS builds happen
in CI (GitHub Actions public repo). Test device: iPhone 16 Pro Max (LiDAR).

## Non-Negotiables
- No subscriptions. Ever.
- 100% on-device. No cloud for v1.0.
- LiDAR-only for scanning. Gate everything behind a support check. Do not fake it.
- **No fakes**: single real `IosNativeBridge` in runtime; honest unsupported
  screen anywhere the native module/hardware is absent. Test doubles live in
  `test/` only (channel-messenger mocks, in-memory repo).
- Dark mode first, light mode equally loved.
- Accessibility is not optional.
- Every animation uses a `Motion` token; every state change has a haptic.

## Key Decisions Log
| Date | Decision | Reason |
|------|----------|--------|
| 2026-09 | Flutter for UI, Swift for native capture | No local Mac; cross-platform future |
| 2026-09 | Riverpod for state management | Testable, no BuildContext in logic |
| 2026-09 | Drift (SQLite) over Isar for local DB | Isar 3.x has compatibility risk on Dart 3.13; docs allowed either |
| 2026-09 | freezed for domain models | Immutability + copyWith per rules.md |
| 2026-09 | very_good_analysis (not flutter_lints) | Strict per rules.md §1 |
| 2026-09-14 | **FakeNativeBridge deleted; single real bridge** | User directive — nothing fake in runtime |
| 2026-09-14 | Tests mock channels at binary-messenger level | Tests the REAL bridge code path; no fake classes in lib/ |
| 2026-09-14 | One event channel `capture_events`, not two | `type` field discriminates payloads; simpler wiring |
| 2026-09-14 | IPA via CI unsigned artifact + Sideloadly (own Apple ID) | No $99 dev program yet; 7-day resign accepted; revisit for TestFlight |
| 2026-09-14 | vphone-cli REJECTED as emulator | Needs Apple Silicon macOS 15+ host + SIP/AMFI relaxation; GH runners nested; no LiDAR/camera in guest |
| 2026-09-14 | windows/ platform folder added | Local dev/hot-reload on the Windows workstation (VS Build Tools present) |
| 2026-09-14 | Native module = classic FlutterPlugin via `registrar(forPlugin:)` | Stable API across Flutter 3.x incl. implicit-engine AppDelegate |

## Environment Gotchas (discovered — do not re-learn these)
0. **`ObjectCaptureSession.stateUpdates` / `feedbackUpdates` can deliver
   NOTHING on device while the session is alive and healthy** (iOS 27).
   Symptom: session created, reaches `.ready`, `startDetecting()` never
   runs, every `startCapturing()` is refused with "not ready" forever.
   Never drive a state machine solely from those sequences — poll the
   `state` property (a cheap property read) and treat the stream as a fast
   path. Log every transition so this is visible in the device log.
1. **drift + build_runner AOT silently fails on the `int()` column alias.**
   A table using `IntColumn get x => int()();` generates an EMPTY database
   (no error!). Use `integer()()` instead.
2. **freezed 4 requires `abstract`/`sealed` on annotated classes**, and the
   factory must be named: `const factory Scan({...}) = _Scan;`.
3. **PowerShell Set-Content writes UTF-8 BOM** and can mangle em-dashes.
   Prefer dedicated file tools or `[IO.File]::WriteAllText` with
   `UTF8Encoding($false)`.
4. **`dart fix --apply` rewrites constructors to `new(...)` syntax** —
   disabled lint; revert if seen.
5. **`dart:math` has no `tau`** — use `2 * math.pi`.
6. **`Icons.viewfinder` doesn't exist** — use `Icons.filter_center_focus`.
7. **DateTime has no const constructor.**
8. **Broadcast streams in tests**: attach listeners BEFORE the event fires.
9. **`flutter build windows` requires Developer Mode** (symlinks). Enabled
   via HKLM AppModelUnlock\AllowDevelopmentWithoutDevLicense=1 (UAC).
10. **EventChannel emission in tests**: `handlePlatformMessage` on the
    channel name + `encodeSuccessEnvelope` + `Duration.zero` pump.
11. **very_good_analysis**: `discarded_futures` fires on fire-and-forget
    notifier calls in widgets — wrap in `unawaited()` (import dart:async).
12. **macos-14 runner = Xcode 15.4 / iOS 17.5 SDK.** `ObjectCaptureSession`
    is NOT in RealityKit's main swiftinterface — it lives in the
    `_RealityKit_SwiftUI` overlay: `import SwiftUI` + `import RealityKit`
    (both required). The class is `@MainActor`.
13. **Verified PhotogrammetrySession API** (Apple docs, iOS 17+):
    `init(input: URL, configuration: .init())` (input is the images
    directory URL — no `.images` case), `Request(modelFile: outputURL)`,
    `Result.modelFile(URL)`, `Output` has `.processingCancelled` (NOT
    `.invalidated`), `.requestProgress(_, fractionComplete:)`.
14. **ObjectCaptureSession state machine**: `start()` → `.ready` →
    `startDetecting()` → `.detecting` → `startCapturing()` → `.capturing`
    → `finish()` → `.completed`. `feedback` is a `Set<Feedback>` (map to
    one value by priority). Added `beginCapturing` to the bridge contract
    for the explicit `startCapturing()` step.
15. **ObjectCaptureSession `stateUpdates`/`feedbackUpdates` are
    single-consumer streams.** Iterating them in two places splits events.
    CaptureService owns the only iterations and forwards via
    ScanViewportController; the preview platform view only renders.
16. **ObjectCaptureView lives in SwiftUI/RealityKit** — host it via
    UIHostingController inside a FlutterPlatformView; `import SwiftUI` +
    `import RealityKit` both required (see gotcha 12).
17. **`UIHostingController` is NOT retained by its own `view`.** Creating
    one inside a platform-view init and letting it go out of scope leaves
    the SwiftUI content permanently inert — a black preview even while
    `ObjectCaptureSession` feeds frames (`processVideoData()` at 30 Hz in
    the device log). Store it on the platform view, size the hosted view
    in `layoutSubviews` (a zero-height host renders nothing), and kick
    `beginAppearanceTransition` from `didMoveToWindow`.
18. **EventChannel sinks drop events emitted before Dart listens.**
    `onListen` is a separate platform message: anything the session emits
    before it lands goes to a nil sink. Native streams that are
    single-consumer and iterated once (ObjectCaptureSession's
    `stateUpdates`) cannot replay themselves — re-emit current state from
    `onListen`, and never gate an action on a mirrored phase on the Dart
    side.
19. **`flutter build ios` bakes `--dart-define` values in, and the CI
    artifact name is free text.** Name every IPA for its version and stamp
    the version into the UI (`--dart-define=FORMA_BUILD`), because
    Sideloadly happily reinstalls a stale `.ipa` from the previous run
    (2026-09-17: the phone was repeatedly tested against build 1 while the
    fixes sat in CI).
20. **A view whose session is gone is worse than no view.** RealityKit
    draws its own *"Cannot make a view for a deinitialized
    ObjectCaptureSession"* over the black feed. Bind the preview BEFORE
    `session.start(…)` (Apple's sample installs the view first, otherwise
    the view never attaches to the live feed), track EVERY mounted preview
    rather than only the newest, unbind all of them before a session is
    released and when it reaches `.completed`/`.failed`, and keep the bound
    session stored on the renderer so it cannot be deallocated behind the
    view.
21. **Feedback names describe the scene, not the action.**
    `.objectTooClose` needs the camera moved AWAY; `.objectTooFar` needs it
    moved closer. The first mapping was inverted, so the app told the user
    to do the opposite of what Object Capture wanted.
23. **Real async file I/O never completes inside `flutter_test`.** The test
    body runs in a fake-async zone, so `Directory.createTemp()` (and any
    other real `await` on the filesystem) hangs the test until the runner
    kills it — reported only as "did not complete", with no error. Use the
    synchronous forms (`createTempSync`, `deleteSync`) or wrap the work in
    `tester.runAsync`.
22. **`ObjectCaptureSession.Error` cases are not all public**, so match
    `String(describing:)` (it does name them: "Error.trackingFailed",
    "Error.insufficientStorage(requiredBytes: …)"). Give every case its own
    wire code and its own user-facing message — collapsing them into one
    "Something went wrong" hides the cause from the user and from anyone
    reading a screenshot.
24. **Two UIKit gesture recognizers on the same view cannot both recognise**
    unless a delegate allows it. A one-finger pan (default
    `maximumNumberOfTouches` = unlimited) and a two-finger pinch on the same
    view means the pan claims the sequence and UIKit refuses to let the
    pinch begin — the model orbits but never zooms, with no error anywhere.
    Fix: `pan.maximumNumberOfTouches = 1` so a second finger makes the pan
    fail, plus `UIGestureRecognizerDelegate`
    `shouldRecognizeSimultaneouslyWith → true` so an orbit can turn into a
    pinch without lifting a finger.
25. **`debugDefaultTargetPlatformOverride` must be reset inside the test
    body.** The binding asserts that no foundation debug variable was left
    changed *before* `addTearDown` callbacks run, so resetting it in a
    teardown fails the test with "The value of a foundation debug variable
    was changed by the test".
26. **Object Capture exposes coverage, and we should use it.**
    `session.userCompletedScanPass` flips true when a full circle has been
    captured (Apple's own "every side is covered" milestone);
    `numberOfShotsTaken` is the frames kept; `ObjectCapturePointCloudView`
    renders the live captured geometry (with `showShotLocations()` — iOS 18+
    — marking where shots were taken); `isAutoCaptureEnabled` and
    `shouldPlayHaptics` are settable on iOS 18+. Deployment target is 17.0,
    so every iOS 18 API needs an `if #available` guard. There is **no**
    numeric coverage percentage — never invent one.

## Platform Bridge Contract (architecture.md §3)
- MethodChannel `com.forma.app/native`: isScanSupported, hasLiDAR,
  startCapture→scanId, beginCapturing, finishCapture, cancelCapture,
  startReconstruction, exportModel{scanId,format},
  hasActiveCaptureSession→bool, getSessionState→phase name,
  resetModelView, zoomModelView{scale}, setCaptureReviewMode{enabled}.
- EventChannel `com.forma.app/capture_events`: payloads `{"type": …,
  "value": …}` — phase / feedback / capture_progress{shots,passComplete} /
  reconstruction_progress / reconstruction_complete / error{code,message}.
- Swift errors → FlutterError(code:) UNSUPPORTED/CAPTURE/RECONSTRUCT/
  EXPORT/STORE → Dart FormaError subclasses in `_mapError`.
- `MissingPluginException` → `UnsupportedDeviceError` (honest non-iOS path).

## Current Sprint
Phase 1 — COMPLETE (2026-09-14): CI fully green on main
(lucifer2711-1/forma). Linux: analyze + 24 tests. macOS (Xcode 15.4,
iOS 17.5 SDK): Swift NativeModule compiles, unsigned app builds,
`forma-unsigned-ipa` artifact packaged (Sideloadly-ready).
Remaining for Phase 1 exit: install on iPhone 16 Pro Max via
Sideloadly → verify `isScanSupported` == true → capture session opens.
Then Phase 2: capture screen with ObjectCaptureView platform view.

## Open Questions
- [ ] apple_spatial_capture vs custom Swift module → kept custom; revisit if
      capture UX disappoints on device
- [ ] Pricing $9.99 vs $14.99 → after beta
- [ ] PhotogrammetrySession OBJ output availability on iOS 18+ → Phase 4
- [ ] Apple Developer Program purchase (unlocks TestFlight path) → when
      Sideloadly 7-day cadence becomes painful

## For AI Agents
1. Read `rules.md` before writing code; `MASTER_PROMPT.md` for product spec.
2. Never introduce a subscription, a cloud dependency, or a fake/simulated
   capture path.
3. Every widget needs light+dark coverage; use `FormaColors.of(context)`.
4. Every animation references `Motion.*`. Every state change: `AppHaptics`.
5. Update the Decisions Log when making architectural choices.

## Session Log
| Session | Date | What was done | What's next |
|---------|------|---------------|-------------|
| 1 | 2026-09-13 | Phase 0: scaffolding, tokens, components, drift schema, library UI, CI files | Phase 1 |
| 2 | 2026-09-14 | Phase 1: real IosNativeBridge only, Swift NativeModule (8 files), Info.plist camera, pbxproj registration, unsupported screen, capture screen, windows target + smoke-run, MASTER_PROMPT.md | Commit, GitHub, CI macOS build, device test |
| 3 | 2026-09-14 | GitHub repo created (public), CI green: 24 tests (Linux) + unsigned IPA (macOS, Sideloadly-ready artifact). API verified via Apple docs + SDK probe. beginCapturing added to bridge contract | Sideloadly device install on iPhone 16 Pro Max; then Phase 2 |
| 4 | 2026-09-15 | First device test findings: blank capture screen (no camera preview), silent ~25% reconstruction failures, stale VM state after a finished scan. Shipped Phase 1.5: native ObjectCaptureView platform view (ScanViewportController + CapturePreviewView), capture VM reset + honest errors, os_log diagnostics (CameraDebugLogger), hasActiveCaptureSession probe | Rebuild IPA in CI → device retest: camera visible, guidance pill live, failure reason visible in logs |
| 5 | 2026-09-15 | Retest of 1.5 build: ALL capture-screen buttons dead (overlay was wrapped in IgnorePointer — only library FAB worked) + preview still black. Fixes: IgnorePointer removed (error layer now separate opaque branch), hosted view sized from Flutter frame + autoresizing, UIHostingController appearance lifecycle kicked manually, camera-authorization os_log. CI Swift-fix loop (3 runs) → green | Sideloadly update install → retest buttons + camera |
| 6 | 2026-09-16 | Camera-health hardening: `hasActiveCaptureSession` added to NativeBridge contract + IosNativeBridge; CaptureViewModel watchdog (8s, injectable) probes session on silence → honest camera-dead error + CameraHealthOverlay (starting/dead states); UnknownError for unmapped PlatformException codes; ScanCard async image loading; ExportService relaunch-safe via canonical model path fallback; strings centralized; mojibake/BOM cleaned; 27 tests green | Rebuild IPA in CI → device retest |
| 7 | 2026-09-16 | Screenshot-diagnosed root causes of black feed: (1) camera permission never requested → ObjectCaptureSession wedged in .initializing; now requestAccess(for: .video) before start(), denial = native 1005 → new CameraPermissionError; (2) method-channel replies dropped off-main → all handlers reply via respond() marshaling to DispatchQueue.main; (3) hasActiveSession probe blind to wedged sessions → initializing ≠ alive; hint pill no longer overlaps Starting-camera scrim; 29 tests green | Rebuild IPA in CI → device retest: expect permission prompt on first launch, live feed + point-cloud build once capturing |
| 8 | 2026-09-16 | Update-install retest: still "Starting camera…" + crash on Start tap. Hardened: start() re-entrancy guard (permission dialog blocks startCapture; double-tap stacked a second native session) + 20s start-timeout → CameraTimeoutError (never hangs forever); Swift start() now replaces any previous session instead of stacking; beginCapturing/finish state guards (startCapturing on a non-detecting session traps the app = the crash); version 1.0.0+2 for install verification; 31 tests green | Reinstall +2 IPA → retest. If still stuck, capture os_log from Console.app (CameraDebugLogger) |
| 9 | 2026-09-17 | Pulled device crash reports + live syslog over USB (pymobiledevice3 on Windows). All 4 crashes = EXC_BREAKPOINT in RealityKit DataModel.startCapturing() — Apple traps when session ≠ .detecting (+1 build, pre-guard). Live log on +2: guard rejected beginCapturing, no crash. **True root cause of black feed: device free space 3.43 GB < Apple's 4 GB hard requirement → session fails instantly with insufficientStorage.** Now: 1007 → StorageFullError with "free 4 GB" message via error event; failed-phase won't overwrite specific errors; 33 tests green | User frees ≥4 GB → retest; expect camera live + point cloud; storage message if under |
| 14 | 2026-09-17 | Recorded the device log during a real capture attempt. **Definitive finding: `beginCapturing rejected in state ready` x30, and our `capture state →` handler logged ZERO transitions across six sessions — `ObjectCaptureSession.stateUpdates` delivered nothing, so `startDetecting()` was never called and the session sat in `.ready` forever.** Fix: the state machine is now driven by polling the session's `state` property (200 ms, cheap main-actor read), which also nudges `startDetecting()` every second while the session waits in `.ready`; the stream is still consumed (before `start()` now) as a fast path, and `handle(_:)` is idempotent so both can feed it. Also logged in the same window: `Feedback.environmentLowLight`, `Tracking.Reason.initializing`, and `No depth map/point cloud is available in ARFrame` — the test device was in a dark room at 3 AM, and Object Capture needs light. 38 tests green; build +9 | Reinstall +9 → capture in GOOD light; the session should reach detecting and capture should start |
| 13 | 2026-09-17 | Retest on +7: camera feed live, but **Start Capture did nothing at all**. Root cause was ours, twice over: (1) `FormaEventSink` emitted the session's startup phases (`.ready`/`.detecting`) before Dart's event-channel `listen` reached the platform — those went into a nil sink and were lost forever (`stateUpdates` is single-consumer), leaving Dart's `phase` null while native was already `.detecting`; (2) the Dart gate added in +7 trusted that mirrored phase, so every tap queued into silence. Fixes: `FormaEventSink.onListenHandler` replays the session's current phase on (re)subscribe; the capture request now goes to native (the only authority, and the guard that prevents Apple's trap) instead of being gated on a mirrored phase; native "not ready" (1006) is retried ~2 s while the CTA shows "Getting ready…"; the watchdog **adopts** the probed phase so a missed event can never leave the UI stale. 38 tests green; build +8 | Reinstall +8 → camera → tap Start Capture; expect capture (or an honest reason) instead of a dead button |
| 12 | 2026-09-17 | Retest on +6 (the preview fix worked — camera feed now visible). Tapping "Start Capture" too early showed a bare **"Capture failed."** because Object Capture only accepts `startCapturing()` from `.detecting`, and the CTA was offered during `.initializing`/`.ready`. The native guard was right; the app was wrong to offer the tap. Now: capture requests made too early are **queued and fired on the `.detecting` phase event** (+ one retry if native still says 1006); new `CaptureNotReadyError` (code 1006) replaces the generic capture failure; the CTA renders disabled as "Getting ready…" until the session can accept capture. 36 tests green; build +7 | Reinstall +7 → tap Start Capture whenever; expect it to wait for readiness instead of failing |
| 11 | 2026-09-17 | Read the device's installed-app record over USB: the phone was running **build 1 with the iOS 17.5 SDK** — the original IPA, none of the fixes. Every "still stuck at Starting camera / all black" retest had been against that build. Also fixed a genuine black-preview bug: `CapturePreviewRendererImpl` was created and dropped inside the platform-view init, so nothing retained the `UIHostingController` (gotcha 17) → SwiftUI content could never render even with a live session. Renderer now held strongly, hosted view sized in `layoutSubviews`, lifecycle kicked from `didMoveToWindow`. CI stamps the build (`--dart-define=FORMA_BUILD`, shown in the library app bar as `v1.0.0+6`) and names every IPA/artifact for its version. 34 tests green; build +6 | Delete the old app, install the **+6** IPA, confirm `v1.0.0+6` in the app bar, then retest capture in good light |
| 10 | 2026-09-17 | Retest on +3 with 10 GB free: still "Starting camera…", NO crashes. Live log (11 s window before iOS 27-beta syslog stream died): CoreOC frames flowing at ~30 Hz (processVideoData 0.14 ms) but "Camera tracking is not normal!" forever → session parked in .initializing, no .ready phase. Fixes: getSessionState() contract + Swift handler; watchdog distinguishes initializing (→ tracking-guidance overlay "well-lit textured surface", NOT an error — old probe falsely blamed permission) from none/failed (→ camera-dead); per-transition os_log; phaseName internal; 34 tests green; build +4 | Reinstall +4 → retest in GOOD LIGHT, textured surface. If still initializing: likely iOS 27 beta ARKit issue → retest on iOS 26.x |
| 17 | 2026-09-18 | Retest: **capture and reconstruction now both work** — "model is created in the app". Two gaps remained, both real: (a) **there was no model viewer at all** (the library tiles had no `onTap`, and no viewer screen existed), so the finished model was unviewable; (b) capture guidance was thin and the app's hint pill sat *centred on top of Object Capture's own AR guidance* (bounding box, walk-around arrows, coverage ring), hiding exactly what a full-coverage scan needs, while the `environmentLowLight` feedback the session sends was dropped entirely. Added a native 360° viewer (`ModelPreviewView.swift`: RealityKit `ARView` in `.nonAR` with `enableCameraControls` for orbit/zoom, three directional lights, model centred and framed from its own bounds, honest on-screen failure text) + `resetModelView` channel + hub, registered in `pbxproj`; a Dart viewer screen that checks the file first and says so when it is missing, reached from the library grid **and automatically right after a scan finishes**; capture guidance moved under the top bar so the centre stays Apple's, a 3-step indicator (aim → walk → build), and the full feedback set mapped (low light, object-not-detected) with unmapped feedback now logged instead of swallowed. 46 tests green; build +12 | Install +12 → confirm `v1.0.0+12`, scan in good light walking a full circle, then inspect the model from every side in the viewer |
| 16 | 2026-09-18 | Next retest showed our error layer with the generic "Something went wrong. Please try again." — the real reason was being flattened on both paths (`_messageFor` mapped only 1005/1007; a `.failed` phase with no prior error also fell back to it). Native now maps each `ObjectCaptureSession.Error` to its own code (1007 storage, 1008 image limit, 1009 sensor, 1010 tracking, else 1001) by matching the description, Dart gives every code its own honest message, and a request against a dead session (1002/1004) surfaces `ScanSessionEndedError` instead of the bare "Capture failed." A failing scan now names its cause on screen, so no USB cable is needed to diagnose it (gotcha 22). 43 tests green; build +11 | Install +11, confirm `v1.0.0+11`, retry a scan — the error text now names the cause (tracking lost / camera sensor / storage / model build). Report that text, or plug the phone in for the full device log |
| 18 | 2026-09-18 | Retest: viewer orbits but **pinch-to-zoom did nothing** (gotcha 24: pan + pinch on one view cannot both recognise, so the pan claimed every two-finger sequence), and a scan still looked imprecise because nothing told the user which sides were captured. Fixes: pan limited to one finger + simultaneous-recognition delegate, plus on-screen +/− zoom that does not depend on a gesture being delivered; the capture screen now polls `userCompletedScanPass` + `numberOfShotsTaken` and shows a live photo count, switches the guidance from "walk a full circle" to "now capture the top" once Apple reports the pass complete, and offers a **Check coverage** button that swaps the preview for Apple's live `ObjectCapturePointCloudView` (shot locations on iOS 18+) so holes in the geometry show exactly which sides are missing; auto-capture + session haptics enabled on iOS 18. 50 tests green; build +13 | Install +13 → confirm `v1.0.0+13`; in a scan tap Check coverage mid-walk to see unscanned sides, then retest pinch **and** the +/− zoom in the viewer |
| 15 | 2026-09-18 | Device screenshot showed Apple's own "Cannot make a view for a deinitialized ObjectCaptureSession" drawn over an all-black feed, with no CTA and a stale feedback hint — a preview bound to a session that was already gone. Six defects fixed from that evidence: (a) the `ObjectCaptureView` platform view was bound *after* `session.start(…)`; Apple's own sample installs the view first, so the view never attached to the live feed → bind before start; (b) `ScanViewportController` tracked only the newest preview, so a session swap left older mounted previews rendering a released session → registry of live previews, all bound/unbound together, registry pruned on platform-view dispose, and the renderer holds its bound session strongly; (c) the preview was never unbound at `.completed`/`.failed` → terminal phases blank it; (d) guidance was INVERTED — `objectTooClose` told the user to move closer and `objectTooFar` to move farther, so the app fought the session's own guidance (gotcha 21); (e) a `.completed` session the app had not driven dead-ended with no CTA and no reconstruction → completion now hands the scan to reconstruction exactly once, including when only the watchdog probe sees it; (f) the camera-dead probe overwrote a specific reason (storage/permission) with the generic camera error. 41 tests green; build +10 | Install +10, confirm `v1.0.0+10`, scan in good light. If the feed is still black, pull the device log — transitions, preview binds and unbinds are all logged |
