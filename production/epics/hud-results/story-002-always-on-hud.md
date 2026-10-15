# Story 002: Clock, phase, roster, objective checklist and crosshair

> **Epic**: HUD & Results Screen
> **Status**: Ready
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

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: Story 010
