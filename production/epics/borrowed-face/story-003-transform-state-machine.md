# Story 003: Transform state machine, cooldown and FormChanged

> **Epic**: Borrowed Face
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

A transformation takes 2 s, a stun interrupts it, and a 12 s cooldown follows either way. Each completion emits one `FormChanged`; a change into true form drives the reveal.

**GDD**: `design/gdd/borrowed-face.md`
**Requirement**: `TR-borrowedface-004`, `TR-borrowedface-009`, `TR-borrowedface-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order (primary); ADR-0006: Data-driven configuration
**ADR Decision Summary**: `FormChanged` is a catalog event emitted by Borrowed Face with previous form, new form and server time; events flush after each module step so Scare Events sees it the same tick; timings from `BorrowedFaceKnobs`.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: As Story 002.

**Control Manifest Rules (this layer)**:
- Required: owner emits its own catalog events
- Required: timers in ticks from data

---

## Acceptance Criteria

*From `borrowed-face.md` Acceptance Criteria (timing, stun, FormChanged, data), scoped to this story:*

- [x] A form change completes 2 s (±1 tick) after acceptance; the next request is rejected until 12 s after completion.
- [x] A stun during transformation keeps the previous form and starts the 12 s cooldown; a stun on the completion tick wins; no transformation starts while Stunned.
- [x] Each completed change emits exactly one `FormChanged` with previous form, new form and server time; one into true form reaches a stub Scare Events subscriber in the same tick, and a suppressed reveal does not delay the form change.
- [x] A round ending mid-transformation discards it; all timings come from `BorrowedFaceKnobs`.

---

## Implementation Notes

*Derived from `borrowed-face.md` rules 7–9 and ADR-0005:*

- States: TrueForm, Disguised, Transforming(target, end_tick), with cooldown_end_tick.

---

## Out of Scope

- Story 004: immunity interactions
- Reveal scare (Scare Events epic)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/borrowed-face/transform_state_machine_test.gd` — must exist and pass

**Status**: [x] `tests/unit/borrowed-face/transform_state_machine_test.gd` (9 tests)

---

## Dependencies

- Depends on: Story 002; event-catalog stories 001, 002
- Unlocks: Stories 004, 005, 007

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-159):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 880/880 after the wave merge, no leak warnings.
- Test file named `transform_state_machine_test.gd` (story said `transform_state_test.gd`; story updated).
- BF-2 tests' `_become` now waits out the cooldown (`COOLDOWN_TICKS := 720`) so chained form changes still work.
- Stun outside a transformation starts no cooldown: inference from rule 10; a designer ruling settles it.
- Rule 7's Lunge/takedown-commit rejection not done (out of scope). No SHAPESHIFTER_FORM registry view yet.
- Agent worktree started before BF-2; its files were built on main's BF-2 copy and applied onto main directly.
**Test Evidence**: 9 tests. Mutations caught: cooldown check removed, no cooldown on stun, stunned rejection removed, stun not interrupting.
**Code Review**: Complete (orchestrator review at merge)
