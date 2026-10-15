# Story 001: Life state and takedown commit

> **Epic**: Downing, Rescue & Elimination
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

## Context

A new `Downing` module holds each survivor's life state and `downs_taken`; a valid `SurvivorHit` starts a takedown commit that ends in a down, an elimination, or nothing if the monster is stunned. Monster Abilities and Survivor Defense have no code yet: tests emit `SurvivorHit` and `MonsterStunned` directly.

**GDD**: `design/gdd/downing-and-rescue.md`
**Requirement**: `TR-downing-001`, `TR-downing-002`, `TR-downing-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order; secondary: ADR-0006
**ADR Decision Summary**: Server-only typed events on the `EventBus`; owner-written state in the `StateRegistry`; Downing runs in the `DOWNING` (500) slot after Monster Abilities and before Holds.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Plain GDScript on the server tick; no post-cutoff APIs.

**Control Manifest Rules (this layer)**:
- Required: run in the `DOWNING` tick slot via `server_tick(tick)`; hold owners emit their own catalog events from `on_complete` and `on_cancel` (ADR-0002, ADR-0005, ADR-0008)
- Forbidden: never emit an event from a client; never let `HoldService` emit events (ADR-0005, ADR-0008)
- Guardrail: every timer, range and multiplier comes from `DowningKnobs` (`data/knobs/downing.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/downing-and-rescue.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [x] A Healthy survivor whose takedown commit completes becomes Downed; a survivor with `downs_taken` 1 whose commit completes becomes Eliminated without entering Downed; `SurvivorDowned` / `SurvivorEliminated` are emitted (rules 4, 5, Formulas "Takedown outcome").
- [x] A `MonsterStunned` received during Committing cancels the commit and `downs_taken` is unchanged; a stun and commit completion on the same tick resolve as the stun (rule 4, edge cases).
- [x] A `SurvivorHit` on a Downed survivor or a survivor in grace changes nothing; the monster disconnecting mid-commit cancels it (rule 3, edge cases).
- [x] Every value this story uses is read from `DowningKnobs`, not hardcoded.

---

## Implementation Notes

- New module `src/feature/downing/downing.gd` with `setup(...)` / `server_tick(tick)` at `TickOrder.DOWNING`; the commit timer counts ticks of `net.sim_tick_hz`.
- Life state, `downs_taken` and Committing are published read-only in the registry for Monster Abilities, Objectives and Match Flow.
- `downs_to_eliminate` is fixed at 2 by its knob range.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: grace windows
- Story 005: rooting the victim and the monster during the commit

---

## QA Test Cases

*From `/qa-plan sprint` (production/qa/qa-plan-sprint-005-2026-10-14.md). Implement against these cases.*

- **AC-1**: Commit outcome
  - Given: a Healthy survivor, then one with `downs_taken` 1
  - When: `SurvivorHit`, then 1.5 s
  - Then: first Downed + `SurvivorDowned`; second Eliminated + `SurvivorEliminated` without Downed
  - Edge cases: commit timer boundary ±1 tick
- **AC-2**: Stun cancels
  - Given: a commit in progress
  - When: `MonsterStunned` arrives (and on the completion tick)
  - Then: commit cancelled, `downs_taken` unchanged, both cases
  - Edge cases: stun one tick after completion → down stands
- **AC-3**: Invalid hits ignored
  - Given: a Downed survivor and one in grace
  - When: `SurvivorHit` for each; monster disconnect mid-commit
  - Then: no change; disconnect cancels the commit
  - Edge cases: hit during an active commit

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/downing-and-rescue/takedown_commit_test.gd` — must exist and pass

**Status**: [x] `tests/unit/downing-and-rescue/takedown_commit_test.gd` (17 tests)

---

## Dependencies

- Depends on: None (event catalog, RoundServer and DowningKnobs exist)
- Unlocks: Stories 002–007

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: all passing (automated)
**Deviations** (AD-127):
- Implemented by gameplay-programmer in a git worktree, in parallel with MF-2 and SO-3; reviewed and merged by the orchestrator.
- New Feature-layer folder `src/feature/downing/`. `Downing.set_roster(survivors, monster)` is called before `RoundServer.start_round`; `setup()` resets every survivor to Healthy with 0 downs.
- No new state key: the module publishes the existing `StateKeys.TAKEDOWN_ELIGIBILITY` (`Downing.LifeView`: life state, downs taken, eligible) and `StateKeys.COMMITTING_STATE` (`Downing.CommitView`). Both views hold the module through a `WeakRef` and fail closed once it is freed.
- The commit completes on hit tick + `knobs.ticks(takedown_commit_s)`, in the DOWNING slot (500). MonsterStunned arrives in the Survivor Defense flush (200), so a stun on the completion tick cancels first (Edge Cases: stun wins).
- Grace (story 002) extends `eligible(player)`; the release hook is `_cancel_commit()`.
- Only the monster's disconnect cancels a commit; a Seized victim's disconnect lets the commit run on.
- Test file `takedown_commit_test.gd` (snake case), not the story's hyphenated name.
**Test Evidence**: `tests/unit/downing-and-rescue/takedown_commit_test.gd`, 17 tests. Five mutations watched failing (agent run).
**Code Review**: Complete (orchestrator review: weak views, slot order, event fields checked)
