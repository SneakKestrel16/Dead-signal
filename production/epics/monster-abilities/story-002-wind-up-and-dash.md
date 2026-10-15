# Story 002: Lunge wind-up root and dash

> **Epic**: Monster Abilities
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: —

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

- [ ] The wind-up begins on accepted activation and the dash begins `lunge_windup_s` (0.6 s) later
- [ ] During wind-up the monster does not move and its facing changes by no more than 15 deg/s
- [ ] During the dash its facing changes by no more than 30 deg/s and it travels `lunge_distance_m` (4 m) over `lunge_dash_s` (0.3 s) along its facing at wind-up end
- [ ] A dash whose path meets a wall, a closed or barricaded door, or the body of a survivor who is not a valid target stops at the obstacle and resolves as a miss

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

*N/A — no qa-lead specs at this tier (lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/monster-abilities/lunge_movement_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: Stories 003, 004
