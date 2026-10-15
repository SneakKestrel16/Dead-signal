# Story 004: Lunge resolution, cooldown and miss slow

> **Epic**: Monster Abilities
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: —

## Context

A lunge ends in Resolved by one of four paths (commit end, dash end or obstacle, stun, disconnect). The cooldown starts at resolution and a miss slows the monster.

**GDD**: `design/gdd/monster-abilities.md`
**Requirement**: `TR-monster-002`, `TR-monster-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Movement, physics and collision layers; secondary: ADR-0005
**ADR Decision Summary**: The miss slow is a controller modifier. A stun-interrupted lunge counts as resolved and the stun replaces the slow; a disconnect ends the lunge with no hit.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Plain GDScript; modifier timing in server ticks.

**Control Manifest Rules (this layer)**:
- Required: run in the MonsterAbilities slot via `server_tick(tick)` registered with `TickRunner` (ADR-0002, ADR-0005); every number from `AbilityKnobs` (ADR-0006)
- Forbidden: never emit an event from a client (ADR-0005); no literal for a tuning knob in ability code
- Guardrail: the dodge-window values are coupled; rerun the steering check after changing wind-up, turn rates, dash, radius or cone

---

## Acceptance Criteria

*From GDD `design/gdd/monster-abilities.md`, scoped to this story:*

- [ ] A miss (including blocked by a door) slows the monster to 50% for 1.5 s; the next lunge is accepted no earlier than 10 s after resolution
- [ ] A transformation request during the miss slow is accepted when Borrowed Face rule 7 holds
- [ ] After a hit whose takedown commit completes (or is cancelled by a stun) at time T, the next lunge is rejected before T + 10 s and accepted at T + 10 s
- [ ] A stun during wind-up or the dash produces no `SurvivorHit`; the cooldown starts at the stun and no miss slow is applied
- [ ] A monster disconnect mid-lunge ends it with no hit

---

## Implementation Notes

- Resolution from Downing: read `Downing.committing()` and the commit end (`SurvivorDowned` / `SurvivorEliminated` / cancel on `MonsterStunned`); do not duplicate the 1.5 s timer.
- Miss slow via `MovementModifiers`; multiplier and duration from `AbilityKnobs`.
- Stun: subscribe to `MonsterStunned`; disconnect: `PlayerConnectionChanged`.

---

## Out of Scope

- Story 006: Downing and Borrowed Face integration checks

---

## QA Test Cases

*Test specs from `/qa-plan sprint` (`production/qa/qa-plan-sprint-006-2026-10-15.md`). Tests emit the other epic's events directly until MA-6 and SD-12 re-run against both real modules.*

**Test file path**: `tests/unit/monster-abilities/lunge_resolution_test.gd`

- **AC-1**: Miss slow and cooldown
  - Given: a lunge that hits nothing, and one blocked by a door
  - When: resolution runs
  - Then: monster at 50% speed for 1.5 s; next lunge accepted no earlier than 10 s after resolution
  - Edge cases: request at 9.99 s and 10.0 s; slow end tick
- **AC-2**: Transform during miss slow
  - Given: the miss slow active
  - When: a transformation request arrives
  - Then: accepted when Borrowed Face rule 7 holds
  - Edge cases: request on the final slow tick
- **AC-3**: Cooldown after a hit
  - Given: a hit whose commit completes at T, then one cancelled by a stun at T
  - When: a lunge is requested before and at T + 10 s
  - Then: rejected before, accepted at T + 10 s, in both cases
  - Edge cases: T + 10 s - 1 tick
- **AC-4**: Stun in wind-up or dash
  - Given: a stun during wind-up, then during the dash
  - When: resolution runs
  - Then: no `SurvivorHit`; cooldown starts at the stun; no miss slow
  - Edge cases: stun on the dash's last tick
- **AC-5**: Disconnect
  - Given: a monster disconnect mid-lunge
  - When: the event arrives
  - Then: lunge ends, no hit
  - Edge cases: disconnect on the hit tick

**Estimated test count**: ~7 tests

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/monster-abilities/lunge_resolution_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 002, 003
- Unlocks: Story 006
