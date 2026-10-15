# Story 002: Lunge wind-up root and dash

> **Epic**: Monster Abilities
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

The Lunge moves the monster: a rooted wind-up with a capped turn rate, then a 4 m dash with limited steering. Movement is a controller modifier, not a separate mover, so it composes with the miss slow (story 004).

**GDD**: `design/gdd/monster-abilities.md`
**Requirement**: `TR-monster-002`, `TR-monster-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Movement, physics and collision layers; secondary: ADR-0002
**ADR Decision Summary**: Wind-up root, turn caps, dash steering and the miss slow are controller modifiers on `ServerMovement`; walls, closed doors and other bodies block the dash on the physics layers.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Jolt is the default physics engine since 4.6; dash obstacle queries run only in TickRunner physics phases. Verify against `docs/engine-reference/godot/modules/physics.md`.

**Control Manifest Rules (this layer)**:
- Required: run in the MonsterAbilities slot via `server_tick(tick)` registered with `TickRunner` (ADR-0002, ADR-0005); every number from `AbilityKnobs` (ADR-0006)
- Forbidden: never emit an event from a client (ADR-0005); no literal for a tuning knob in ability code
- Guardrail: the dodge-window values are coupled; rerun the steering check after changing wind-up, turn rates, dash, radius or cone

---

## Acceptance Criteria

*From GDD `design/gdd/monster-abilities.md`, scoped to this story:*

- [x] The wind-up begins on accepted activation and the dash begins `lunge_windup_s` (0.6 s) later
- [x] During wind-up the monster does not move and its facing changes by no more than 15 deg/s
- [x] During the dash its facing changes by no more than 30 deg/s and it travels `lunge_distance_m` (4 m) over `lunge_dash_s` (0.3 s) along its facing at wind-up end
- [x] A dash whose path meets a wall, a closed or barricaded door, or the body of a survivor who is not a valid target stops at the obstacle and resolves as a miss

---

## Implementation Notes

- Use `ServerMovement.modifiers_of(player)` / `MovementModifiers` (`src/foundation/network/server_movement.gd`) for the root and forced dash velocity; do not move the body from the ability module.
- Obstacle test uses the layers in `src/core/controller/physics_layers.gd`. Another survivor's body stops the dash unless that survivor is a valid target and takes the hit (story 003).
- Run the dash per server tick, steering clamped by `lunge_dash_turn_deg_s * dt`.

---

## Out of Scope

- Story 003: choosing a hit survivor
- Story 004: miss slow after the dash

---

## QA Test Cases

*Test specs from `/qa-plan sprint` (`production/qa/qa-plan-sprint-006-2026-10-15.md`). Tests emit the other epic's events directly until MA-6 and SD-12 re-run against both real modules.*

**Test file path**: `tests/integration/monster-abilities/lunge_movement_test.gd`

- **AC-1**: Wind-up timing
  - Given: an accepted activation at tick T
  - When: ticks advance
  - Then: dash begins at T + 0.6 s (`lunge_windup_s`)
  - Edge cases: one tick either side of the boundary
- **AC-2**: Wind-up root and turn cap
  - Given: the monster in wind-up with held move input and a fast turn input
  - When: positions and facing are sampled each tick
  - Then: position fixed; facing change <= 15 deg/s
  - Edge cases: input exactly at the cap
- **AC-3**: Dash distance and turn cap
  - Given: wind-up ended in open floor
  - When: the 0.3 s dash runs
  - Then: travels 4 m along the facing at wind-up end; facing change <= 30 deg/s
  - Edge cases: tick quantisation of 0.3 s
- **AC-4**: Obstacle stops the dash
  - Given: a wall, a closed door, a barricaded door, a non-target survivor body on the path
  - When: the dash runs into each
  - Then: stops at the obstacle and resolves as a miss
  - Edge cases: obstacle at 0 m and at exactly 4 m

**Estimated test count**: ~6 tests

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/monster-abilities/lunge_movement_test.gd` — must exist and pass

**Status**: [x] `tests/integration/monster-abilities/lunge_movement_test.gd` (13 tests)

---

## Dependencies

- Depends on: Story 001
- Unlocks: Stories 003, 004

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-186):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 976/976 after the wave merge, no leak warnings.
- The step edits the server copy of the frame's yaw, so ViewState reports the capped yaw during a lunge; its doc comment ('no gameplay state turns the view') is now stale.
- Turn cap and dash are not in snapshots: the monster's own client is corrected, not predicted (inference; a playtest of the monster view settles it).
- A barricade is assumed to keep the door's DOORS-layer blocker on (SD-7 does this via held-shut doors).
- The dash has no gravity or sliding, so a ramp or step stops it (ponytail comment).
- Merge conflict with MA-5 in monster_abilities.gd (both additive) resolved by keeping both. Commit hook flagged possible hardcoded values; the knob-literal scan passes.
**Test Evidence**: 13 tests. Mutations caught: yaw clamp removed, blocked-dash resolve removed, speed from lunge_dash_s not whole ticks, wind-up root removed.
**Code Review**: Complete (orchestrator review at merge)
