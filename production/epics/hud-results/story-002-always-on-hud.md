# Story 002: Clock, phase, roster, objective checklist and crosshair

> **Epic**: HUD & Results Screen
> **Status**: In Review
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

The always-visible survivor HUD (H1-H6 in `hud.md`): the round clock with the final-30-second treatment, the phase label, the activation countdown, the roster with life-state icon and word, the objective checklist and the crosshair dot. None is drawn by the shipped client round scene today.

**GDD**: `design/ux/hud.md` H1-H6; HUD States; Layout Zones Z1-Z4
**Requirement**: `TR-ui-001`, UX-hud-01, UX-hud-02, UX-hud-10
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: UI and input focus
**ADR Decision Summary**: HUD widgets are views on the HUD layer, FOCUS_NONE and MOUSE_FILTER_IGNORE, reading HudModel only; every string through tr().
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: every visible string through tr()
- Required: FOCUS_NONE and MOUSE_FILTER_IGNORE on HUD controls
- Forbidden: a HUD widget holding a gameplay module, the snapshot or the router

---

## Acceptance Criteria

*From GDD `design/ux/hud.md`, scoped to this story:*

- [ ] In exploration a survivor sees exactly the clock, phase label, roster, objective checklist and crosshair, plus live markers and feed lines; with Show roster Off the roster is absent.
- [ ] Clock and phase follow the server (`MatchDisplay`), the activation countdown shows "Paused" when nobody holds, and roster life states show an icon plus a word.
- [ ] At 1920x1080, 2560x1080 and 1920x1200 every element sits at least 48 px from each edge (64 px from the 16:9 safe rectangle at 21:9), and critical text measures at least 20 px at 1080p.
- [ ] Retained screenshots of exploration at the three resolutions.

---

## Implementation Notes

- Margins and sizes are layout constants in one place; the spec's Tuning Knobs (HUD scale, Show roster) become knobs.
- Capture through `round_view` with a fixed seed; ports 30000-30999.

---

## Out of Scope

- Shapeshifter elements S1-S7 (story 006).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: retained screenshot of each screen touched in `production/qa/evidence/always-on-hud/`

**Status**: [x] production/qa/evidence/always-on-hud-evidence.md (4 png); tests/unit/hud-results/always_on_hud_test.gd

---

## Dependencies

- Depends on: Story 001
- Unlocks: Story 010

## Progress Notes (2026-10-15)

Merged 429a4fc+fe363e2+f91e1d8 (round_view.gd conflict with HUD-7 resolved keeping both bots). AlwaysOnHud: clock, phase, activation countdown, roster with icon+word, objective checklist, crosshair dot with dark rim; reads HudModel only; hidden until the first phase. HudModel gains set_survivors, name_of, on_activation, activation. Main hides the boot status line while the round view is spawned. DEVIATIONS: HUD scale, Show roster and Reduced motion are widget properties, not knobs (knobs feed the join version hash, so per-player settings there would split joins). OPEN DATA GAPS: no server message sends the round roster (round_view seeds it; the shipped path shows only survivors an event named until a producer calls set_survivors); no server message carries activation seconds or paused state (label reads "Activating"; handler unit-tested); Wounded state, crosshair hide while hidden and final-30 s tick sound not drawn. Measured: text 60/62 px from edges at 1080p and 16:10; 76/78 px inside the 16:9 rect at 21:9; capitals 21 px at 1080p. 4 mutations caught. Full suite 1451/1451.
