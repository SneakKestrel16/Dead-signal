# Story 006: Hiding spots: enter, exit, occupancy, search

> **Epic**: Survivor Defense
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Hiding spots as interactables: a Healthy survivor holds `hide_transition_s` to enter or leave, one occupant per spot; the monster in any form can hold `search_duration_s` to eject an occupant without a hit. A hidden survivor is excluded from lunge targeting, objectives, pings and shot traces.

**GDD**: `design/gdd/survivor-defense.md`
**Requirement**: `TR-defense-006, TR-defense-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Hold-to-interact protocol; secondary: ADR-0004
**ADR Decision Summary**: Hide and search are holds registered with `HoldService`; the owner emits its own events from `on_complete` and `on_cancel`, and hidden state is excluded from views.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Builds on `HoldService`, `Interactable`, `set_barred`; hiding-spot positions come from the facility map data.

**Control Manifest Rules (this layer)**:
- Required: owners register interactables and handle `on_complete` / `on_cancel`; the occupant set is server state, published as hidden state (ADR-0008, ADR-0004)
- Forbidden: never let a hold decide occupancy on the client; fake holds take no lock
- Guardrail: Every value is read from `DefenseKnobs` (`data/knobs/defense.tres`), none hardcoded.

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-defense.md` (Detailed Design and Acceptance Criteria), scoped to this story:*

- [ ] Entering takes `hide_transition_s` (1.0 s) rooted, reset on cancel; the survivor stays targetable until hidden; one occupant per spot (rules 18-20, 28a).
- [ ] A hidden survivor cannot be lunged, shot, use items, do objectives or rescues, and keeps charges and flashlight (rules 20, 23).
- [ ] Searching an occupied spot for `search_duration_s` ejects the survivor in front of it without a down; an empty spot does nothing; a stun interrupts the search (rules 15, 22).
- [ ] A search on a spot being entered lets the entry finish first, then ejects (edge case); only Healthy survivors can hide.

---

## Implementation Notes

- Spots are `Interactable`s with `roots_actor` true, reset on cancel, exclusive lock per spot (table in rule 28a).
- Resetting the Controller's held flinch offset on entry is owned by the Controller; only call its existing hook if present.
- Re-run `disguise_gates_test.gd`: its hide and search fixtures are replaced by these.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 010: noise and the long-hide cue
- Story 011: peek view presentation

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: Integration: `tests/integration/survivor-defense/hiding_spots_test.gd`. Re-run: `tests/integration/borrowed-face/disguise_gates_test.gd` (hiding and search rows).

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001, 004
- Unlocks: Stories 010, 012
