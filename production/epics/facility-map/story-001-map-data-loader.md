# Story 001: Facility map data and whole-level load

> **Epic**: Facility Map
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

The facility is one hand-authored level, loaded whole. Everything gameplay reads from it (rooms, doors and swing boxes, volumes, spawns, hiding points, switches, cameras, candidate markers) comes from one map data resource, never from runtime geometry generation.

**GDD**: `design/levels/research-facility.md`
**Requirement**: `TR-facility-001`, `TR-facility-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Movement, physics and collision layers
**ADR Decision Summary**: Gameplay zones, doors and interactables are analytic from map data; interactables get net ids `0..N-1` in map order (ADR-0008 §2).
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `Resource` and `.tres` stable since 4.0; load by fixed `res://` path (ADR-0006).

**Control Manifest Rules (this layer)**:
- Required: gameplay zones and interactables are analytic from map data
- Forbidden: `Area3D` for gameplay zones or interactables on a physics layer

---

## Acceptance Criteria

*From `research-facility.md` Acceptance Criteria 6, Spawn Points and Technical Notes, scoped to this story:*

- [ ] The map data loads whole at round start and lists every room and corridor volume, door (with swing box and barricadable flag), spawn S1–S5 and M1–M3, hiding point, switch, camera and candidate marker in the level doc.
- [ ] Wall, door and room layout is identical across 10 rounds (data digest and geometry node count compared); only candidate activation differs.
- [ ] Interactables register in map order and get the same net ids on host and client.
- [ ] Every shapeshifter spawn M1–M3 is at least 25 m of walking from A1 and out of A1's line of sight (checked against the data).

---

## Implementation Notes

*Derived from ADR-0007 §9–10 and `research-facility.md` Technical Notes:*

- The slice generated geometry from the ASCII sketch (`prototypes/dead-signal-vertical-slice/map_builder.gd`); production uses an authored scene plus map data. Reference only, never copy.
- `MapData` resource with typed arrays; `MapQueries` serves lookups.

---

## Out of Scope

- Story 002: greybox geometry
- Candidate selection (Stories 007, 008)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/facility-map/map_data_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: data-config story 002
- Unlocks: Stories 002–006
