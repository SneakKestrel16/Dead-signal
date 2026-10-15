# Story 004: Monster stun, immunity and cancels

> **Epic**: Survivor Defense
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

The monster's Normal, Stunned, Immune machine. A valid hit stuns for `stun_duration_s` and emits `MonsterStunned`; the immunity runs `stun_immunity_s` after and ends early on a lunge wind-up or a completed change into a disguise. A stun cancels a lunge, a takedown commit, a transformation, a search and a break. This replaces the Borrowed Face `StubDefense`.

**GDD**: `design/gdd/survivor-defense.md`
**Requirement**: `TR-defense-004, TR-defense-005, TR-defense-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order; secondary: ADR-0007
**ADR Decision Summary**: `MonsterStunned` is emitted by its owner; a stun beats same-tick completions through the tick order, and consumers react to the event.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Uses `EvMonsterStunned`; Downing and Borrowed Face already subscribe (`_on_monster_stunned`). The stand-ins are in three Borrowed Face tests.

**Control Manifest Rules (this layer)**:
- Required: events emitted by the owner in its tick slot; a stun processed before same-tick completions (ADR-0005)
- Forbidden: never emit `MonsterStunned` from a client path; never extend immunity on a second hit
- Guardrail: Every value is read from `DefenseKnobs` (`data/knobs/defense.tres`), none hardcoded.

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-defense.md` (Detailed Design and Acceptance Criteria), scoped to this story:*

- [x] A taser first-hit on the true-form monster within 5 m applies a 2.0 s stun and emits `MonsterStunned`; out of range, missed or blocked by a survivor it does not (acceptance 1).
- [x] A stun during lunge wind-up produces no `SurvivorHit`; during a takedown commit it frees the victim; during a transformation it cancels it; a stun beats a completion on the same tick (rule 15).
- [x] A second true-form hit inside `stun_immunity_s` is resisted and applies nothing; two survivors firing on the same tick stun once and spend two charges (rule 10, edge case).
- [x] A stun at 0 s, lunge wind-up at 2 s into immunity ends immunity, and a stun on that wind-up applies; a completed change into a disguise also ends immunity (rule 16).
- [x] A search or break in progress is interrupted and barricade damage already dealt is kept (rule 15).

---

## Implementation Notes

- The module reads the lunge and wind-up from Monster Abilities through a narrow callable (that module is built in parallel, use a fixture until it lands).
- A disguised hit goes through story 003's lock instead of this machine; this machine runs only in true form.
- Stun timers keep running while the monster is disconnected.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: the lock a disguised monster gets
- Story 005: events seen by clients
- Story 012: re-running stand-in tests

---

## QA Test Cases

*Test specs from `/qa-plan sprint` (`production/qa/qa-plan-sprint-006-2026-10-15.md`). Tests emit the other epic's events directly until MA-6 and SD-12 re-run against both real modules.*

**Test file path**: `tests/unit/survivor-defense/monster_stun_test.gd`

- **AC-1**: Stun applies
  - Given: a true-form monster within 5 m; out of range; missed; blocked by a survivor
  - When: a taser hit
  - Then: 2.0 s stun and `MonsterStunned` only for the first
  - Edge cases: exactly 5 m
- **AC-2**: Stun cancels
  - Given: a lunge wind-up, takedown commit, transformation, and a same-tick completion
  - When: a stun lands
  - Then: no `SurvivorHit`; victim freed; change cancelled; stun beats completion
  - Edge cases: stun one tick after completion: the down stands
- **AC-3**: Immunity
  - Given: a stun, then a second true-form hit inside `stun_immunity_s`; two survivors firing the same tick
  - When: hits land
  - Then: second resisted, nothing applied; same-tick pair stuns once and spends two charges
  - Edge cases: hit at immunity end
- **AC-4**: Immunity ends early
  - Given: stun at 0 s; lunge wind-up at 2 s into immunity; a completed change into a disguise
  - When: each occurs
  - Then: immunity ends and a stun on that wind-up applies; same after a disguise
  - Edge cases: a rejected wind-up leaves immunity in place
- **AC-5**: Interrupted actions
  - Given: a search or break in progress
  - When: a stun lands
  - Then: interrupted; barricade damage already dealt is kept
  - Edge cases: stun on the final break tick

**Re-run against the real module**: `tests/unit/borrowed-face/transform_state_machine_test.gd`; `tests/unit/borrowed-face/transform_immunity_test.gd`; the Downing tests listed under Cross-Epic Re-Runs in the sprint plan

**Estimated test count**: ~10 tests

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: Logic: `tests/unit/survivor-defense/monster_stun_test.gd`. Re-run: `tests/unit/borrowed-face/transform_state_machine_test.gd`, `tests/unit/borrowed-face/transform_immunity_test.gd`, and the Downing commit-cancel tests under `tests/unit/downing-and-rescue/`.

**Status**: [x] `tests/unit/survivor-defense/monster_stun_test.gd` (16 tests)

---

## Dependencies

- Depends on: Stories 002, 003
- Unlocks: Stories 005, 008, 012

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-187):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 992/992 after the wave merge, no leak warnings.
- MonsterStunned is emitted in every form (GDD rules 1 and 9, the event's true_form field); survivors never receive the disguised one because project() filters it. Needed so a stun during a change back to true form cancels it.
- Break tested with a stand-in item (story 008 adds Break); 'damage kept' checked as progress > 0 passed to the item on cancel.
- Lunge wind-up detected from AbilityUsed (only accepted wind-ups emit it), not LungeView.
- SurvivorHit emitted directly in tests until MA-6 and SD-12. Composer must call set_form_source(bf.form).
- Uncaught mutation: dropping the 'never shorten a running stun' check; unreachable through real modules (a locked monster can neither lunge nor transform), check kept.
**Test Evidence**: 16 tests with real Borrowed Face, Monster Abilities and Downing. Mutations caught: no MonsterStunned emit, immunity never ends early, disguise completion not ending immunity.
**Code Review**: Complete (orchestrator review at merge)
