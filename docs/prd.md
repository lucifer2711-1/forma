# Forma — Product Requirements (Flutter build)

**App:** Forma — *"Turn anything into 3D. Right from your iPhone."*
**Platform:** iOS 17+, LiDAR (Pro) devices · **Bundle ID:** `com.forma.app`
**Stack:** Flutter UI + Swift native capture module (see architecture.md).

## Vision
Anyone can turn a real object into a shareable, printable, AR-ready 3D model
using only their iPhone. No subscriptions. No cloud. Pay once, scan forever.

## Problem
Polycam/Scandy Pro/Heges are subscription-walled ($100–300/yr). Makers and AR
devs resent monthly fees for occasional use; existing apps have poor UX and
hidden export limits.

## Target Users
1. **Maker Maya** — 3D-printing hobbyist; scans figurines/parts; wants
   STL/OBJ export; buys one-time-purchase apps.
2. **AR Dev Dan** — needs clean USDZ for RealityKit/Quick Look; batch exports.
3. **Curious Casey** — first scan must feel magical (onboarding + reveal).

## Core Features
**P0 (v1.0):** F1 guided LiDAR capture · F2 on-device reconstruction (USDZ) ·
F3 local model library · F4 AR Quick Look preview · F5 share-sheet export ·
F6 one-time Pro IAP (StoreKit 2) · F7 device capability gating · F8 dark+light.
**P1 (v1.1):** OBJ export, STL export, iCloud sync, multi-object scan, re-scan/merge.
**P2 (v1.2+):** cloud reconstruction for non-LiDAR, mesh cleanup, AR placement,
widget, Vision Pro companion.

## User Stories (must-pass)
1. Maker: scan a small object in <2 min → STL ready to slice.
2. AR dev: USDZ with clean textures, drops into Reality Composer as-is.
3. Curious user: first scan feels magical → tells friends.
4. Paying user: pay once, never see a paywall again.
5. Non-LiDAR user: clear explanation, never a broken experience.

## Monetization
- **Free:** 3 scans total, USDZ export only, watermark on share.
- **Pro (one-time):** $14.99 (launch promo $9.99, first 2 weeks) — unlimited
  scans, OBJ/STL, no watermark, iCloud sync. No subscriptions. No ads. Ever.

## Success Metrics (90 days)
DAU/MAU ≥ 25% · first-scan completion ≥ 70% · paywall conversion ≥ 6% ·
App Store rating ≥ 4.7 · crash-free ≥ 99.5% · scan-to-export ≤ 3 min median.

## Constraints & Risks (Flutter edition)
| Risk | Mitigation |
|------|-----------|
| Apple rejects app for LiDAR limitation | Clear in-app messaging + review notes |
| Flutter bridge to native frameworks is complex | `NativeBridge` abstraction; plugin vs custom decision gated at Phase 1 exit |
| No local Mac for native debugging | CI builds + os_log in CI logs; all Dart dev on Windows with FakeNativeBridge |
| Plugin quality varies | Plugin-first behind our interface; custom Swift module is the escape hatch |
| 3D viewer perf | Native preview via bridge (already in plugin scope); o3d only as fallback |
| Long reconstruction | Progress UI, notify on completion |
| Storage bloat | Compress textures; "delete source photos" action |

## Non-Goals
Not a cloud photogrammetry service; not turntable-based; no non-LiDAR
scanning; no Android for v1.0.
