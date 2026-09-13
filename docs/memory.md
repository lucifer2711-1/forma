# Forma — Project Memory

> Single source of truth for AI agents and engineers. Read this first.

## What We're Building
Forma is a Flutter iOS app that turns photos into 3D models using Apple's
Object Capture and PhotogrammetrySession frameworks, accessed through a
platform-channel bridge to a Swift NativeModule. One-time purchase, no
subscriptions, 100% on-device. Built on a Windows machine; iOS builds happen
in CI (GitHub Actions public repo → Codemagic fallback for signed builds).

## Non-Negotiables
- No subscriptions. Ever.
- 100% on-device. No cloud for v1.0.
- LiDAR-only for scanning. Gate everything behind a support check. Do not fake it.
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
| 2026-09 | `NativeBridge` abstraction + `FakeNativeBridge` | Whole app runs/tests on Windows without iOS device |
| 2026-09 | GitHub Actions primary CI, Codemagic fallback | Public repo = free macOS minutes; signed builds via Codemagic |
| 2026-09 | very_good_analysis (not flutter_lints) | Strict per rules.md §1 |

## Environment Gotchas (discovered in Phase 0 — do not re-learn these)
1. **drift + build_runner AOT silently fails on the `int()` column alias.**
   A table using `IntColumn get x => int()();` generates an EMPTY database
   (no error!). Use `integer()()` instead. Same for reviewing any drift code.
2. **freezed 4 requires `abstract`/`sealed` on annotated classes**, and the
   factory must be named: `const factory Scan({...}) = _Scan;` — a nameless
   `const factory({...})` generates a broken (half-empty) part file.
3. **PowerShell Set-Content writes UTF-8 BOM** and can mangle em-dashes into
   mojibake. Prefer the editor tool or `[IO.File]::WriteAllText` with
   `UTF8Encoding($false)` when writing Dart files from scripts.
4. **`dart fix --apply` rewrites constructors to the new `new(...)` syntax**
   (unnecessary_type_name_in_constructor). We disabled that lint; if you run
   dart fix and see `const new({`, revert it.
5. **`dart:math` has no `tau`** — use `2 * math.pi`.
6. **`Icons.viewfinder` doesn't exist** in Material icons; use
   `Icons.filter_center_focus`.
7. **DateTime has no const constructor** — `const Scan(createdAt: DateTime(...))`
   won't compile; use `final`.
8. **Broadcast streams in tests**: attach listeners BEFORE the event fires or
   you will hang/miss events.

## Platform Bridge Contract (see architecture.md §3)
- `MethodChannel`-equivalent commands: isScanSupported, startCapture,
  finishCapture, cancelCapture, startReconstruction, exportModel.
- Event streams: phaseUpdates, feedbackUpdates, reconstructionProgress,
  reconstructionComplete, errorUpdates.
- The ONLY implementation today is `FakeNativeBridge`. Phase 1 adds the real
  Swift bridge; swap it in `core/providers.dart` — nowhere else.

## Current Sprint
Phase 0 — Foundation: DONE (analyze clean, 11 tests green, CI configured).
Next: Phase 1 — Swift NativeModule + real bridge behind the same interface.

## Open Questions
- [ ] apple_spatial_capture vs custom Swift module for the capture UX →
      decide at end of Phase 1 after first real scan.
- [ ] Pricing $9.99 vs $14.99 → after beta.
- [ ] PhotogrammetrySession OBJ output availability on iOS 18 → Phase 2.

## For AI Agents
1. Read `rules.md` before writing code.
2. Never introduce a subscription or a cloud dependency.
3. Every widget needs light+dark coverage; use `FormaColors.of(context)`.
4. Every animation references `Motion.*`. Every state change: `AppHaptics`-equivalent.
5. Update this Decisions Log when making architectural choices.
