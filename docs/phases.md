# Forma — Development Phases (Flutter Edition)

## Phase 0 — Foundation (Week 1) ✅ DONE
- [x] Flutter project, Riverpod, freezed, drift, very_good_analysis
- [x] Design tokens (Motion, FormaColors light/dark, spacing, radii, type)
- [x] Core components: PrimaryButton, ProgressRing, EmptyState, Toast, ScanCard
- [x] `NativeBridge` interface + `FakeNativeBridge` (full app runs on Windows)
- [x] Drift schema + DriftScanRepository
- [x] Library screen (grid, empty state, FAB) + theming
- [x] CI: GitHub Actions (analyze fatal-infos + tests; unsigned iOS build on main)
- [x] `codemagic.yaml` fallback
- Exit: analyze clean ✅, 11 tests green ✅

## Phase 1 — Native Module (Weeks 2–3) ✅ CODE COMPLETE
- [x] `ios/Runner/NativeModule/` Swift package-in-target:
      FormaChannelHandler, CaptureService, ReconstructionService,
      ExportService (stub), CapabilityChecker, FormaError, FormaEventSink,
      FormaStorage — registered in pbxproj
- [x] Dart `IosNativeBridge` (MethodChannel/EventChannel) implementing
      NativeBridge — the ONLY implementation (fakes purged per user directive)
- [x] `isScanSupported` gating + unsupported-device explainer screen
- [x] Camera permission + Info.plist strings; ios/Podfile created (was missing)
- [x] Unit tests (bridge contract via binary-messenger mocks, view model,
      unsupported screen, library navigation) — 23 green, analyze clean
- [x] windows/ dev platform + smoke-run
- [x] First CI macOS build (first Swift compile — no local Mac) — GREEN
- [ ] Install on iPhone 16 Pro Max via Sideloadly; verify
      `isScanSupported` == true and capture session opens
      (Phase 1 exit criteria)

## Phase 2 — Capture UI (Week 4)
- [ ] `ScanCaptureScreen`: native preview (UiKitView) OR plugin UI
- [ ] Guidance overlay (24-dot ring) driven by feedbackUpdates — if custom
- [ ] CaptureViewModel state machine; haptics + animations per design.md
- [ ] Cancel/discard flow; torch toggle

## Phase 3 — Reconstruction & Library (Weeks 5–6)
- [ ] ReconstructionScreen progress ring + particle reveal (CustomPainter)
- [ ] Library CRUD: rename, favorite (undo toast), delete w/ file cleanup
- [ ] ModelDetailScreen: 3D viewer (native preview via bridge first), metadata
- [ ] AR Quick Look via bridge

## Phase 4 — Export & Monetization (Weeks 7–8)
- [ ] Swift ExportService: USDZ native, OBJ (+MTL/textures), binary STL writer
- [ ] ExportSheet UI + share sheet; quality presets (Pro)
- [ ] StoreKit 2 → entitlement provider; free tier (3 scans, watermark)
- [ ] PaywallScreen + triggers; restore; .storekit local testing

## Phase 5 — Polish (Weeks 9–10)
- [ ] Animation/haptic audit vs design.md; dark-mode audit
- [ ] textScaler AX audit; Semantics audit; localization (ARB, 7 locales)
- [ ] Performance pass (profile mode); app icon + launch screen

## Phase 6 — Beta & Launch (Weeks 11–12)
- [ ] TestFlight via Codemagic; feedback; App Store assets; submit
