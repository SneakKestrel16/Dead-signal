# Story 006: Traversal budget walk-through

> **Epic**: Facility Map
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

The round's pacing assumes any room is within 20 s of any other at walk speed. A scripted walker checks the two longest routes in the real greybox.

**GDD**: `design/levels/research-facility.md`
**Requirement**: `TR-facility-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Movement, physics and collision layers
**ADR Decision Summary**: Shared movement step; capsule 0.30 m radius.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Run with the real movement step and Jolt, headless.

**Control Manifest Rules (this layer)**:
- Required: one movement step function shared by server and owning client

---

## Acceptance Criteria

*From `research-facility.md` Acceptance Criteria 7 and `first-person-controller.md` AC (Facility Map), scoped to this story:*

- [ ] A scripted walker at `walk_speed` 4.0 following the route-table waypoints takes ≤ 20 s from A1 to the C4 exit and ≤ 20 s from A6 to C3 (expected about 17 s and 18 s).
- [ ] The walker never stalls at a doorway on either route (no tick with speed under half the walk speed while input is held, outside turns).

---

## Implementation Notes

*Derived from `research-facility.md` Dimensions and Traversal:*

- Waypoints live in test data, not the map data.

---

## Out of Scope

- Playtest pacing (Grouping AC 11, Match Telemetry epic)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/facility-map/traversal_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002; controller-interaction story 002
- Unlocks: none
