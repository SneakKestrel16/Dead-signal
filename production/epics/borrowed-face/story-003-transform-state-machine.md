# Story 003: Transform state machine, cooldown and FormChanged

> **Epic**: Borrowed Face
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] A form change completes 2 s (±1 tick) after acceptance; the next request is rejected until 12 s after completion.
- [ ] A stun during transformation keeps the previous form and starts the 12 s cooldown; a stun on the completion tick wins; no transformation starts while Stunned.
- [ ] Each completed change emits exactly one `FormChanged` with previous form, new form and server time; one into true form reaches a stub Scare Events subscriber in the same tick, and a suppressed reveal does not delay the form change.
- [ ] A round ending mid-transformation discards it; all timings come from `BorrowedFaceKnobs`.

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
- Logic: `tests/unit/borrowed-face/transform_state_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002; event-catalog stories 001, 002
- Unlocks: Stories 004, 005, 007
