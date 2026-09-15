# Forma — Technical Architecture (Flutter Edition)

## 1. Stack
- **UI:** Flutter 3.47 stable / Dart 3.13, Material 3
- **State:** Riverpod 3
- **Native (iOS):** Swift 5.10+, RealityKit/ARKit/Object Capture, Model I/O, StoreKit 2
- **Bridge:** platform channels (`MethodChannel` + `EventChannel`), hidden behind `NativeBridge`
- **Persistence:** Drift (SQLite), path_provider file layout
- **Min iOS:** 17.0 (Object Capture requirement) · Bundle ID `com.forma.app`
- **CI:** GitHub Actions (analyze/test/unsigned builds) + Codemagic (signed/TestFlight)

## 2. Module Graph
```
FormaApp (Flutter + Riverpod)
  ├─ UI Layer (screens/widgets, design_system)
  ├─ Feature logic (providers per feature)
  ├─ Domain (core/models — freezed, zero deps)
  ├─ Data (core/repositories + data/database via Drift)
  └─ platform/native_bridge ──► Swift NativeModule (ios/Runner/NativeModule/)
        ├─ FormaChannelHandler (channels)
        ├─ CaptureService (ObjectCaptureSession)
        ├─ ReconstructionService (PhotogrammetrySession)
        ├─ ExportService (MDLAsset → USDZ/OBJ/STL)
        └─ CapabilityChecker (isSupported)
```

## 3. Bridge Contract (implemented as `NativeBridge`)
Commands (Future-based): `isScanSupported`, `startCapture → scanId`,
`finishCapture(scanId)`, `cancelCapture(scanId)`, `startReconstruction(scanId)`,
`exportModel(scanId, format) → path`.
Streams (broadcast): `phaseUpdates` (initializing→ready→detecting→capturing→
finishing→completed|failed), `feedbackUpdates` (objectTooClose/TooFar/
movingTooFast/outOfFieldOfView), `reconstructionProgressUpdates` (0..1),
`reconstructionCompleteUpdates` (model path), `errorUpdates` ({code,message}).

Native method-channel names (Phase 1): `com.forma.app/native` +
`com.forma.app/capture_events`. All methods error via `PlatformException`
mapped to a single `FormaError` hierarchy in Dart.

Camera preview (2026-09-15): native `ObjectCaptureView` platform view
registered as `com.forma.app/capture_preview` (UiKitView in Dart;
ScanViewportController binds the active session to it).
`hasActiveCaptureSession` probes the native session state.

## 4. Data Flow
Scan tap → `nativeBridge.startCapture()` → phases stream → capture UI →
`finishCapture` → `startReconstruction` → progress → complete →
`ScanRepository.save(Scan(status: ready, modelPath:…))` → library grid updates.

## 5. Persistence
- Drift DB `forma` (schema v1): `ScanTable` — id(text, PK), name, createdAt,
  updatedAt, statusIndex, thumbnailPath?, modelPath?, bytes, isFavorite, tags(csv).
- Files (path_provider docs dir): `/Scans/{uuid}/Images/`, `Model.usdz`,
  exports under `/Exports/`.

## 6. Concurrency
- Dart: Riverpod + `Stream`s from the bridge; cancel subscriptions in dispose.
- Swift (Phase 1): strict concurrency, sessions on dedicated Tasks,
  `AsyncStream` bridging, no retain cycles (`[weak self]`).

## 7. Testing
- Dart unit: view models, fake bridge, repository contract.
- Widget tests: every screen/component, light+dark (goldens for components).
- Integration: platform-channel bridge with mock native (fake) — full flow.
- Native XCTest for Swift services in Phase 1+ (runs on macOS CI).

## 8. Device Gating
`nativeBridge.isScanSupported()` gates the entire capture flow. Non-LiDAR
devices get the explainer screen — never a broken experience (F7).
