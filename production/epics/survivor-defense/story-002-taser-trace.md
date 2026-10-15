# Story 002: Taser trace along the view ray with rewind

> **Epic**: Survivor Defense
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Turns a validated fire intent into a hit: after `stun_use_delay_s` the server traces from the shooter's view, finds the first body in `stun_range_m` within `stun_aim_tolerance_deg`, skipping Seized and Downed survivors, and returns who was hit. It applies nothing yet; stories 003 and 004 act on the result.

**GDD**: `design/gdd/survivor-defense.md`
**Requirement**: `TR-defense-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Lag compensation and rewind; secondary: ADR-0007
**ADR Decision Summary**: Every server hit test, lunge and taser alike, goes through `LagCompensation.targets_at` with positions rewound to the shooter's view tick, capped at `max_rewind_ms` (180).
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Uses `LagCompensation` and `RewindHistory`; physics queries run in the server tick only. Glass blocks the dart (projectile mask `world | glass`, GDD open question, ADR-0007 default).

**Control Manifest Rules (this layer)**:
- Required: all hit tests use `LagCompensation` (ADR-0003); trace on the server only (ADR-0002)
- Forbidden: never trust a client-reported hit or position; never rewind beyond `max_rewind_ms`
- Guardrail: Every value is read from `DefenseKnobs` (`data/knobs/defense.tres`), none hardcoded.

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-defense.md` (Detailed Design and Acceptance Criteria), scoped to this story:*

- [x] The shot hits the first body within `stun_range_m` (5 m) inside the aim tolerance; at 5.1 m or outside 10 degrees it hits nothing, and one cartridge is still consumed (rule 8).
- [x] A survivor standing in front of the monster is the hit; the monster behind is not (rule 8, edge case).
- [x] Seized and Downed survivors are skipped: the shot passes through and the monster behind is hit (rule 8).
- [x] The shot resolves against positions rewound to the shooter's view tick, the same path as the lunge test, and a target that moved after that tick is still hit (rule 8).

---

## Implementation Notes

- `SurvivorDefense` queues the shot for `stun_use_delay_s`, then calls `targets_at(view_tick, rewind, ids)` and picks the nearest body on the ray.
- Seized/Downed come from `Downing` status; hidden survivors are not bodies (story 006).
- Return a result dictionary (hit id or -1, reason in {hit, missed, blocked, range}) so the failure texture in Game Feel can be shown later.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: shocking a hit survivor
- Story 004: stunning the monster
- Story 005: what clients are told

---

## QA Test Cases

*Test specs from `/qa-plan sprint` (`production/qa/qa-plan-sprint-006-2026-10-15.md`). Tests emit the other epic's events directly until MA-6 and SD-12 re-run against both real modules.*

**Test file path**: `tests/unit/survivor-defense/taser_trace_test.gd`

- **AC-1**: Range and aim
  - Given: a target at 5.0 m inside tolerance, 5.1 m, and outside 10 degrees
  - When: a shot is fired at each
  - Then: first hits; others hit nothing and still consume a cartridge
  - Edge cases: exactly 10 degrees; exactly 5 m
- **AC-2**: Blocking order
  - Given: a survivor in front of the monster
  - When: a shot is fired
  - Then: the survivor is hit; the monster is not
  - Edge cases: two survivors in line
- **AC-3**: Skipped bodies
  - Given: a Seized and a Downed survivor in front of the monster
  - When: a shot is fired
  - Then: passes through; the monster behind is hit
  - Edge cases: all bodies skipped and nothing behind
- **AC-4**: Rewind
  - Given: a target that moved after the shooter's view tick
  - When: a shot is fired
  - Then: still hit at the rewound position; same path as the lunge test
  - Edge cases: `view_tick` unset clamps to the cap (NA-7)

**Estimated test count**: ~7 tests

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: Logic: `tests/unit/survivor-defense/taser_trace_test.gd`

**Status**: [x] `tests/unit/survivor-defense/taser_trace_test.gd` (10 tests)

---

## Dependencies

- Depends on: Story 001
- Unlocks: Stories 003, 004

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-180):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 954/954 after the wave merge, no leak warnings.
- Bug caught in development: `Downing.action_locked` is also true for the monster during a takedown, so the pass-through skip applies to survivors only (the rescuer's shot must reach the monster).
- Range measured to the target's nearest capsule-axis point so the AC's 5.1 m case misses (inference). Aim: angle <= 10 degrees or ray within capsule radius.
- Walls and doors via an injected `blocked(from, to)`; composer must wire PROJECTILE-mask ray plus door leaves (MapQueries.clear_sight uses SIGHT).
- A shooter Seized during the 0.2 s delay still resolves the shot (GDD silent).
- Implementation written before the test file; mutations stand in for the red run.
**Test Evidence**: 10 tests. Mutations caught: Seized/Downed skip removed, rewind 0, range loosened 0.2 m.
**Code Review**: Complete (orchestrator review at merge)
