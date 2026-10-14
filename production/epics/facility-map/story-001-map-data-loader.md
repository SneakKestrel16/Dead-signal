# Story 001: Facility map data and whole-level load

> **Epic**: Facility Map
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 1.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

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

- [x] The map data loads whole at round start and lists every room and corridor volume, door (with swing box and barricadable flag), spawn S1–S5 and M1–M3, hiding point, switch, camera and candidate marker in the level doc.
- [x] Wall, door and room layout is identical across 10 rounds (data digest and geometry node count compared); only candidate activation differs.
- [x] Interactables register in map order and get the same net ids on host and client.
- [x] Every shapeshifter spawn M1–M3 is at least 25 m of walking from A1 and out of A1's line of sight (checked against the data).

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

*From `production/qa/qa-plan-sprint-002-2026-10-13.md` (/qa-plan, 2026-10-13). Implement against these and the Acceptance Criteria above.*

**What to test**:
- The map data loads whole at round start and lists every room and corridor volume, door (swing box, barricadable flag), spawn S1–S5 and M1–M3, hiding point, switch, camera and candidate marker in the level doc (counts against the level doc table).
- Across 10 loads, the layout digest and geometry node count are identical; only candidate activation differs.
- Interactables register in map order and get the same net ids on host and client (two SceneMultiplayer subtrees).
- Every M1–M3 spawn is at least 25 m of walking from A1 and out of A1's line of sight, checked against the data.

**Edge cases to cover**:
- A missing marker type in the data fails the load with a named error.
- A duplicate marker id fails the load.

**Estimated test count**: ~7 integration tests

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/facility-map/map_data_test.gd` — must exist and pass

**Status**: [x] `tests/integration/facility-map/map_data_test.gd` passes (16 tests). 6 mutants were caught: each load error, the map order and the digest fields. Suite 230/230 (2026-10-14).

---

## Dependencies

- Depends on: data-config story 002
- Unlocks: Stories 002–006

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: 4/4 passing. Each has a declared partial; all are tracked in TD-008.
- AC1: counts and rooms are pinned against the level doc tables.
- AC2: the map data digest is identical across 10 uncached loads. The geometry node count half waits for story 002 (greybox).
- AC3: net ids are list indices in map order (doors, then interactable markers). Two loads give identical ids, which is what two peers loading the same file get. This is not run through two SceneMultiplayer subtrees.
- AC4: M1, M2 and M3 walk 45.8, 51.6 and 41.6 m from the nearest A1 exit (lower bounds over passage centres). Sight is checked at room level: no M room is A1 or opens onto it. This agrees with A1's row of the doc's visibility table. The full sightline check is story 005.
**Deviations**:
- The data was generated once from the doc's ASCII sketch by `tools/level/sketch_to_map.py`. The script records every derivation. Door width 1.0 m and a both-sides swing box are inference; the greybox settles them.
- There is no RoundServer wiring: RoundServer is Foundation. `MapData.load_map()` is the round-start entry point. Refusing a broken map is the Core composer's job (TD-008).
- The doc's Technical Notes say "about 26 doors and archways". The connectivity graph gives 29 passages: 24 doors, 2 archways, 2 open junctions and 1 exit. The doc is the designer's to update.
**Code review**: godot-specialist and qa-tester; nothing blocking. Applied:
- Three sketch columns misread (the A4-A5 door, the A5-H-S door, P2) were corrected and the data regenerated.
- `errors()` now rejects overlapping volumes.
- The usage note now says to pass net ids as ints.
- The first marker's net id and the last net id are now pinned.
Noted for later: a point exactly on the outer east or south wall is in no volume (half-open boxes).
**Gotcha**: `CACHE_MODE_IGNORE_DEEP` reloads the class's own script (gotchas.md).
**Test Evidence**: Integration: `tests/integration/facility-map/map_data_test.gd`.
