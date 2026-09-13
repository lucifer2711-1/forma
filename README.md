# Forma

**Turn anything into 3D. Right from your iPhone.**

Flutter iOS app for LiDAR-based object scanning: guided capture, on-device
reconstruction, USDZ/OBJ/STL export, AR preview. One-time purchase, no
subscriptions, 100 percent on-device.

## Status
Phase 0 (Foundation) complete: design system, NativeBridge abstraction with a
working fake (app runs on Windows), Drift persistence, 11 green tests,
GitHub Actions + Codemagic CI. See docs/phases.md.

## Develop on Windows

    flutter pub get
    flutter analyze          # very_good_analysis, must stay clean
    flutter test             # unit + widget + golden tests
    flutter run -d windows   # runs with FakeNativeBridge (mock scans)

## iOS (CI)
All iOS builds happen in CI (no local Mac needed):
- GitHub Actions: analyze/tests on PRs; unsigned iOS build on main
- Codemagic: signed builds + TestFlight (codemagic.yaml)

## Architecture
docs/architecture.md - the key seam is lib/platform/native_bridge/:
NativeBridge (interface) -> today FakeNativeBridge, Phase 1 adds the Swift
platform-channel implementation behind the same contract.

## Docs
docs/ - prd, architecture, rules, design, phases, memory, cicd.
Read docs/memory.md first (decisions log + environment gotchas).