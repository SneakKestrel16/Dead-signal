# Story 002: Win evaluation order and immediate endings

> **Epic**: Match Flow & Win Conditions
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

## Context

The win check in its fixed priority order, run on relevant events and once at the end of every tick in the `MATCH_FLOW_RESOLVE` slot. Downing and Survivor Objectives have no code yet; tests emit `SurvivorEliminated` and `ObjectiveProgressChanged` directly.

**GDD**: `design/gdd/match-flow.md`
**Requirement**: `TR-matchflow-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order
**ADR Decision Summary**: Server-only typed events on the `EventBus`; owner-written state in the `StateRegistry`; Match Flow runs in the `MATCH_FLOW_BEGIN` (100) and `MATCH_FLOW_RESOLVE` (900) slots.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Plain GDScript; no post-cutoff APIs.

**Control Manifest Rules (this layer)**:
- Required: implement `server_tick(tick)` and register with `TickRunner` in the `MATCH_FLOW_BEGIN` / `MATCH_FLOW_RESOLVE` slots; never rely on `_physics_process` (ADR-0002, ADR-0005)
- Forbidden: never emit an event from a client (ADR-0005); never let Match Flow tally other systems' stats or call into their modules (ADR-0011, Proposed)
- Guardrail: every tuning value comes from `MatchFlowKnobs` (`data/knobs/match_flow.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/match-flow.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [x] When all survivors are eliminated (including by bleed-out), the round ends at that moment with "All survivors eliminated"; with only Downed survivors inside and the drives not out, it does not end until the last bleeds out (rules 12, 13, 18).
- [x] If nobody is left inside (all Escaped or Eliminated) and a drive was not Extracted, the round ends at once with "Evidence lost"; a survivor in reconnect grace counts as inside (rule 13).
- [x] With nothing done, the deadline at 9:00 ends the round "Shapeshifter Wins — Evacuation deadline expired"; a 15 s activation started at 8:50 does not finish and the monster wins at 9:00 (rules 8, 9).
- [x] Within one tick the order is evidence escaped, all eliminated, evidence lost, deadline, forfeit: the second drive Extracted in the same tick as the last elimination, or as the deadline, is a survivor win (rule 16).

---

## Implementation Notes

- `MatchFlow.resolve` at `TickOrder.MATCH_FLOW_RESOLVE` runs the checks in rule 16's order and stops at the first that fires; the event handlers only mark the check dirty — one evaluation per tick keeps the order deterministic.
- Track per-survivor status (inside Healthy/Downed, Escaped, Eliminated, in grace) from events only; never read Downing's internals (ADR-0011 forbids calling into other modules).
- On an outcome, emit `RoundEnded` with outcome and reason; the results payload is story 008.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: escapes, the outcome lock and the post-escape window
- Story 006: the forfeit check's inputs
- Story 008: the results payload

---

## QA Test Cases

*From `/qa-plan sprint` (production/qa/qa-plan-sprint-005-2026-10-14.md). Implement against these cases.*

- **AC-1**: All eliminated ends at once; only-Downed waits
  - Given: 4 survivors
  - When: each is eliminated by `SurvivorEliminated` (one by bleed-out)
  - Then: `RoundEnded` with "All survivors eliminated" on the tick of the last; with only Downed survivors left no `RoundEnded`
  - Edge cases: last elimination on the deadline tick
- **AC-2**: Evidence lost
  - Given: 1 drive Extracted, others Escaped or Eliminated
  - When: the last survivor inside is eliminated
  - Then: `RoundEnded` "Evidence lost" that tick; a survivor in grace keeps the round running
  - Edge cases: only Downed survivors inside → no Evidence lost
- **AC-3**: Deadline
  - Given: nothing done
  - When: the clock reaches 540 s
  - Then: "Shapeshifter Wins — Evacuation deadline expired"; activation started at 530 s does not complete
  - Edge cases: deadline tick with pending events
- **AC-4**: Same-tick order
  - Given: second drive Extracted and last elimination in one tick; and Extracted on the deadline tick
  - When: the resolve step runs
  - Then: survivor win in both
  - Edge cases: forfeit and earned result same tick → earned result

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/match-flow/win_evaluation_test.gd` — must exist and pass

**Status**: [x] `tests/unit/match-flow/win_evaluation_test.gd` (25 tests)

---

## Dependencies

- Depends on: Story 001
- Unlocks: Stories 003, 004, 006, 008

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: all passing (automated)
**Deviations** (AD-128):
- Implemented by gameplay-programmer in a git worktree, in parallel with DR-1 and SO-3; reviewed and merged by the orchestrator.
- `EvRoundEnded.outcome` and `reason` carry the new `MatchFlow.Outcome` and `MatchFlow.Reason` enums; the rule 23 wording is in `OUTCOME_TEXT` and `REASON_TEXT`.
- The win check runs on every MATCH_FLOW_RESOLVE tick in rule 16 order, first match wins; no dirty flag (same once-per-tick result, less state). `_ended` latches: one RoundEnded per round.
- Both drives Extracted ends the round at once; the post-escape window and outcome lock are story 003.
- Forfeit is a `_forfeit_due()` hook returning false until story 006.
- The roster comes in through `MatchFlow.survivor_ids`, set before start_round. An empty roster skips the all-eliminated and evidence-lost checks.
- A survivor in reconnect grace counts as inside in their last state; only `GRACE_EXPIRED` takes them out (rules 13, 19).
- Test file `win_evaluation_test.gd` (snake case), not the story's hyphenated name.
**Test Evidence**: `tests/unit/match-flow/win_evaluation_test.gd`, 25 tests. Mutations caught: check order swapped, plain disconnect treated as out (4 grace tests), `_ended` lock removed.
**Code Review**: Complete (orchestrator review; drive-id range check on EXTRACTED confirmed against SO-3's fuse and box ids)
