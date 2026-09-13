# Forma — Design System (Flutter Edition)

Design vision unchanged from the original design.md (Apple-level polish,
dark-first, content-is-hero). This edition maps every SwiftUI primitive to
Flutter. Rules below are binding.

## 1. Foundations
- **Colors:** `FormaColors` ThemeExtension — semantic tokens (bg, bgElevated,
  bgSunken, textPrimary/Secondary/Tertiary, accent #FF6B35/#FF7A45, accentSoft,
  success, warning, danger, separator). Light + dark values exactly as §1.1 of
  the original. Access via `FormaColors.of(context)` — never hardcode.
- **Type:** `AppTypography` (displayL 40/bold → caption 12; -1..0 tracking).
  Scales with the system `textScaler` up to AX sizes.
- **Spacing:** `AppSpacing` 4pt grid (4..64). **Radii:** `AppRadii`
  (small 10, card 16, sheet 28, pill 999).
- **Elevation:** no drop shadows — layered translucency (`Colors` + opacity),
  0.5pt hairline separators.

## 2. Motion (design.md §5.1 → Flutter)
| Token | Value | Curve |
|---|---|---|
| snappy | 280ms | easeOutCubic |
| smooth | 420ms | easeOutCubic |
| bouncy | 550ms | easeOutBack |
| gentle | 300ms | easeInOut |
| cinematic | 900ms | fastOutSlowIn |
| micro | 150ms | easeOut |

All animations must take `Motion.*`. Implicit animations for state; explicit
(AnimationController) for looping/reveal sequences.

## 3. Haptics (§5.4 mapping)
button tap → lightImpact · toggle → selectionClick · scan state → mediumImpact ·
success → mediumImpact · error → heavyImpact · long-press → mediumImpact.
(Flutter's HapticFeedback lacks notification styles; documented mapping.)

## 4. Components (built, tested, goldened in Phase 0)
- `PrimaryButton` — pill h56, accent, scale 0.97 on press, loading spinner swap.
- `ProgressRing` — 3pt accent arc, animated 0..1 (TweenAnimationBuilder).
- `EmptyState` — 72pt icon @40%, displayM title, CTA.
- `Toast` — top overlay capsule (info/success/error), auto-dismiss 3s.
- `ScanCard` — 3:4 thumb, rounded 16, translucent info strip (name/date).

## 5. Screens (status)
- Library (home): ✅ grid 2-col, large title, FAB (filter_center_focus), empty state.
- Capture: Phase 2 (see phases.md). Reconstruction: Phase 3. Paywall: Phase 4.

## 6. Signature Animations to build (Phase 2+)
1. Scan start pulse (1.2s loop on FAB)
2. Guidance dot fill (CustomPainter + feedback stream)
3. Model reveal — particle explosion (CustomPainter + Timeline ~80 particles)
4. Export success — checkmark + radial glow
5. Paywall confetti (60 particles, gravity sim)
6. Pull-to-refresh cube spin

## 7. Accessibility
Semantics labels on all interactive elements; 44pt min targets; test with
screen reader + textScaler 3.2; reduce-motion: swap springs for ease-out.

## 8. Dark Mode
Dark-first. Every widget must be exercised in both themes (widget tests +
goldens prove it in CI).
