# Story 004: Rescue hold with persisting progress

> **Epic**: Downing, Rescue & Elimination
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

A Healthy teammate rescues a Downed survivor with a six-second hold; progress stays on the Downed survivor and decays when nobody is holding.

**GDD**: `design/gdd/downing-and-rescue.md`
**Requirement**: `TR-downing-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Hold-to-interact protocol; secondary: ADR-0005
**ADR Decision Summary**: One `HoldService` times every hold; owners register `Interactable`s and emit their own events from `on_complete` / `on_cancel`.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Builds on `HoldService` (CI-8, CI-9).

**Control Manifest Rules (this layer)**:
- Required: run in the `DOWNING` tick slot via `server_tick(tick)`; hold owners emit their own catalog events from `on_complete` and `on_cancel` (ADR-0002, ADR-0005, ADR-0008)
- Forbidden: never emit an event from a client; never let `HoldService` emit events (ADR-0005, ADR-0008)
- Guardrail: every timer, range and multiplier comes from `DowningKnobs` (`data/knobs/downing.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/downing-and-rescue.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [ ] Holding Rescue for 6.0 s (±1 tick) uninterrupted rescues; releasing at 4.0 s and resuming 3.0 s later needs 3.5 s more (rule 7, Formulas "Rescue progress").
- [ ] With two survivors holding Rescue on the same Downed survivor, the second gets "already being rescued" and the rescue still takes 6 s; a hidden survivor cannot start a rescue.
- [ ] A rescuer who is hit or shocked mid-rescue interrupts it (progress kept, decaying); a rescued survivor stands up Healthy with `downs_taken` 1 and `SurvivorRescued` is emitted (rules 7, 8).
- [ ] Every value this story uses is read from `DowningKnobs`, not hardcoded.

---

## Implementation Notes

- The Downed survivor is an `Interactable` (exclusive, `duration_s = rescue_duration_s`, `range_m = rescue_range_m`); progress lives on the Downed survivor, not in `HoldService`, so it can decay and persist across rescuers (ADR-0008 stored progress, CI-8).
- Both rescuer and victim are rooted while the hold is active (story 005's modifier).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: rooting during the rescue

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/downing-and-rescue/rescue-hold_test.gd` OR playtest doc

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001, 002
- Unlocks: None
