# Forma — Engineering Rules (Flutter Edition)

## 1. Dart Style
- Effective Dart + very_good_analysis. `flutter analyze` must stay at zero issues.
- Max line 80 (formatter-enforced), max file 400 lines, max function ~40.
- `const` everywhere possible; `final` over `var`; sound null safety — no `!`
  without a justification comment.

## 2. Flutter UI Rules
- One widget per file; split widgets > 80 lines.
- No hardcoded colors — `FormaColors.of(context)` (ThemeExtension).
- No hardcoded strings — central strings now, AppLocalizations (ARB) in Phase 5.
- Every animation: `Motion.*` duration/curve, always with an explicit `value:`.
- Every state change: haptic via `HapticFeedback` wrapper (see design.md §5.4).
- `RepaintBoundary` around complex custom-painted animations.

## 3. State Management (Riverpod)
- `Provider` for services, `StreamProvider` for bridge events,
  `Notifier`/`AsyncNotifier` for view models.
- View models never receive `BuildContext`; no `setState` for business logic.

## 4. Platform Channel Rules
- Channels: `com.forma.app/{feature}`. All calls `Future`-based + try/catch.
- `EventChannel`-backed broadcast streams for continuous events.
- Dart code must ONLY touch native via `NativeBridge` (package:forma/platform/…).
- Document every channel method in architecture.md §3.

## 5. Native (Swift) Rules
- Swift API Design Guidelines; no force unwraps outside tests; `[weak self]`
  in closures; `Result`-based errors; `os_log` categories: capture, reconstruct,
  export, store, ui.

## 6. Concurrency
- `Future`/`Stream`; cancel subscriptions in `dispose()`; `Isolate.run` for
  heavy Dart computation; never block the UI thread.

## 7. Errors
- Single `FormaError` hierarchy in Dart; native errors arrive as
  `PlatformException` and are mapped at the bridge boundary.
- User-facing messages never leak technical detail; recoverable → toast;
  never crash on framework failure.

## 8. File Organization
```
lib/
├── main.dart, app.dart
├── core/           models/ repositories/ errors/ logging/ providers.dart
├── data/database/  (Drift)
├── features/       onboarding/ library/ capture/ reconstruction/ model_detail/ export/ paywall/ settings/
├── design_system/  tokens/ components/ theme.dart
└── platform/native_bridge/
test/               mirrors lib structure
docs/               project docs
.github/workflows/  ci.yaml, ios-build.yaml
```

## 9. Naming
- Widgets `ScanCaptureScreen`, providers `captureViewModelProvider`,
  services `CaptureService`, bridge `NativeBridge`.
- Booleans `isReady`, `canExport`; async `Future<X> doThing()`.

## 10. Do Not
- ❌ Ship a feature without dark mode.
- ❌ Add a subscription.
- ❌ Use raw `Colors.x` in widgets — theme tokens only.
- ❌ Skip haptics on state changes.
- ❌ Merge without `flutter analyze` (fatal-infos) and `flutter test` green.
- ❌ Push directly to `main`.
