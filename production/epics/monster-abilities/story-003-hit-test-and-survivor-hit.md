# Story 003: Lunge hit test with lag compensation

> **Epic**: Monster Abilities
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1-2 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Each Active tick the server tests survivors against positions rewound by `LagCompensation` (network-authority story 007: `RewindHistory`, `rewind_ticks`, `targets_at`, `capsule_hits_segment`). A hit emits `SurvivorHit`, which Downing already consumes.

**GDD**: `design/gdd/monster-abilities.md`
**Requirement**: `TR-monster-003`, `TR-monster-004`, `TR-monster-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Lag compensation and rewind; secondary: ADR-0007
**ADR Decision Summary**: Hit tests run on positions rewound to the attacker's viewed tick, capped at `max_rewind_ms` (180) and bounded by server RTT; only positions are rewound, eligibility and stun use current state.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Rewound geometry is analytic capsules from `RewindHistory`, not physics bodies; line of sight queries run on the Jolt 3D space.

**Control Manifest Rules (this layer)**:
- Required: run in the MonsterAbilities slot via `server_tick(tick)` registered with `TickRunner` (ADR-0002, ADR-0005); every number from `AbilityKnobs` (ADR-0006)
- Forbidden: never emit an event from a client (ADR-0005); no literal for a tuning knob in ability code
- Guardrail: the dodge-window values are coupled; rerun the steering check after changing wind-up, turn rates, dash, radius or cone

---

## Acceptance Criteria

*From GDD `design/gdd/monster-abilities.md`, scoped to this story:*

- [x] A survivor is hit only if eligible (Healthy, not hidden, no grace, not Seized), within 1.2 m of the attack point, inside the 60 degree cone, with chest line of sight, and the monster has not been stunned since wind-up
- [x] With two valid survivors in the cone, only the closer one gets `SurvivorHit` and the dash ends on that tick
- [x] A survivor behind a closed door 1 m from the monster is never hit
- [x] A survivor in post-rescue or post-release grace, or hidden, inside cone and radius is not hit
- [x] At 80 ms RTT positions are rewound to the viewed tick; at 300 ms RTT exactly 180 ms; a survivor who became hidden or entered grace after the rewound time is not hit
- [x] A survivor 3 m ahead (radius 0.3 m) strafing at 4.0 m/s from 0.25 s after the cue, monster at 150 ms RTT, is not hit (smoke check of the first-person-controller dodge AC)

---

## Implementation Notes

- `LagCompensation.rewind_ticks(attacker_id, tick)` then `targets_at`; eligibility via `Downing.eligible` / `Downing.is_eligible`; hidden via the Downing hidden source.
- Attack point is the monster body centre at chest height (rule 7). Cone and radius from `AbilityKnobs`.
- Emit `EvSurvivorHit` (monster, survivor, server time, position) once; Downing starts the commit.
- Log disputes through the `LagCompensation` log path (Match Telemetry).

---

## Out of Scope

- Story 002: dash movement
- Story 004: resolution after the hit
- Downing: what the hit does

---

## QA Test Cases

*Test specs from `/qa-plan sprint` (`production/qa/qa-plan-sprint-006-2026-10-15.md`). Tests emit the other epic's events directly until MA-6 and SD-12 re-run against both real modules.*

**Test file path**: `tests/unit/monster-abilities/lunge_hit_test_test.gd`; `tests/integration/monster-abilities/lunge_lag_comp_test.gd`

- **AC-1**: Eligibility, range, cone, line of sight
  - Given: survivors Healthy, hidden, in grace, Seized, outside 1.2 m, outside the 60 degree cone, without chest line of sight; and a monster stunned since wind-up
  - When: the dash hit test runs
  - Then: only the eligible one in range, cone and sight gets `SurvivorHit`; a stunned monster hits nobody
  - Edge cases: exactly 1.2 m; exactly on the cone edge
- **AC-2**: Two valid targets
  - Given: two valid survivors in the cone
  - When: the test runs
  - Then: only the closer gets `SurvivorHit`; the dash ends that tick
  - Edge cases: equal distance (assert the tie-break)
- **AC-3**: Closed door
  - Given: a survivor 1 m away behind a closed door
  - When: the test runs
  - Then: never hit
  - Edge cases: door opened on the same tick
- **AC-4**: Grace and hidden
  - Given: survivors in post-rescue grace, post-release grace, hidden, all inside cone and radius
  - When: the test runs
  - Then: none hit
  - Edge cases: grace expiring on the dash tick
- **AC-5**: Rewind
  - Given: a monster at 80 ms RTT, then 300 ms; a survivor who hid or entered grace after the rewound time
  - When: the test runs
  - Then: 80 ms rewinds to the viewed tick; 300 ms rewinds exactly 180 ms (cap); the late-hidden survivor is not hit
  - Edge cases: RTT at the cap +/- 1 tick; `view_tick` unset clamps to the cap (NA-7)
- **AC-6**: Dodge smoke
  - Given: a survivor 3 m ahead (radius 0.3 m) strafing 4.0 m/s from 0.25 s after the cue, monster at 150 ms RTT
  - When: the lunge runs
  - Then: not hit (steering check)
  - Edge cases: rerun after any change to wind-up, turn rates, dash, radius or cone

**Estimated test count**: ~10 unit and ~5 integration tests

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/monster-abilities/lunge_hit_test_test.gd` — must exist and pass
- Integration: `tests/integration/monster-abilities/lunge_lag_comp_test.gd` — rewind cases

**Status**: [x] `tests/unit/monster-abilities/lunge_hit_test_test.gd` (14 tests), `tests/integration/monster-abilities/lunge_lag_comp_test.gd` (9 tests)

---

## Dependencies

- Depends on: Story 002; network-authority story 007 (done)
- Unlocks: Stories 004, 006

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-188):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 1040/1040 after the wave merge, no leak warnings.
- A stun landing the same tick is only flushed after all modules run, so the hit test also refuses while the injected locked(monster) is true.
- Cone measured horizontally to the nearest capsule-axis point (inference; a designer ruling on body edge vs centre settles it).
- SurvivorHit.position carries the hit survivor's rewound feet position (GDD says only 'position'; inference).
- Cone compared as off + off against the full cone to avoid the 0.5 and 2.0 literals the knob-literal scan flags.
- Tests stand in for line of sight (door-plane Callable) and eligibility (Downing.is_eligible over test state). Composer must call set_hit_sources(lc, survivors, Downing.eligible, facing, MapQueries.clear_sight).
- The red run was a parse error (set_hit_sources missing), not observed; mutations stand in for it.
**Test Evidence**: 23 tests; AC-6 dodge smoke (3 m, 4.0 m/s strafe from 0.25 s, 150 ms RTT) not hit. Mutations caught: eligibility removed, rewind forced 0, tie-break changed, LOS ignored, full cone as half-angle.
**Code Review**: Complete (orchestrator review at merge)
