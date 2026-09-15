# FORMA — MASTER PROMPT

> Single source of truth. Paste at the start of every AI coding session.
> Reference specific Parts when asking for code: "Using Part 8.4, write the ScanCaptureScreen widget."
> When the AI drifts: "Re-read Part 11. You violated rule 5."
> Update this file when a decision changes.

## PART 1 — PROJECT IDENTITY

- **App name:** Forma
- **Tagline:** Turn anything into 3D. Right from your iPhone.
- **Bundle ID:** com.forma.app
- **Platform:** iOS 17.0+ (iPhone Pro / iPad Pro with LiDAR only)
- **Framework:** Flutter 3.x + native Swift module via Platform Channels
- **Backend:** None. 100% on-device.
- **Monetization:** One-time IAP ($14.99, launch promo $9.99). No subscriptions. No ads. No cloud.
- **Target user:** Makers, 3D-printing hobbyists, AR developers, curious power users.
- **Developer setup:** Windows/Linux machine (no Mac), GitHub Student Pack, GitHub Actions for CI/CD.

## PART 2 — THE HARD CONSTRAINT (READ FIRST)

This app is only fully functional on devices with an Apple LiDAR sensor.

**Supported devices (LiDAR):**
- iPhone 12 Pro, 12 Pro Max
- iPhone 13 Pro, 13 Pro Max
- iPhone 14 Pro, 14 Pro Max
- iPhone 15 Pro, 15 Pro Max
- iPhone 16 Pro, 16 Pro Max
- iPad Pro (2020 and later)

**Unsupported (must show a graceful explainer screen, never a broken scan flow):**
- iPhone 12/13/14/15/16 (standard & Plus)
- iPhone SE (all)
- All non-Pro iPads
- Any iPhone < 12

**Why:** Apple's ObjectCaptureSession and PhotogrammetrySession require LiDAR for depth tracking, scale estimation, and camera pose. PhotogrammetrySession.isSupported returns false on non-LiDAR devices. There is no software workaround on-device.

**App Store risk:** Apple has rejected apps for not messaging this limitation clearly. The unsupported-device screen and the App Store review notes must be crystal clear. This is non-negotiable.

## PART 3 — TECH STACK (FINAL)

| Layer | Technology | Why |
|---|---|---|
| UI | Flutter 3.x (Dart 3) | Cross-platform future, no Mac required for dev |
| State | Riverpod (flutter_riverpod + riverpod_annotation) | Testable, no BuildContext coupling |
| Immutable models | freezed + json_serializable | Zero-boilerplate value types |
| Local DB | Isar or Drift (SQLite) | Fast, Flutter-native |
| File storage | path_provider | Documents dir for scans |
| Native bridge | Platform Channels (MethodChannel + EventChannel) | Only way to reach Apple frameworks |
| Native language | Swift 5.10+ | RealityKit, ARKit, ModelIO, StoreKit 2 |
| 3D viewer | Platform view wrapping RealityKit (preferred) OR o3d package (fallback) | RealityKit is faster and Apple-native |
| Haptics | HapticFeedback (Flutter) + native UIImpactFeedbackGenerator for nuanced cases | |
| Localization | flutter_localizations + ARB files | en, es, fr, de, ja, ko, zh-Hans |
| Lint | flutter_lints + very_good_analysis | |
| CI/CD | GitHub Actions (macOS runners, student-pack boosted) | Free |
| Signing | GitHub Secrets + apple-actions/import-codesign-certs | No Mac needed |

**Rejected alternatives:**
- SwiftUI-only — user has no Mac, wanted Flutter
- Cloud photogrammetry — breaks "pay once" model
- Non-LiDAR devices — impossible on-device
- Subscription pricing — kills the differentiator

## PART 4 — NATIVE BRIDGE CONTRACT (MOST IMPORTANT PART)

Flutter cannot call ObjectCaptureSession or PhotogrammetrySession directly. You MUST build a Swift native module and bridge it.

### 4.1 Channel Names

```
MethodChannel: com.forma.app/native
EventChannel:  com.forma.app/capture_events
EventChannel:  com.forma.app/reconstruction_events
```

### 4.2 MethodChannel API (Dart → Swift)

| Method | Args | Returns | Notes |
|---|---|---|---|
| isScanSupported | none | bool | PhotogrammetrySession.isSupported |
| hasLiDAR | none | bool | ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) |
| startCapture | none | void → scanId | Begins ObjectCaptureSession |
| finishCapture | scanId | void | Ends session, writes images to disk |
| cancelCapture | scanId | void | Cancels and cleans up |
| startReconstruction | scanId | void | Kicks off PhotogrammetrySession |
| cancelReconstruction | scanId | void | |
| exportModel | scanId, format | String fileUrl | format ∈ usdz, obj, stl |
| getModelInfo | scanId | Map | vertices, triangles, bytes, textures |
| openARQuickLook | fileUrl | void | Presents QLPreviewController |
| purchasePro | none | Map | StoreKit 2 purchase result |
| restorePurchases | none | Map | |
| getEntitlement | none | bool | Current Pro state |
| setTorch | bool | void | Torch toggle on capture screen |

### 4.3 EventChannel Payloads (Swift → Dart)

capture_events:

```json
{ "type": "stateUpdate", "value": "initializing|ready|detecting|capturing|finishing|completed|failed" }
{ "type": "feedbackUpdate", "value": "objectTooClose|objectTooFar|movingTooFast|outOfFieldOfView|none" }
{ "type": "captureProgress", "value": 0.0 }
{ "type": "error", "code": 1001, "message": "Session failed to start" }
```

reconstruction_events:

```json
{ "type": "progress", "scanId": "uuid", "value": 0.47 }
{ "type": "inputComplete", "scanId": "uuid" }
{ "type": "completed", "scanId": "uuid", "modelUrl": "file:///..." }
{ "type": "error", "scanId": "uuid", "code": 2003, "message": "Insufficient images" }
```

### 4.4 Native Swift Module Files

```
ios/Runner/NativeModule/
├── FormaChannelHandler.swift      // Registers channels, routes methods/events
├── CapabilityChecker.swift        // isSupported, hasLiDAR
├── CaptureService.swift           // Wraps ObjectCaptureSession
├── ReconstructionService.swift    // Wraps PhotogrammetrySession
├── ExportService.swift            // MDLAsset → USDZ / OBJ / STL
├── StoreService.swift             // StoreKit 2 wrapper
├── ARQuickLookPresenter.swift     // QLPreviewController presentation
└── FormaError.swift               // Error enum with numeric codes
```

### 4.5 Flutter Bridge Files

```
lib/platform/native_bridge/
├── native_bridge.dart             // Dart-facing API
├── native_events.dart             // Typed stream wrappers
├── native_exceptions.dart         // Maps PlatformException codes → FormaError
└── models/
    ├── capture_state.dart
    ├── capture_feedback.dart
    └── model_info.dart
```

**Rules for the bridge:**
- All native errors must map to numeric codes documented in FormaError.swift.
- Never surface raw PlatformException to UI — always translate to FormaError.
- All EventChannel streams must be cancellable and cleaned up in dispose().
- Test the bridge end-to-end on a real LiDAR device before building any Flutter UI on top of it.

## PART 5 — FLUTTER ARCHITECTURE

### 5.1 Folder Structure

```
lib/
├── main.dart
├── app.dart                          // MaterialApp + theme + routing
├── core/
│   ├── models/                       // Scan, ExportRecord, ModelInfo
│   ├── services/                     // Repository interfaces
│   ├── repositories/                 // Isar-backed implementations
│   ├── errors/                       // FormaError hierarchy
│   └── logging/                      // Structured logger
├── features/
│   ├── onboarding/
│   ├── library/
│   ├── capture/
│   ├── reconstruction/
│   ├── model_detail/
│   ├── export/
│   ├── paywall/
│   ├── settings/
│   └── unsupported_device/
├── design_system/
│   ├── tokens/                       // colors.dart, type.dart, spacing.dart, radii.dart
│   ├── motion/                       // motion.dart, curves.dart
│   ├── haptics/                      // haptics.dart
│   └── components/                   // PrimaryButton, ScanCard, ProgressRing, etc.
├── platform/
│   └── native_bridge/                // (see 4.5)
└── l10n/                             // ARB files
```

### 5.2 State Management Rules

- Providers for services (bridge, repositories, store).
- AsyncNotifierProvider for view models.
- StreamProvider for EventChannel streams.
- View models must NOT import BuildContext. Ever.
- Every notifier has build() returning AsyncValue<State>.
- Dispose all stream subscriptions in ref.onDispose.

### 5.3 Routing

- Use go_router.
- Routes: /onboarding, /library, /capture, /reconstruct/:scanId, /model/:scanId, /paywall, /settings, /unsupported.
- Shell route for the app chrome; nested routes for modal flows.
- Deep links: forma://model/{id}.

### 5.4 Persistence

Isar collection Scan:

```dart
class Scan {
  Id id;
  String name;
  DateTime createdAt;
  DateTime updatedAt;
  Uint8List? thumbnailBytes;
  String modelPath;
  String? sourceImagesPath;
  ScanStatus status;   // draft, processing, ready, failed
  int bytes;
  bool isFavorite;
  List<String> tags;
}
```

Files live under Documents/Scans/{uuid}/ with Images/, Model.usdz, thumbnail.jpg.

## PART 6 — DESIGN SYSTEM

### 6.1 Design Philosophy (Non-Negotiable)

- Content is the hero; chrome recedes.
- Motion has meaning — never decorative.
- Depth via materials, not shadows.
- Haptics tell the story — every state change has one.
- Dark mode is designed first, light mode second.
- Every screen passes the "Would Apple ship this?" test.

### 6.2 Color Tokens (define in design_system/tokens/colors.dart)

| Token | Light | Dark |
|---|---|---|
| bg | #FAFAF7 | #0B0B0D |
| bgElevated | #FFFFFF | #16161A |
| bgSunken | #F0F0EC | #050506 |
| textPrimary | #0A0A0A | #F5F5F7 |
| textSecondary | #6B6B70 | #9A9AA1 |
| textTertiary | #A0A0A6 | #5F5F66 |
| accent | #FF6B35 | #FF7A45 |
| accentSoft | #FFE7DC | #3A1F13 |
| success | #34C759 | #30D158 |
| warning | #FF9F0A | #FFD60A |
| danger | #FF3B30 | #FF453A |
| separator | #E5E5EA | #2C2C2E |

**Accent rationale:** warm orange = creation, energy. Differentiates from Polycam (blue) and Apple system blue.

### 6.3 Typography

Use SF Pro (system default on iOS via Flutter). Rounded variant for display text.

| Style | Size / Weight | Tracking |
|---|---|---|
| Display L | 40 / Bold Rounded | -1.0 |
| Display M | 32 / Semibold Rounded | -0.5 |
| Title | 24 / Semibold | -0.3 |
| Headline | 17 / Semibold | -0.2 |
| Body | 17 / Regular | -0.2 |
| Callout | 16 / Regular | -0.2 |
| Subhead | 15 / Regular | -0.1 |
| Footnote | 13 / Regular | 0 |
| Caption | 12 / Regular | 0 |

**Dynamic Type:** all text uses MediaQuery.textScalerOf(context) scaling. Test at AX5.

### 6.4 Spacing

4pt grid: 4, 8, 12, 16, 20, 24, 32, 40, 48, 64.

### 6.5 Corner Radii

- Small: 10
- Cards: 16
- Sheets: 28 (top corners only)
- Pills: 999

### 6.6 Elevation

No drop shadows. Use BackdropFilter + ImageFilter.blur for materials. Add a 0.5pt inner white stroke at 6% opacity on dark surfaces.

## PART 7 — MOTION & HAPTICS (THE DIFFERENTIATOR)

### 7.1 Motion Tokens (design_system/motion/motion.dart)

```dart
class Motion {
  static const snappy    = Duration(milliseconds: 280);
  static const smooth    = Duration(milliseconds: 420);
  static const bouncy    = Duration(milliseconds: 550);
  static const gentle    = Duration(milliseconds: 300);
  static const cinematic = Duration(milliseconds: 900);
  static const micro     = Duration(milliseconds: 150);

  static const snappyCurve    = Curves.easeOutBack;
  static const smoothCurve    = Curves.easeOutCubic;
  static const bouncyCurve    = Curves.elasticOut;
  static const gentleCurve    = Curves.easeInOut;
  static const cinematicCurve = Curves.easeInOutCubicEmphasized;
}
```

### 7.2 Global Animation Rules

- Every button press: scale to 0.97 with Motion.micro.
- Every state text change: AnimatedSwitcher with Motion.snappy.
- Every number change: count-up animation (custom, 400ms).
- Every icon toggle: ScaleTransition bounce with Motion.bouncy.
- Every async completion: haptic + visual pulse.
- Never use AnimationController without storing it and disposing it.

### 7.3 Haptic Choreography (design_system/haptics/haptics.dart)

| Event | Haptic |
|---|---|
| Button tap | HapticFeedback.lightImpact() |
| Toggle | HapticFeedback.selectionClick() |
| Scan state change | HapticFeedback.mediumImpact() |
| Guidance direction change | HapticFeedback.lightImpact() |
| Scan complete | HapticFeedback.heavyImpact() |
| Export complete | HapticFeedback.heavyImpact() |
| Error | HapticFeedback.heavyImpact() (or native error haptic) |
| Long-press menu | HapticFeedback.mediumImpact() |
| Purchase success | native UINotificationFeedbackGenerator.success() |

### 7.4 Signature Animations (must be built exactly)

- **Scan FAB pulse** — 1.2s loop, scale 1.0 → 1.05 → 1.0 with easeInOut.
- **Guidance dot fill** — 24 dots on a ring; filled dots scale 1.15 + accent color, Motion.snappy.
- **Model reveal** — particle explosion (60–80 particles) that reforms into the model. Custom CustomPainter + AnimationController, 800ms, Motion.cinematicCurve.
- **Export success** — checkmark draws (PathMetric trim), radial glow, auto-dismiss.
- **Paywall purchase** — confetti burst (60 particles, gravity sim), sheet dismiss with Motion.bouncy.
- **Pull-to-refresh** — 3D cube spins on X → Y → Z axes sequentially.
- **Sheet presentation** — drag handle morphs, backdrop blur animates in with Motion.smooth.

### 7.5 Reduce Motion

Detect MediaQuery.disableAnimationsOf(context). When true:
- Replace all springs with 200ms Curves.easeOut.
- Skip particle reveal — crossfade instead.
- Keep haptics.

## PART 8 — SCREEN-BY-SCREEN SPEC

### 8.1 Splash / Launch
- Wordmark fades in (400ms, ease).
- Cube icon draws 3 axes (trim animation, 600ms).
- Tagline fades in, letter-spacing animates -2 → 0.
- Dissolve to next screen at 1.2s.
- Haptic: lightImpact on logo complete.

### 8.2 Onboarding (3 pages, skippable)
- Page 1: "Turn anything into 3D" — floating cube rotating slowly.
- Page 2: "Just walk around it" — looping video of capture.
- Page 3: "Export. Print. Share." — icons fan out.
- Parallax page transitions (background moves at 0.6× speed).
- Page indicator: active dot stretches to a pill (300ms spring).

### 8.3 Library (Home)
- Large nav title "Forma" collapsing to inline "Library" on scroll.
- 2-column grid, 12pt spacing, adaptive to 3–4 columns on iPad.
- Cards fade+scale at scroll edges (scrollTransition-equivalent).
- Custom pull-to-refresh: 3D cube spinning.
- FAB bottom-center: 72×72, accent fill, viewfinder icon, pulse loop.
- Long-press card → context menu (Rename, Favorite, Export, Delete).
- Empty state: large rounded SF Symbol (72pt, 40% opacity), title, subtitle, CTA.

### 8.4 Capture Screen (⭐ MOST IMPORTANT)

Layout:
- Full-bleed camera preview — must be a native platform view wrapping ObjectCaptureView. Do NOT attempt to render the AR camera feed in Flutter.
- Top bar: close (X) left, torch toggle right, both in blurred circles (BackdropFilter).
- Bottom: guidance ring + guidance text + Finish button + optional Cancel.

Guidance overlay (in Flutter, on top of the platform view):
- 24 dots arranged in a ring around the object's detected bounding box.
- Dots the user has "covered" flip from grey → accent with a subtle scale pulse.
- A "next" arrow points to the least-covered angle.
- Direction changes trigger HapticFeedback.lightImpact() and rotate the ring 400ms.
- Guidance text changes based on feedbackUpdate: "Move closer", "Slow down", "Keep it in frame", etc.

State transitions:
- .initializing → screen fades in from black, 500ms.
- .ready → "Start Capture" button pulses (scale 1.0 → 1.05 → 1.0, 1.2s loop).
- .detecting → progress ring spins up.
- .capturing → dots fill in, text updates with AnimatedSwitcher.
- .finishing → entire view blurs (radius 0 → 20, 400ms) + spinner + "Building your model…".

Finish tap:
- HapticFeedback.heavyImpact().
- Ring completes with spring.
- Navigate (Hero/zoom transition) to Reconstruction screen.

**Critical:** the platform view for ObjectCaptureView must be created via UiKitView with ObjectCaptureViewFactory. The Flutter overlay sits in a Stack on top.

### 8.5 Reconstruction Screen
- Centered wireframe cube rotating slowly (drawn in Flutter CustomPainter, not native).
- Progress ring below with "Reconstructing… 47%".
- Number counts up smoothly.
- Background radial gradient shifts from accent → success as progress approaches 1.0.
- On complete: particle explosion → model reveal animation (800ms).
- Model does a 360° spin (3s, ease-in-out) before enabling the toolbar.
- Haptic: heavy impact + success notification.

### 8.6 Model Detail Screen
- 3D viewer (platform view of RealityKit scene; fallback: o3d).
- Orbit gesture.
- Primary button: "View in AR" → openARQuickLook.
- Toolbar: Share, Export, Rename, Delete.
- Bottom sheet (draggable detents: 120px, medium, large):
  - Metadata: vertices, triangles, file size, format, created date.
  - Export format pills: USDZ / OBJ / STL.

### 8.7 Export Sheet
- Bottom sheet, medium detent.
- Format picker: 3 large tappable cards with icons.
- Quality slider (Low / Medium / High) — Pro only.
- "Export" primary button.
- On export: button morphs to progress ring → checkmark with bounce → auto-dismiss → native share sheet.

### 8.8 Paywall
- Full-screen, large detent, blurred backdrop.
- Hero: animated 3D cube rotating with glow.
- Title: "Pay once. Scan forever."
- 3 benefit rows with staggered appear (100ms each).
- Price card: $14.99 struck through → $9.99 animating in.
- CTA: "Unlock Pro — $9.99".
- Secondary: "Restore Purchase".
- On purchase success: confetti, heavy haptic, dismiss with Motion.bouncy.

### 8.9 Settings
- List with iOS-style grouped sections.
- Rows: Appearance, Default Export Format, iCloud Sync (future), Storage, About, Support, Restore Purchase.
- Storage row: animated bar (used / total) with color shift at 80% / 95%.

### 8.10 Unsupported Device Screen
- Icon: iPhone with slash, slow pulse.
- Title: "Forma needs a Pro iPhone".
- Body: explains LiDAR requirement, lists supported models.
- Button: "Notify me when cloud scanning is available" (email capture — optional).
- No scanning entry point. No dark patterns. No "try anyway" button.

## PART 9 — DEVELOPMENT PHASES

### Phase 0 — Foundation (Week 1)
- flutter create forma
- Add Riverpod, freezed, json_serializable, go_router, Isar, path_provider
- Configure flutter_lints + very_good_analysis
- Set up GitHub repo (public for unlimited Actions minutes)
- Add .github/workflows/ios.yml
- Write design tokens (colors.dart, type.dart, spacing.dart, motion.dart, haptics.dart)
- Build core components: PrimaryButton, ScanCard, ProgressRing, EmptyState, Toast
- Exit: project builds, all components previewable in light/dark.

### Phase 1 — Native Bridge (Weeks 2–3)
- Create ios/Runner/NativeModule/ with all Swift services
- Implement CapabilityChecker, CaptureService, ReconstructionService, ExportService, FormaChannelHandler
- Write Dart NativeBridge
- Before evaluating plugins: check apple_spatial_capture on pub.dev — it may save you weeks
- First TestFlight build via GitHub Actions
- Test on a real LiDAR device
- Exit: Dart can call isScanSupported and receive true on a Pro device; startCapture opens the native session.

### Phase 2 — Capture Flow (Week 4)
- ScanCaptureScreen with UiKitView for ObjectCaptureView
- Guidance overlay in Flutter (dots + arrow + text)
- Capture view model state machine
- Haptics + animations per Part 7
- Cancel / discard flow
- Torch toggle
- Semantic labels for VoiceOver
- Exit: end-to-end scan on real device, images written to disk, 60fps sustained.

### Phase 3 — Reconstruction & Library (Weeks 5–6)
- Reconstruction screen with progress ring + particle reveal
- Isar-backed library
- Scan cards with async thumbnail loading
- Model detail screen with 3D viewer
- AR Quick Look button
- Rename, favorite, delete, search, sort
- Exit: scan → USDZ on disk → visible in library → opens in AR Quick Look.

### Phase 4 — Export & Monetization (Weeks 7–8)
- ExportService in Swift (MDLAsset + custom OBJ/STL writers)
- Export sheet in Flutter
- Share sheet integration
- StoreKit 2 in Swift, bridged
- Paywall screen with confetti
- Free tier limits (3 scans, watermark, USDZ only)
- Restore purchases
- Exit: STL opens in PrusaSlicer, OBJ opens in Blender with textures, purchase works in sandbox.

### Phase 5 — Polish (Weeks 9–10)
- Full animation audit vs Part 7
- Dynamic Type audit (test at AX5)
- VoiceOver audit on every screen
- Reduce Motion support
- Localization (7 languages)
- iPad layout
- App icon + launch screen
- Performance profiling (flutter run --profile)

### Phase 6 — Beta & Launch (Weeks 11–12)
- TestFlight internal (10) → external (50)
- Fix top 10 issues
- App Store assets (screenshots, preview video, icon)
- Privacy manifest, review notes
- Submit to App Review
- Launch day plan (Product Hunt, r/3Dprinting, r/iOSProgramming, HN)

## PART 10 — CI/CD WITH GITHUB ACTIONS

### 10.1 .github/workflows/ios.yml

```yaml
name: iOS Build

on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request:
    branches: [main, develop]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.x'
          cache: true
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage

  build-ios:
    if: github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/v')
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.x'
          cache: true

      - name: Cache CocoaPods
        uses: actions/cache@v4
        with:
          path: ios/Pods
          key: ${{ runner.os }}-pods-${{ hashFiles('ios/Podfile.lock') }}

      - name: Import signing certificates
        uses: apple-actions/import-codesign-certs@v3
        with:
          p12-file-base64: ${{ secrets.BUILD_CERTIFICATE_BASE64 }}
          p12-password: ${{ secrets.P12_PASSWORD }}

      - name: Install provisioning profile
        uses: apple-actions/download-provisioning-profiles@v3
        with:
          bundle-id: com.forma.app
          issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
          api-key-id: ${{ secrets.APPSTORE_KEY_ID }}
          api-private-key: ${{ secrets.APPSTORE_PRIVATE_KEY }}

      - run: flutter pub get
      - run: cd ios && pod install
      - run: flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

      - name: Upload to TestFlight
        uses: apple-actions/upload-testflight-build@v1
        with:
          app-path: build/ios/ipa/forma.ipa
          issuer-id: ${{ secrets.APPSTORE_ISSUER_ID }}
          api-key-id: ${{ secrets.APPSTORE_KEY_ID }}
          api-private-key: ${{ secrets.APPSTORE_PRIVATE_KEY }}

      - uses: actions/upload-artifact@v4
        with:
          name: ipa
          path: build/ios/ipa/*.ipa
```

### 10.2 Required GitHub Secrets

| Secret | Source |
|---|---|
| BUILD_CERTIFICATE_BASE64 | Exported .p12 from Apple Developer, base64-encoded |
| P12_PASSWORD | Your .p12 password |
| APPSTORE_ISSUER_ID | App Store Connect → Users & Access → Keys |
| APPSTORE_KEY_ID | Same page |
| APPSTORE_PRIVATE_KEY | Contents of .p8 file (base64-encoded) |

### 10.3 Cost Management

- Public repo: unlimited free macOS minutes. Use this. Your signing certs live in encrypted Secrets regardless of visibility.
- Private repo (Student Pack): 3,000 min/month baseline ÷ 10× macOS multiplier = ~300 macOS min/month ≈ 25–35 builds.
- Cache aggressively (~/.pub-cache, ios/Pods) — cuts build time 40–60%.
- Run heavy builds only on main and tags. PRs run lint+tests on Linux only.
- Apple Developer Program: $99/year — unavoidable, no student discount.

## PART 11 — RULES FOR THE AI AGENT

When writing code for this project:

### Hard Rules
1. Never add a subscription or recurring charge.
2. Never add a third-party analytics or tracking SDK.
3. Never make a network call without explicit user action.
4. Never allow scanning on a non-LiDAR device.
5. Always reference Motion.* constants for animations — no magic Durations.
6. Always fire a haptic on state change.
7. Always use design tokens — no Color(0xFF...) inline, no raw Colors.blue.
8. Always use ARB strings — no hardcoded English in widgets.
9. Always add Semantics labels to interactive widgets.
10. Always provide a light and dark preview for every new widget.

### Code Style
- One widget per file. File name matches widget name (primary_button.dart → PrimaryButton).
- Break widgets > 80 lines into subwidgets or private _build* methods.
- Prefer const constructors everywhere possible.
- Use freezed for all domain models.
- All async work in view models, not widgets.
- No setState for business logic.
- Cancel all stream subscriptions in ref.onDispose.

### Error Handling
- Single FormaError sealed class with Freezed.
- Map PlatformException codes → FormaError in native_exceptions.dart.
- User-facing messages never leak technical detail.
- Log via a central Logger with structured categories: capture, reconstruct, export, store, ui.

### When Stuck
- Check memory.md for past decisions.
- Check api-reference.md for Apple framework signatures.
- Prefer Apple sample code over Stack Overflow.
- If an animation feels off, verify against Part 7 of this prompt.

## PART 12 — GOTCHAS & KNOWN TRAPS

- PhotogrammetrySession.isSupported is the single source of truth. Do not infer from device model string.
- Apple has rejected apps for not messaging LiDAR limitation clearly. Ship the unsupported-device screen.
- OBJ output via PhotogrammetrySession may be deprecated on iOS 17+. Be prepared to write a custom OBJ exporter from MDLMesh.
- apple_spatial_capture on pub.dev exists and may save weeks of native work. Evaluate it in Phase 1 before writing custom Swift.
- Flutter platform views are expensive. Only use UiKitView where absolutely necessary: ObjectCaptureView, 3D viewer, AR Quick Look.
- Reconstruction is memory-heavy. On iPhone 12 Pro, large scans approach 1.5GB. Warn users, offer lower quality.
- Background reconstruction is limited. Use beginBackgroundTask; expect ~30s max. Prompt user to keep app open.
- Haptics don't fire in Simulator. Always test on real hardware.
- No Mac means no Xcode debugging. Use os_log in Swift, view logs in GitHub Actions output, or use a cloud Mac (MacinCloud, MacStadium) for occasional debugging.
- TestFlight requires a physical device. Have a LiDAR iPhone ready before Phase 1.

## PART 13 — DEFINITION OF DONE

For v1.0, ALL must be true:

- [ ] Runs on iPhone 12 Pro through iPhone 16 Pro Max without crashes.
- [ ] Shows the unsupported screen on all non-LiDAR devices.
- [ ] Scan → reconstruct → export to USDZ / OBJ / STL all work end-to-end.
- [ ] STL opens in PrusaSlicer without errors.
- [ ] OBJ opens in Blender with textures intact.
- [ ] USDZ opens in AR Quick Look.
- [ ] Every animation in Part 7 is implemented and matches the spec.
- [ ] Every haptic in Part 7.3 fires at the right moment.
- [ ] App passes VoiceOver navigation on every screen.
- [ ] App passes Dynamic Type at AX5 without truncation.
- [ ] App respects Reduce Motion and Reduce Transparency.
- [ ] Purchase + restore work in sandbox and production.
- [ ] 0 crash-free rate ≥ 99.5% over a week of TestFlight.
- [ ] All UI in dark mode, light mode, and iPad layout.
- [ ] Localized in en, es, fr, de, ja, ko, zh-Hans.
- [ ] App Store screenshots, preview video, and description are ready.
- [ ] Privacy manifest (PrivacyInfo.xcprivacy) included.
- [ ] App Review notes explain the LiDAR requirement clearly.

If any box is unchecked, it's not v1.0.

## PART 14 — HOW TO USE THIS PROMPT

- Save this file as MASTER_PROMPT.md in the root of your repo.
- Paste it at the start of every AI coding session.
- Reference specific Parts when asking for code: "Using Part 8.4, write the ScanCaptureScreen widget."
- When the AI drifts, point it back: "Re-read Part 11. You violated rule 5."
- Update this file when a decision changes. It is the single source of truth.

---

## IMPLEMENTATION DEVIATIONS (log of deltas from this spec)

| Date | Deviation | Reason |
|---|---|---|
| 2026-09-14 | Event channels merged into one `capture_events` channel (not two) | Simpler; payload `type` field discriminates. Contract in architecture.md §3 |
| 2026-09-14 | Drift (SQLite) chosen over Isar | Isar 3.x compatibility risk on Dart 3.13 |
| 2026-09-14 | FakeNativeBridge deleted entirely; single real IosNativeBridge | User directive: "we will not use anything fake" — honest failure via unsupported screen |
| 2026-09-14 | Tests use binary-messenger channel mocks (test doubles), not fakes in lib/ | Standard Flutter test API; no simulated capture logic ships in the app |
| 2026-09-14 | windows/ platform folder added | Local hot-reload dev on the Windows workstation |
| 2026-09-14 | IPA delivery: Sideloadly + personal Apple ID (not TestFlight) | No Apple Developer Program yet ($99/yr deferred); 7-day resign cadence accepted |
| 2026-09-14 | vphone-cli rejected as test target | Requires Apple Silicon macOS 15+ host; GH runners are nested VMs; guest has no LiDAR/camera |
| 2026-09-14 | Test device: iPhone 16 Pro Max (owned, LiDAR) | — |
| 2026-09-14 | `beginCapturing` added to bridge contract | ObjectCaptureSession requires explicit `startCapturing()` from `.detecting` (verified: Apple docs + macos-14 Xcode 15.4 SDK probe) |
| 2026-09-14 | ObjectCaptureSession needs `import SwiftUI` (lives in `_RealityKit_SwiftUI` overlay), is `@MainActor` | CI compile on iOS 17.5 SDK — absent from RealityKit main interface |
| 2026-09-14 | Podfile removed — project uses SPM integration (FlutterGeneratedPluginSwiftPackage) | `flutter build ios` failed with CocoaPods sandbox-sync error; SPM is the default for this template |
| 2026-09-15 | Native `ObjectCaptureView` platform view (`com.forma.app/capture_preview`) shipped in Phase 1.5, before the full Phase 2 UI | First device test showed a blank capture screen — without the preview the user aims blind and photogrammetry failed at ~25% on garbage input |
| 2026-09-15 | Capture/reconstruct errors surface full-screen with retry; details to `debugPrint` + `os_log` (`com.forma.app` subsystem) | Device test: failures were silent; diagnostics must survive no-Mac debugging |
| 2026-09-15 | Capture VM hard-resets after completion; success haptic/snackbar moved to the screen's completion listener | Device test: reopening capture after a finished scan inherited stale state — "Finish" appeared to do nothing |
| 2026-09-15 | go_router not yet adopted; Navigator.push routing; reconstruction UI lives inside CaptureScreen (ReconstructionPanel) | Kept from Phase 0; revisit when /model/:scanId lands in Phase 3 |
