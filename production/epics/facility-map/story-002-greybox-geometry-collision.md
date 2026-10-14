# Story 002: Greybox geometry and collision authoring

> **Epic**: Facility Map
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

The greybox must respect the controller's limits so nothing snags: wide doorways, ramp colliders on every step, large box floors, glass on its own layer and LOS blockers where the level doc wants them.

**GDD**: `design/levels/research-facility.md`
**Requirement**: `TR-facility-002`, `TR-facility-007`, `TR-facility-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Movement, physics and collision layers
**ADR Decision Summary**: Layers `world`, `glass`, `doors`, `players`; one `StaticBody3D` blocker per door; ramp colliders ≤ 40° for steps up to 0.35 m; large box floors against seam snagging; no `WorldBoundaryShape3D`.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Verification (6) PASS: no seam snag with large floor boxes on Jolt. Verification (9): `floor_max_angle` 40.0° blocks 41°.

**Control Manifest Rules (this layer)**:
- Required: climb steps through ramp colliders
- Forbidden: inline layer numbers [inline_layer_numbers]; `WorldBoundaryShape3D`

---

## Acceptance Criteria

*From `research-facility.md` Dimensions and Traversal (Geometry limits) and Acceptance Criteria 1, scoped to this story:*

- [ ] A test over the scene fails if any doorway or archway is narrower than 0.8 m clear, any step above 0.35 m lacks a ramp collider, or any ramp exceeds 40°.
- [ ] Every collider is on `world`, `glass` or `doors` through `PhysicsLayers`; glass partitions are on `glass` only.
- [ ] LOS blockers named in the level doc are on `world`, so `SIGHT` rays stop at them (spot-checked by ray tests at three blockers).
- [ ] A walk-through confirms every room in the Zones and Rooms table has at least two traversable exits (retained screenshots of the greybox).

---

## Implementation Notes

*Derived from ADR-0007 §4–5 and `research-facility.md` Geometry limits:*

- Greybox primitives only; art is a later pass.

---

## Out of Scope

- Art pass

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-003-2026-10-14.md` (/qa-plan, 2026-10-14). Implement against these and the Acceptance Criteria above.*

**What to test**:
- Over the greybox scene: every doorway and archway in map data is ≥ 0.8 m clear; every step > 0.35 m has a ramp collider; no ramp exceeds 40°. Each failure names the passage or step.
- Every collider is on `world`, `glass` or `doors` via `PhysicsLayers` constants; glass partitions on `glass` only.
- No `WorldBoundaryShape3D` in the scene; one `StaticBody3D` blocker per door.
- `SIGHT` ray tests at three LOS blockers named in the level doc: the ray stops at each.
- Closes FM-1 AC2's geometry-node-count half: assert the node count matches map data.

**Edge cases to cover**:
- A step exactly 0.35 m without ramp passes; 0.36 m without ramp fails.
- A ramp at exactly 40° passes; 41° is blocked by `floor_max_angle` (ADR-0007 Verification 9).
- Seam snagging: a capsule walked across adjacent floor boxes does not stop (ADR-0007 Verification 6).

**Estimated test count**: ~7 integration tests

**Manual checks**:

**Verification method**: Screenshot + designer sign-off
**Who must sign off**: designer (level-designer review)
**Evidence to capture**: retained screenshots in `production/qa/evidence/` (overview per zone, plus each room's exits)

- [ ] Every room in the Zones and Rooms table shows at least two traversable exits.
- [ ] A capsule walked through every doorway does not snag.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/facility-map/greybox_geometry_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001; controller-interaction story 001
- Unlocks: Stories 003, 009
