# Story 006: Integrate with Downing and Borrowed Face

> **Epic**: Monster Abilities
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Replace the stand-ins. Downing tests drive `SurvivorHit` directly, and Borrowed Face 005 (`tests/integration/borrowed-face/disguise_restrictions_test.gd`) uses `StubAbilities`. With the real module, re-check that both still hold and add the end-to-end Lunge to takedown path.

**GDD**: `design/gdd/monster-abilities.md`
**Requirement**: `TR-monster-002`, `TR-monster-003`, `TR-monster-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order; secondary: ADR-0003
**ADR Decision Summary**: Tick order Defense > BorrowedFace > MonsterAbilities > Downing; events are the only coupling between modules.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Plain GDScript; no post-cutoff APIs.

**Control Manifest Rules (this layer)**:
- Required: run in the MonsterAbilities slot via `server_tick(tick)` registered with `TickRunner` (ADR-0002, ADR-0005); every number from `AbilityKnobs` (ADR-0006)
- Forbidden: never emit an event from a client (ADR-0005); no literal for a tuning knob in ability code
- Guardrail: the dodge-window values are coupled; rerun the steering check after changing wind-up, turn rates, dash, radius or cone

---

## Acceptance Criteria

*From GDD `design/gdd/monster-abilities.md`, scoped to this story:*

- [x] Borrowed Face `set_attack_source` is fed from `MonsterAbilities` state; the Borrowed Face 005 disguise-restriction tests pass with the real module in place of `StubAbilities` (re-checked; stub removed or reduced to a thin adapter)
- [x] The existing Downing tests that emit `SurvivorHit` directly still pass; one new test drives a real Lunge into a Downing takedown commit through to `SurvivorDowned`
- [x] Multi-client: across 20 lunges with 5 clients (one at 150 ms simulated latency), all clients agree on every hit/miss and the survivor's resulting state; every dispute is logged

---

## Implementation Notes

- Do not delete the Downing direct-drive tests; they stay as unit coverage of its consumer.
- Re-run `tests/integration/downing-and-rescue/` and `tests/integration/borrowed-face/` in full.

---

## Out of Scope

- New ability behaviour (stories 001-005)

---

## QA Test Cases

*Test specs from `/qa-plan sprint` (`production/qa/qa-plan-sprint-006-2026-10-15.md`). Tests emit the other epic's events directly until MA-6 and SD-12 re-run against both real modules.*

**Test file path**: `tests/integration/monster-abilities/lunge_end_to_end_test.gd`

- **AC-1**: Borrowed Face on the real module
  - Given: `StubAbilities` replaced (or reduced to an adapter) and `set_attack_source` fed from `MonsterAbilities`
  - When: the Borrowed Face 005 disguise-restriction tests run
  - Then: they pass
  - Edge cases: an adapter, if kept, holds no logic
- **AC-2**: Downing unchanged and one real chain
  - Given: the existing Downing tests that emit `SurvivorHit` directly; one new test
  - When: run; then a real lunge drives a takedown commit
  - Then: old tests pass; new test reaches `SurvivorDowned`
  - Edge cases: second down gives `SurvivorEliminated`
- **AC-3**: Five-client agreement
  - Given: 20 lunges, 5 clients, one at 150 ms
  - When: all clients' hit/miss and survivor state are compared
  - Then: identical on every lunge; every dispute logged
  - Edge cases: the dispute log being empty is asserted, not assumed

**Re-run against the real module**: `tests/unit/borrowed-face/transform_state_machine_test.gd`; `tests/unit/borrowed-face/transform_immunity_test.gd`; `tests/integration/borrowed-face/stun_projection_test.gd`; `tests/integration/borrowed-face/disguise_gates_test.gd`; `tests/integration/borrowed-face/disguise_restrictions_test.gd`; the Downing files listed under Cross-Epic Re-Runs in the sprint plan

**Estimated test count**: ~6 tests

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/monster-abilities/lunge_end_to_end_test.gd` — must exist and pass

**Status**: [x] `tests/integration/monster-abilities/lunge_end_to_end_test.gd` (3 tests)

---

## Dependencies

- Depends on: Stories 003, 004, 005
- Unlocks: Story 007

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-193):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 1053/1053 after the wave merge, no leak warnings.
- Hit/miss agreement compares each client's down count and life state against the server's SurvivorHit, because SurvivorHit is never sent to clients (project() empty).
- In the 5-client test the monster's view tick is unset, so its rewind clamps to max_rewind_ms; 150 ms latency is on a survivor link. Rewind under latency is covered by lunge_lag_comp_test.
- Wiring (set_attack_source to LungeView, set_hit_sources) exists only in tests: no composition root yet.
- Downing tests that emit SurvivorHit directly kept unchanged and passing.
**Test Evidence**: 3 tests; disguise_restrictions_test 5/5 on the real module. Mutations caught: Downing ignores SurvivorHit, is_attacking always false, Lunge ignores the form check.
**Code Review**: Complete (orchestrator review at merge)
