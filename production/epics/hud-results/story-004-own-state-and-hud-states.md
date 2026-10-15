# Story 004: Own-state vignettes, own bleed-out and the HUD state table

> **Epic**: HUD & Results Screen
> **Status**: Complete
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

**Status**: [x] Created: `production/qa/evidence/own-state-and-hud-states-evidence.md` (lead sign-off pending)

---

## Dependencies

- Depends on: Stories 001, 002
- Unlocks: None

## Progress Notes (2026-10-15)

Merged edff945..d7381a9. OwnStateHud (vignette edge bands, own bleed-out takes Z4, Seized and shocked rows, hidden prompt "Leave", spectating hides crosshair and blocks ping/warning/wheel; feed scrollback stays). HudModel hud_state(), spectating(), watched(), bleed-out and rescue values. SERVER: SurvivorHudFeed sends EventBatch.OWN_LIFE {life, rescue_s} per survivor on change (rescue in tenths), diffed once per tick, monster gets nothing; batch_extras 12. BUG FIX outside story: round_client passed the network peer id as own player id to AlwaysOnHud (HUD-2 crosshair never hid on own Downed); now net.local_player_id. DEFECTS NOT FIXED: spectating 3D view is black (no spectator camera; OwnerPredictor replays the spectator inputs on the watched body, which falls below the map); TaserCount still shows the watched survivor kit while spectating (state table says no kit). INFERENCE: shocked lasts stun_root_s; vignette is placeholder bands, not the P11 shader. Shocked, rescue ring and the 250 ms transition are unit-tested only. 12 unit tests; 3 mutations caught. Full suite 1500/1500.

## Closed (2026-10-15)

Closed on its retained screenshots (UI gate). The designer played the shipped build on 2026-10-15 (lobby to round to Results; survivor, shapeshifter and spectating sessions), then approved closing the sprint-9 UI stories in chat (AD-242). Orchestrator reviewed the evidence images. Earlier shots predate BUG-0010/0011 (fixed in b024355); after-fix shots are in production/qa/evidence/hud-budget-accessibility/after/.
