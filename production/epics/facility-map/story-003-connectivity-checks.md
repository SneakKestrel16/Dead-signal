# Story 003: Connectivity checks: no sealed rooms, no single choke

> **Epic**: Facility Map
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

## Context

Barricades and blocked doors must never cut the map in two. These checks run on the connectivity graph from the map data, so they are cheap and run on every map change.

**GDD**: `design/levels/research-facility.md`
**Requirement**: `TR-facility-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR: N/A — graph checks over authored map data, no architectural pattern required
**ADR Decision Summary**: N/A.
**ADR Version**: N/A

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Plain GDScript over `MapData`.

**Control Manifest Rules (this layer)**:
- Required: tests are deterministic

---

## Acceptance Criteria

*From `research-facility.md` Acceptance Criteria 1, 2, 3, scoped to this story:*

- [x] Every room in the Zones and Rooms table has at least two exits in the graph.
- [x] With all five barricadable doors barricaded, H-N reaches C4 and every other room.
- [x] Blocking each single edge into Zone B in turn (A4-B1, B2-H-N, B3-H-S, B1-C2), B1 stays reachable from A1.

---

## Implementation Notes

*Derived from `research-facility.md` Connectivity Graph:*

- Breadth-first search over door edges; barricaded = edge removed.

---

## Out of Scope

- Walk-through checks (Story 002)

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-003-2026-10-14.md` (/qa-plan, 2026-10-14). Implement against these and the Acceptance Criteria above.*

**What to test**:
- Every room in the Zones and Rooms table has ≥ 2 exits in the graph.
- All five barricadable doors barricaded: H-N reaches C4 and every other room.
- Blocking A4-B1, B2-H-N, B3-H-S, B1-C2 one at a time: B1 stays reachable from A1.

**Edge cases to cover**:
- A synthetic map with a sealed room fails the check (proves the check can fail).

**Estimated test count**: ~4 unit tests

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/facility-map/connectivity_test.gd` — must exist and pass

**Status**: [x] Created and passing (6 tests, 2026-10-14)

---

## Dependencies

- Depends on: Story 001
- Unlocks: none
