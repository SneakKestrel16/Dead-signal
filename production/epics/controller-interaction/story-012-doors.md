# Story 012: Doors: instant toggle and swing-area close check

> **Epic**: First-Person Controller & Interaction
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

## Context

Doors open and close instantly on interact. A close is refused while anyone stands in the swing area, so nobody is shoved through walls and a disguised shapeshifter can visibly hold a door.

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-controller-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Movement, physics and collision layers
**ADR Decision Summary**: §5: one `StaticBody3D` blocker per door on layer `doors`, shape enabled while closed and disabled while open; §8: a close is rejected while any player capsule overlaps the swing box from Facility Map data, tested analytically.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Verification (7): disabling a shape is seen by later queries in the same physics frame; a moved body is not.

**Control Manifest Rules (this layer)**:
- Required: gameplay zones and interactables are analytic from map data
- Required: use `set_deferred` only inside physics callbacks
- Forbidden: `Area3D` for gameplay zones

---

## Acceptance Criteria

*From `first-person-controller.md` Acceptance Criteria (door) and rule 18, Edge Cases (lunge), scoped to this story:*

- [x] A close requested while a capsule overlaps the swing area is rejected; with the area clear the door toggles on the same tick.
- [x] During a lunge dash (stub dash mover), close is rejected only if the dashing capsule is already in the swing area; otherwise the door closes.
- [x] The door blocker shape is enabled exactly while the door is closed, and both server movement and client prediction collide with it from replicated door state.

---

## Implementation Notes

*Derived from ADR-0007 Decision §5, §8 and ADR-0008 §2 (doors are instant interactables):*

- Doors register as instant interactables (`duration_s` 0) through `HoldService`.
- Swing boxes come from Facility Map data; use a fixture door in the test.
- Barricade state on doors belongs to Survivor Defense.

---

## Out of Scope

- Barricades (Survivor Defense epic)
- The lunge itself (Monster Abilities epic)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/first-person-controller/doors_test.gd` — must exist and pass

**Status**: [x] `tests/integration/first-person-controller/doors_test.gd`

---

## Dependencies

- Depends on: Stories 001, 008
- Unlocks: facility-map, Survivor Defense epics

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: all passing (automated)
**Deviations** (AD-142):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 748/748 after the wave merge, no leak warnings.
- `MapQueries.capsule_overlaps_swing` (ADR-0007 interface); touching is not overlap.
- Door state is not sent over the network yet: AC3 is tested by applying `closed_states()` to a blocker in a separate world.
- Barricades and shock-lock eligibility are not here (Survivor Defense; injected `eligible` defaults to anyone). No catalog event on toggle (none exists).
**Test Evidence**: Mutations caught: swing `<` to `<=`, swing check removed from toggle, blocker logic inverted.
**Code Review**: Complete (orchestrator review at merge)
