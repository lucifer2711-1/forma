# Forma — CI/CD Guide

## Primary: GitHub Actions (public repo = free unlimited macOS)
- `.github/workflows/ci.yaml` — every PR + push to main:
  `flutter pub get`, `flutter analyze --fatal-infos`, `flutter test` (Linux).
- `.github/workflows/ios-build.yaml` — push to main + tags `v*`:
  unsigned `flutter build ios --release --no-codesign` on macos-14, artifact upload.
- Concurrency blocks cancel superseded runs. Cache pub + pub-cache.

## Fallback: Codemagic (signed builds → TestFlight)
1. Create account → connect repo.
2. Add App Store Connect API key (issuer id, key id, .p8 contents) in env vars.
3. `codemagic.yaml` at repo root (already committed) → workflow `ios-testflight`.

## Debugging native code without a Mac
- Extensive `os_log` in Swift; logs visible in CI build output.
- Keep native modules small and behind tests.
- Remote Mac services (e.g., MacStadium) for hands-on debugging if needed.

## Budget strategy
- Public repo: macOS minutes free — biggest lever.
- PR checks stay on Linux; macOS reserved for real builds.
- Cancel in-progress runs (concurrency groups already set).
- Codemagic free tier: 500 macOS minutes/month — release builds only.
