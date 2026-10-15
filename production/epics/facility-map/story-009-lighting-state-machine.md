# Story 009: Per-volume lighting state machine and precedence

> **Epic**: Facility Map
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15


## Context

Each lighting volume has a base state from the round (Low Power, Investigation, Power Restored, Evacuation) and overlays such as Blackout. The server resolves precedence; clients only show it.

**GDD**: `design/levels/research-facility.md`
**Requirement**: `TR-facility-004`, `TR-facility-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009: Lighting states and Blackout (Proposed)
**ADR Decision Summary**: Server-owned per-volume lighting state with base states and overlays, precedence rules and a reset on `RoundEnded`.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Per ADR-0009 once Accepted.

**Control Manifest Rules (this layer)**:
- Required: (Proposed) rules per ADR-0009 — re-check the control manifest once it is Accepted

---

## Acceptance Criteria

*From `research-facility.md` Lighting States, Edge Cases and Acceptance Criteria 12, scoped to this story:*

- [x] Terminal armed during Infiltration goes Power Restored straight to Evacuation; the Investigation flicker never plays.
- [x] A Blackout in a room when Power Restored lands keeps it dark for the rest of the Blackout, then shows Power Restored; in the active terminal room Evacuation ends the Blackout at once, elsewhere it runs out first.
- [x] Both fuses, then Evacuation, then a Blackout in a Zone B room: the room is dark with emergency strips; when the Blackout ends it shows Evacuation, not Power Restored.
- [x] After `RoundEnded` every volume is Low Power with no overlays.

---

## Implementation Notes

*Derived from ADR-0009 (Proposed) and `research-facility.md` Lighting States:*

- Pure state logic per volume; rendering is Story 010.

---

## Out of Scope

- Story 010: rendering and replication

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/facility-map/lighting_state_test.gd` — must exist and pass

**Status**: [x] `tests/unit/facility-map/lighting_state_test.gd` (9 tests)

---

## Dependencies

- Depends on: Story 001; ADR-0009 Accepted
- Unlocks: Story 010; Monster Abilities (Blackout), Scare Events epics

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-203):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 1076/1076 after the wave merge, no leak warnings.
- New slot FACILITY_LIGHTING 460 because FACILITY_MAP 450 is taken by Doors (one module per slot); composer must register it there.
- Named FacilityLighting, not the ADR's FacilityMap (Doors owns the rest); registry owner string kept &"FacilityMap".
- View getters are get_base, get_overlays, is_dark, is_blackout_able (getter-only test prefix rule), not the ADR's names; volumes are StringName ids, not int.
- Feature enum values copied as constants (Core may not name Feature classes); a test fails on drift.
- objective_volume(objective) injected; composer must supply it. Exit-open overlay on the exit's inside room C4 (inference). Blackout also refused here for non-blackout_able volumes.
- No verification spike: ADR-0009's Verification Required items are rendering (story 010).
**Test Evidence**: 9 tests; red run was a parse error before the code existed. Mutations caught: base not forward-only, Evacuation not ending terminal-room Blackout, expiry >= to >, reset not clearing overlays.
**Code Review**: Complete (orchestrator review at merge)
