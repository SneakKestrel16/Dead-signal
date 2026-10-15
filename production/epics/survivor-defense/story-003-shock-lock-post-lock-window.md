# Story 003: One shock lock, no refresh, post-lock window

> **Epic**: Survivor Defense
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

The single lock both a shocked survivor and a stunned disguised monster get: `stun_root_s` root, then `stun_slow_mult` slow to `stun_duration_s`, no doors, interact, items, pings or callouts; a hit cancels any hold in progress. Hits during the lock or the following `stun_immunity_s` still spend the charge but add nothing.

**GDD**: `design/gdd/survivor-defense.md`
**Requirement**: `TR-defense-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Movement, physics and collision layers; secondary: ADR-0005, ADR-0008
**ADR Decision Summary**: Root and slow are owner-keyed `MovementModifiers`; hold gating goes through `HoldService.set_barred`, so one lock serves a shocked survivor and a stunned disguised monster alike.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Uses `MovementModifiers` (owner key `taser_root` / slow) and `HoldService.set_barred`; Downing already accepts modifiers through `set_modifiers`.

**Control Manifest Rules (this layer)**:
- Required: movement effects as owner-keyed modifiers on the server; hold gating through `set_barred` (ADR-0007, ADR-0008)
- Forbidden: never refresh or extend a running lock; never branch the lock on whether the target is a survivor or the monster
- Guardrail: Every value is read from `DefenseKnobs` (`data/knobs/defense.tres`), none hardcoded. The lock state is published under `StateKeys.SHOCK_STUN_LOCK`.

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-defense.md` (Detailed Design and Acceptance Criteria), scoped to this story:*

- [x] A hit on a survivor roots them for `stun_root_s`, slows them until `stun_duration_s`, and cancels a rescue, objective hold or barricade in progress (rules 11, 14).
- [x] For `stun_duration_s` the locked player fails every door, interact, item, ping and callout attempt and succeeds on the first attempt after it ends (rule 14).
- [x] Four hits 0.5 s apart lock for exactly `stun_duration_s` from the first hit; four charges spent (no refresh).
- [x] Eight hits 2 s apart (0, 2, ..., 14 s) lock only 0 to 2 s and 8 to 10 s; the other hits play and spend a charge but apply no root, slow or lock; a hit inside the post-lock window still cancels a hold (rules 14, 11).

---

## Implementation Notes

- Timers count server ticks and run through a disconnect.
- The post-lock window starts when the lock ends and lasts `stun_immunity_s`; the monster's immunity (story 004) is this same window plus its early ends.
- Return whether a hit applied a lock so the event story (005) can pick the presentation.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: monster-only cancels and early immunity end
- Story 005: events
- Story 011: presentation

---

## QA Test Cases

*Test specs from `/qa-plan sprint` (`production/qa/qa-plan-sprint-006-2026-10-15.md`). Tests emit the other epic's events directly until MA-6 and SD-12 re-run against both real modules.*

**Test file path**: `tests/unit/survivor-defense/shock_lock_test.gd`

- **AC-1**: Root, slow, cancel
  - Given: a survivor in a rescue, an objective hold, and a barricade build
  - When: a hit lands
  - Then: rooted `stun_root_s`; slowed until `stun_duration_s`; the hold is cancelled
  - Edge cases: hit on the first tick of a hold
- **AC-2**: Lock blocks actions
  - Given: a locked player
  - When: door, interact, item, ping and callout are tried
  - Then: every attempt fails; the first attempt after the lock succeeds
  - Edge cases: attempts on the last locked tick and the first free tick
- **AC-3**: No refresh
  - Given: four hits 0.5 s apart
  - When: time is read
  - Then: lock lasts exactly `stun_duration_s` from the first hit; four charges spent
  - Edge cases: hit exactly at lock end
- **AC-4**: Post-lock window
  - Given: eight hits 2 s apart (0, 2, ..., 14 s)
  - When: effects are read
  - Then: lock only at 0 to 2 s and 8 to 10 s; other hits spend a charge, play, apply no root, slow or lock; a hit in the window still cancels a hold
  - Edge cases: hit at exactly the window edge

**Estimated test count**: ~8 tests

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: Logic: `tests/unit/survivor-defense/shock_lock_test.gd`

**Status**: [x] `tests/unit/survivor-defense/shock_lock_test.gd` (9 tests)

---

## Dependencies

- Depends on: Stories 001, 002
- Unlocks: Stories 004, 005

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-185):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 976/976 after the wave merge, no leak warnings.
- One modifier owner `&"taser"` switches ROOT to SLOW instead of the two keys in the engine notes.
- Door, interact and barricade gating goes through `HoldService.set_barred`; the composer must combine it with Borrowed Face's Transforming bar (one barred Callable).
- Pings and callouts have no module yet; AC-2 tested through the SHOCK_STUN_LOCK view they are expected to read.
- AC-1's three hold kinds tested with stub interactables on a real HoldService (shared cancel path; inference).
- Modules ordered before SURVIVOR_DEFENSE see the modifier change one tick late (they see `locked()` on time).
- First runs failed on a parse error and an out-of-range test knob, not missing behaviour; mutations stand in for the red run.
**Test Evidence**: 9 tests. Mutations caught: post-lock window removed, root one tick long, can_fire lock check dropped, hold cancel removed.
**Code Review**: Complete (orchestrator review at merge)
