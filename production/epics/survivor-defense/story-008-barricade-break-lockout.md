# Story 008: Barricade break, persistence and rebarricade lockout

> **Epic**: Survivor Defense
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

The monster, in any form, holds Break on a barricaded door. The barricade breaks after `barricade_break_s` (5 s) of total break time, progress kept across interruptions, and emits `BarricadeBroken`. After a break the door cannot be barricaded for `rebarricade_lockout_s` (30 s).

**GDD**: `design/gdd/survivor-defense.md`
**Requirement**: `TR-defense-007, TR-defense-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order; secondary: ADR-0008
**ADR Decision Summary**: The owner emits `BarricadeBroken` from its hold completion; break progress persists on the server between holds.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Uses `EvBarricadeBroken` (no client payload; the door state and break sound reach peers by replicated door and positional audio).

**Control Manifest Rules (this layer)**:
- Required: emit `BarricadeBroken` from `on_complete`; break is rooting with progress kept on cancel (rule 28a)
- Forbidden: never let a survivor break a barricade; never lose break progress on a stun
- Guardrail: Every value is read from `DefenseKnobs` (`data/knobs/defense.tres`), none hardcoded.

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-defense.md` (Detailed Design and Acceptance Criteria), scoped to this story:*

- [ ] A barricade breaks after exactly 5 s of total break time, with progress kept across interruptions, including a stun (rules 27, 15).
- [ ] A broken barricade cannot be rebuilt on that door for 30 s and can after (rule 28).
- [ ] Break works in any form and is a visible monster action; survivors cannot start it (rule 27).
- [ ] `BarricadeBroken` is emitted once per break.

---

## Implementation Notes

- Total break time is accumulated hold ticks, not a single hold; store it per door and clear it on removal or break.
- Strike noise is positional audio, owned by the audio pipeline (ADR-0013, Proposed); only emit the event here.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: building
- Story 011: presentation and audio

---

## QA Test Cases

*Test specs from `/qa-plan sprint` (`production/qa/qa-plan-sprint-006-2026-10-15.md`). Tests emit the other epic's events directly until MA-6 and SD-12 re-run against both real modules.*

**Test file path**: `tests/unit/survivor-defense/barricade_break_test.gd`

- **AC-1**: Break time
  - Given: a barricade
  - When: break with interruptions including a stun
  - Then: breaks after exactly 5 s total; progress kept
  - Edge cases: interruption on the final tick
- **AC-2**: Rebuild lockout
  - Given: a just-broken barricade
  - When: a rebuild at 29.9 s and 30 s
  - Then: rejected before, allowed at 30 s
  - Edge cases: exactly 30 s
- **AC-3**: Who may break
  - Given: the monster in each form; a survivor
  - When: a break is started
  - Then: works in any form and is a visible monster action; survivors cannot start it
  - Edge cases: disguised monster
- **AC-4**: Event
  - Given: a break
  - When: completes
  - Then: `BarricadeBroken` emitted once
  - Edge cases: two doors broken give two events

**Estimated test count**: ~6 tests

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: Logic: `tests/unit/survivor-defense/barricade_break_test.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 004, 007
- Unlocks: Story 012
