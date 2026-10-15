# Story 006: Disconnects during a commit or while Downed

> **Epic**: Downing, Rescue & Elimination
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Disconnecting can never dodge a takedown or stall the round: commits resolve on schedule and bleed-out keeps running while away.

**GDD**: `design/gdd/downing-and-rescue.md`
**Requirement**: `TR-downing-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Hosting, session join and reconnect; secondary: ADR-0005
**ADR Decision Summary**: A dropped peer has a reconnect grace and resumes its player; server timers keep running while it is away.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Real ENet on loopback; Match Flow owns the grace (match-flow story 005).

**Control Manifest Rules (this layer)**:
- Required: run in the `DOWNING` tick slot via `server_tick(tick)`; hold owners emit their own catalog events from `on_complete` and `on_cancel` (ADR-0002, ADR-0005, ADR-0008)
- Forbidden: never emit an event from a client; never let `HoldService` emit events (ADR-0005, ADR-0008)
- Guardrail: every timer, range and multiplier comes from `DowningKnobs` (`data/knobs/downing.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/downing-and-rescue.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [ ] A victim who disconnects while Seized is Downed (or Eliminated, with `downs_taken` 1) when the commit timer ends, and returns in that state on reconnect.
- [ ] A Downed survivor who disconnects keeps bleeding out and is Eliminated ("Bled out") while still disconnected if the timer expires.
- [ ] A Healthy survivor who disconnects stops slowing bleed-out at once and no longer counts as Healthy (edge cases).
- [ ] Every value this story uses is read from `DowningKnobs`, not hardcoded.

---

## Implementation Notes

- React to `PlayerConnectionChanged`; no special path for a disconnected victim — timers simply keep running.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Match Flow story 005: the reconnect grace itself

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/downing-and-rescue/disconnects_test.gd` OR playtest doc

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001, 003
- Unlocks: None
