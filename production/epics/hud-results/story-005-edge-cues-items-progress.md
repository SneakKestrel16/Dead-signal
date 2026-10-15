# Story 005: Edge cues, flinch-off pulse, taser count and world progress bars

> **Epic**: HUD & Results Screen
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

H11, H13 and H14: the taser cartridge count, world progress bars on objects in progress, and edge cue indicators for the lunge wind-up, the transform arc and the flinch-off substitute pulse (P8). `scare_presenter.gd` still says the P8 edge pulse is not built.

**GDD**: `design/ux/hud.md` H11, H13, H14; pattern P8
**Requirement**: `TR-ui-001`, `TR-scare-009`, UX-hud-08
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: UI and input focus; secondary: ADR-0015
**ADR Decision Summary**: Edge cues are HUD shapes driven by HudModel; with flinch off, the pulse replaces the camera flinch and never alters server timing.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: the flinch-off pulse is client-only and changes no server state
- Required: cue radius from the knob `lunge_cue_radius_m`

---

## Acceptance Criteria

*From GDD `design/ux/hud.md`, scoped to this story:*

- [ ] The lunge wind-up chevron appears for a player at 19 m from the source and not at 21 m (`lunge_cue_radius_m` 20), pointing toward the source.
- [ ] With camera flinch off, a scare that would flinch shows the P8 edge pulse instead, and the server's view offset path is unchanged.
- [ ] A survivor holding the taser sees the cartridge count change within one snapshot of a shot; objects in progress show a world bar with percent and "Paused".
- [ ] Retained screenshots of each cue.

---

## Implementation Notes

- Remove the "Not here yet" note in `scare_presenter.gd` once the pulse lands.

---

## Out of Scope

- Final art for the cues.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: retained screenshot of each screen touched in `production/qa/evidence/edge-cues-items-progress/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: None
