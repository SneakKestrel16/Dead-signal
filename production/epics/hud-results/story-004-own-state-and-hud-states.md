# Story 004: Own-state vignettes, own bleed-out and the HUD state table

> **Epic**: HUD & Results Screen
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

H15 and H16 and the HUD States table: Seized, Downed, shocked, hidden and spectating each change what shows. Downed swaps the prompt for own bleed-out seconds; spectators see the watched survivor's feed and markers but no wheel and no ping (pings-and-callouts rule 7).

**GDD**: `design/ux/hud.md` H15, H16; HUD States by Gameplay Context
**Requirement**: `TR-ui-001`, UX-hud-02, UX-hud-03
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: UI and input focus
**ADR Decision Summary**: HudModel own_state_changed drives the state; the HUD decides nothing about life state.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: own state comes from HudModel only
- Forbidden: the HUD inferring life state from local prediction

---

## Acceptance Criteria

*From GDD `design/ux/hud.md`, scoped to this story:*

- [ ] Downed: the vignette and the word "Downed" show, the crosshair hides, own bleed-out seconds replace the prompt, and roster and checklist stay.
- [ ] Seized, shocked and hidden each show their row of the state table and nothing else; the transition takes 250 ms, or a cut with reduced motion on.
- [ ] Spectating shows roster, clock, objectives, and the watched survivor's feed and markers, with no wheel and no ping input.
- [ ] Retained screenshots of Downed, Seized, hidden and spectating.

---

## Implementation Notes

- Use `round_view` bots to reach each state; record which flag reached it.

---

## Out of Scope

- Reduced-motion setting UI (Accessibility Options system).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**: retained screenshot of each screen touched in `production/qa/evidence/own-state-and-hud-states/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001, 002
- Unlocks: None
