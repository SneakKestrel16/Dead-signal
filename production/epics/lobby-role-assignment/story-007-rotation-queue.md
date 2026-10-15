# Story 007: Shapeshifter rotation queue (post-M1)

> **Epic**: Lobby & Role Assignment
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

## Context

Post-M1 phase. Instead of a random pick, a shuffled queue of session tokens decides who is the shapeshifter, so turns are fair. It advances on Ended, not Cancelled.

**GDD**: `design/gdd/lobby-role-assignment.md`
**Requirement**: `TR-lobby-005`, `TR-lobby-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR: N/A — pure server logic, no architectural pattern required (EPIC.md GDD Requirements)
**ADR Decision Summary**: N/A.
**ADR Version**: N/A

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Plain GDScript with a seeded `RandomNumberGenerator`.

**Control Manifest Rules (this layer)**:
- Required: tests are deterministic (seeded RNG)

---

## Acceptance Criteria

*From `lobby-role-assignment.md` AC-LB-13, AC-LB-15, AC-LB-16, scoped to this story:*

- [x] With N connected tokens and a seeded RNG before the first round, Q_1 holds each token exactly once, its order is reproducible from the seed, and its head is the shapeshifter.
- [x] With a stable roster of N = 4, 5 and 6, over 2N rounds reaching Ended (one by forfeit), `shapeshifter(r) = Q_1[(r − 1) mod N]` and every token is the shapeshifter exactly twice.
- [x] After a Cancelled round the queue is unchanged, the same token is the shapeshifter, and character assignment runs again.

---

## Implementation Notes

*Derived from `lobby-role-assignment.md` Formulas (rotation queue) and rule 10:*

- Replaces Story 002's M1 random pick behind the same function.

---

## Out of Scope

- Story 008: absent and reconnecting tokens

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-004-2026-10-14.md` (/qa-plan, 2026-10-14). Implement against these and the Acceptance Criteria above.*

**Test file path**: `tests/unit/lobby/rotation_queue_test.gd`
**What to test**:
- N connected tokens and a seeded RNG: Q_1 holds each token once, reproducible from the seed, head is the shapeshifter.
- Stable roster N = 4, 5, 6 over 2N Ended rounds (one forfeit): `shapeshifter(r) = Q_1[(r − 1) mod N]`, each token the shapeshifter exactly twice.
- After a Cancelled round: queue unchanged, same shapeshifter, characters dealt again.

**Estimated test count**: ~5 unit tests

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/lobby/rotation_queue_test.gd` — must exist and pass

**Status**: [x] Created; passes (8 tests, plus 15 in `tests/integration/lobby/roster_lock_test.gd`)

---

## Dependencies

- Depends on: Story 002; network-authority story 002 (tokens)
- Unlocks: Stories 008, 012

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: 3/3 passing (automated)
**Deviations** (AD-114):
- Implemented by gameplay-programmer in a git worktree, in parallel with CI-9 at the designer's request; reviewed and merged by the orchestrator.
- `RotationQueue` (session-long, owned by `RosterHandoff`): Q_1 is a seeded Fisher-Yates shuffle of the tokens at the first lock (every connected player must be Ready to lock, so this is the GDD's "connected before the first round"); the first present token is the shapeshifter; `advance()` moves that picked token (not necessarily the head) to the back.
- `RosterHandoff.end_round(ended: bool)` is required, not defaulted: only Ended advances the queue, Cancelled leaves it and redeals characters. A forfeit reaches Ended (rule 9); Match Flow's forfeit-to-Ended mapping is its own story's test.
- First-time joiners are appended at the next lock whatever the last round's outcome (the GDD formula adds them after Ended): a reading of rule 10.
- `Roster.lock` takes the queue; a refused lock never touches it (refusal checks run before the pick).
- `RosterHandoff` round index still counts Cancelled rounds (story 002's test); the GDD's `r` counts Ended rounds only. The queue does not depend on it. Design question recorded, not changed.
- Deferred: a "next shapeshifter" query for the lobby display while in Waiting (rule 11) is the lobby-screen story's; `queue_order()` is empty before the first lock. Absent and reconnecting tokens are story 008 (AC-LB-17).
**Test Evidence**: Unit: `tests/unit/lobby/rotation_queue_test.gd`; 5 mutations caught, 1 equivalent (a repeated advance() is a no-op either way). Full suite 479/479.
**Code Review**: Complete (qa-tester reviewing code and tests; S3s fixed: redeal check could not fail, forfeit recorded; S4 typing and shadowing fixed)
