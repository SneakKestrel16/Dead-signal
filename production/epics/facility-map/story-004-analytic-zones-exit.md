# Story 004: Analytic zones, terminal zone and exit gating

> **Epic**: Facility Map
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

The terminal zone, exit volume, spawn rooms and door swing areas are point-in-box tests from map data. The exit stays shut until the server says activation is complete.

**GDD**: `design/levels/research-facility.md`
**Requirement**: `TR-facility-009`, `TR-facility-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Movement, physics and collision layers (primary); ADR-0004: Replication scope and information hiding
**ADR Decision Summary**: Zones are analytic boxes from map data (point-in-box); door state and exit state are server-owned and replicated; clients never change them locally.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No `Area3D` for gameplay zones.

**Control Manifest Rules (this layer)**:
- Required: gameplay zones are analytic from map data
- Forbidden: `Area3D` for gameplay zones

---

## Acceptance Criteria

*From `research-facility.md` Acceptance Criteria 10 and Technical Notes (server authority), scoped to this story:*

- [ ] `MapQueries.zone_at(point)` returns the right zone for points inside, on the edge and outside the terminal zone, exit volume and each spawn room.
- [ ] Exit E stays closed until the server reports activation complete; an early interact from 5 clients opens it 0 times.
- [ ] Door open, closed and barricaded state is server-owned and every client shows the server's state after a toggle.

---

## Implementation Notes

*Derived from ADR-0007 §8–9:*

- Activation complete comes from Survivor Objectives; drive it from a stub here.

---

## Out of Scope

- Terminal activation rules (Survivor Objectives epic)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/facility-map/zones_exit_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001; controller-interaction story 012
- Unlocks: Survivor Objectives, Match Flow epics
