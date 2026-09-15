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

## Platform Bridge Contract (architecture.md §3)
- MethodChannel `com.forma.app/native`: isScanSupported, hasLiDAR,
  startCapture→scanId, beginCapturing, finishCapture, cancelCapture,
  startReconstruction, exportModel{scanId,format}.
- EventChannel `com.forma.app/capture_events`: payloads `{"type": …,
  "value": …}` — phase / feedback / reconstruction_progress /
  reconstruction_complete / error{code,message}.
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
