# Story 001: Ability requests and Lunge state machine

> **Epic**: Monster Abilities
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

A new `MonsterAbilities` module (`src/feature/monster_abilities/monster_abilities.gd`) owns the request path and the Lunge state machine. Borrowed Face 005 tests use a `StubAbilities` request handler that this module replaces (story 006). The module reads form and Transforming from Borrowed Face views, takedown eligibility from Downing, and knobs from the existing `AbilityKnobs`.

**GDD**: `design/gdd/monster-abilities.md`
**Requirement**: `TR-monster-001`, `TR-monster-002`, `TR-monster-005`, `TR-monster-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Authoritative simulation, tick rate and input; secondary: ADR-0005, ADR-0006
**ADR Decision Summary**: Client sends an activation request and aim point only; the server validates and owns cooldown and state. Invalid requests have no effect and no cooldown cost. Fixed tick for the dodge simulation.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Plain GDScript on the server tick; no post-cutoff APIs. Request packets follow the existing `BorrowedFace.request_packet` pattern.

**Control Manifest Rules (this layer)**:
- Required: run in the MonsterAbilities slot via `server_tick(tick)` registered with `TickRunner` (ADR-0002, ADR-0005); every number from `AbilityKnobs` (ADR-0006)
- Forbidden: never emit an event from a client (ADR-0005); no literal for a tuning knob in ability code
- Guardrail: the dodge-window values are coupled; rerun the steering check after changing wind-up, turn rates, dash, radius or cone

---

## Acceptance Criteria

*From GDD `design/gdd/monster-abilities.md`, scoped to this story:*

- [x] Server rejects a lunge during cooldown, while Disguised, while Stunned, under the shock lock, or while Transforming; a rejection has no effect and costs no cooldown
- [x] While a lunge is in wind-up, Active or takedown commit, False Signal and Blackout requests are rejected with no cooldown cost (guard in place now; those abilities arrive in stories 009-010)
- [x] The Lunge state machine Ready, Wind-up, Active, Takedown Commit, Resolved, Cooldown exists with the GDD entry and exit conditions
- [x] Using one ability does not change the other abilities' cooldowns or the form-change cooldown
- [x] No ability code contains a literal for an `AbilityKnobs` parameter

---

## Implementation Notes

- Create `MonsterAbilities` as a `RefCounted` with `setup(tick_runner, bus, registry, knobs)` like `Downing` and `BorrowedFace`; inject form, transforming, stun and shock-lock sources as Callables (see `BorrowedFace.set_status_source` / `set_attack_source`).
- Request decoding mirrors `BorrowedFace.request_packet` / `decode_request`. Only an ability id and an aim point cross the wire.
- Stun and shock lock come from Survivor Defense events (`MonsterStunned`, `PlayerShocked`); Survivor Defense has no code yet, so tests emit them directly as the Downing tests do.
- Cooldowns are per-ability ready-ticks; the Lunge cooldown starts at resolution (story 004), not here.

---

## Out of Scope

- Story 002: wind-up and dash movement
- Story 003: hit test
- Story 004: resolution, cooldown start and miss slow
- Stories 009-010: False Signal and Blackout bodies

---

## QA Test Cases

*Test specs from `/qa-plan sprint` (`production/qa/qa-plan-sprint-006-2026-10-15.md`). Tests emit the other epic's events directly until MA-6 and SD-12 re-run against both real modules.*

**Test file path**: `tests/unit/monster-abilities/request_validation_test.gd`

- **AC-1**: Rejections cost nothing
  - Given: a monster in cooldown, then Disguised, Stunned, shock-locked, Transforming
  - When: a lunge request arrives
  - Then: rejected, no state change, cooldown value unchanged
  - Edge cases: request on the exact tick cooldown ends; two rejection reasons at once
- **AC-2**: False Signal and Blackout guard
  - Given: a lunge in wind-up, Active, then takedown commit
  - When: a False Signal or Blackout request arrives
  - Then: rejected with no cooldown cost in all three states
  - Edge cases: request on the tick the lunge resolves
- **AC-3**: State machine
  - Given: an accepted lunge
  - When: the machine is stepped through every transition
  - Then: Ready, Wind-up, Active, Takedown Commit, Resolved, Cooldown in GDD order; no illegal jump
  - Edge cases: a miss skips Takedown Commit
- **AC-4**: Cooldown independence
  - Given: a lunge used
  - When: the other ability and form-change cooldowns are read
  - Then: unchanged
  - Edge cases: lunge used on the tick a form change completes
- **AC-5**: No knob literals
  - Given: the module source
  - When: scanned for numeric literals matching `AbilityKnobs` values
  - Then: none found
  - Edge cases: fails if a literal 0.6 / 4 / 10 is added

**Estimated test count**: ~8 tests

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/monster-abilities/request_validation_test.gd` — must exist and pass

**Status**: [x] `tests/unit/monster-abilities/request_validation_test.gd` (12 tests)

---

## Dependencies

- Depends on: None (builds on existing Borrowed Face, Downing, `AbilityKnobs`)
- Unlocks: Stories 002, 005

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-183):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 954/954 after the wave merge, no leak warnings.
- Lunge cooldown set at resolution in this story (needed for AC-1); story 004 owns the miss slow and its cooldown tests.
- Stun and shock lock read through one `locked(player)` Callable (StateKeys.SHOCK_STUN_LOCK stand-in); MonsterStunned only interrupts a lunge.
- Takedown commit ends on any SurvivorDowned/SurvivorEliminated while committing (events don't name the monster; inference). `Downing.committing()` not wired yet.
- False Signal and Blackout validated but have no effect yet. `on_lunge_state(state, tick)` hook added for the transition-order test.
- Uncaught mutation: a cooldown written as a tick literal (+600) passes the knob-literal scan (it compares seconds).
- Module written just before the test file; mutations stand in for the red run.
**Test Evidence**: 12 tests. Mutations caught: lunge-in-progress guard dropped, cooldown one tick late, true-form check dropped, knob-literal scan.
**Code Review**: Complete (orchestrator review at merge)
