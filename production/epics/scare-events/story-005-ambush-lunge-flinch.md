# Story 005: Ambush lunge scare and flinch suppression near a lunge

> **Epic**: Scare Events
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

At lunge wind-up (`AbilityUsed`) the server runs the ambush test per survivor within `lunge_cue_radius_m`: no line of sight to the monster's chest for `ambush_unseen_s`, or a blacked-out volume. A passing survivor gets the ambush lunge scare. The server-held flinch offset and its freeze already exist from controller-interaction story 013; this story drives it from Major scares.

**GDD**: `design/gdd/scare-events.md` rules 13, 14; Formulas (ambush test)
**Requirement**: `TR-scare-005`, `TR-scare-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0015: Scare presentation and view offset; secondary: ADR-0009, ADR-0012
**ADR Decision Summary**: Flinch is a server-held view offset written into the Controller's view-offset input; a lunge wind-up freezes it.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Required: line of sight through the shared `SightTest`, facing ignored
- Required: `ambush_unseen_s` from data

---

## Acceptance Criteria

*From GDD `design/gdd/scare-events.md`, scoped to this story:*

- [x] A lunge wind-up started in a blacked-out volume, or by a monster that a survivor within `lunge_cue_radius_m` has not seen for `ambush_unseen_s`, sends the ambush lunge scare to that survivor; a wind-up in a lit volume by a monster seen within `ambush_unseen_s` sends none.
- [x] No flinch plays on a survivor within `lunge_cue_radius_m` of a monster in lunge wind-up or Active, from the ambush scare or any other Major scare.
- [x] A Major scare to a toggled-on player writes the flinch through `ViewOffset`; maximum measured input loss is at most 0.3 s, and movement and stun input work during a flinch.

---

## Implementation Notes

- Per-survivor last-seen time of the monster chest is updated each tick in a physics phase.
- Reuse `src/core/controller/view_offset.gd`; do not add a second offset path.

---

## Out of Scope

- Re-baseline rules (done in controller-interaction 013).

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/scare-events/ambush_lunge_flinch_test.gd` (real ENet where the AC names clients)

**Status**: [x] `tests/integration/scare-events/ambush_lunge_flinch_test.gd` (4 cases, AC3 over real ENet)

---

## Dependencies

- Depends on: Stories 001, 002
- Unlocks: None

## Progress Notes (2026-10-15)

Merged from wt-se5. Full suite 1328 tests: 1327 passed. `proximity_voice_replication_test.gd` failed during the run while parallel agents ran real-ENet suites, and passed 2/2 re-run alone (a port clash, as in sprint 7; no bound widened). Mutations caught: blackout ignored, `ambush_unseen_s` threshold removed, flinch gated on wind-up only, Minor scares allowed to flinch.

Notes:
- `AmbushTest` runs at `TickOrder.SCARE_EVENTS - 1`, recording each survivor's last sight of the monster chest; `ScareFlinch` turns each delivered Major `ScareTriggered` into a `FlinchRequested`. `ViewOffset` stays the only offset writer. `_in_wind_up` in the composer now covers Lunge Active too (rule 14).
- After SE-2 gating merged, the flinch test steps past `major_scare_cooldown_s` before its last burst, because the earlier Majors start the cooldown (rule 9).

Deviations (inference):
- `SightTest` runs with fov INF: at 360 a monster exactly behind was dropped (`angle_to` rounds above PI).
- A survivor who has never seen the monster this round counts as unseen. A designer call on early-round lunges settles it.
- The cue radius is measured chest to chest (same as feet at equal capsule height).
- AC3 input loss is counted in server ticks to the offset target against `scare_max_control_loss_s`.
