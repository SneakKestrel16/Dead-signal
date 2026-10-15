# Story 002: Grace windows and takedown eligibility

> **Epic**: Downing, Rescue & Elimination
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

After a rescue or a stun release a survivor cannot be taken down for a short grace; eligibility is published for Monster Abilities to read before it produces a hit.

**GDD**: `design/gdd/downing-and-rescue.md`
**Requirement**: `TR-downing-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order
**ADR Decision Summary**: Server-only typed events on the `EventBus`; owner-written state in the `StateRegistry`; Downing runs in the `DOWNING` (500) slot after Monster Abilities and before Holds.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Plain GDScript; no post-cutoff APIs.

**Control Manifest Rules (this layer)**:
- Required: run in the `DOWNING` tick slot via `server_tick(tick)`; hold owners emit their own catalog events from `on_complete` and `on_cancel` (ADR-0002, ADR-0005, ADR-0008)
- Forbidden: never emit an event from a client; never let `HoldService` emit events (ADR-0005, ADR-0008)
- Guardrail: every timer, range and multiplier comes from `DowningKnobs` (`data/knobs/downing.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/downing-and-rescue.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [ ] A rescued survivor cannot be taken down for `post_rescue_grace_s` (3 s ±1 tick) after standing up; a survivor freed by a stun cannot for `post_release_grace_s` (2 s ±1 tick) (rules 4.4, 8).
- [ ] Eligibility (Healthy, not hidden, not in grace, not in a commit) is published read-only in the registry; a hidden survivor (Survivor Defense state; absent owner reads as not hidden) is ineligible (rule 3).
- [ ] Every value this story uses is read from `DowningKnobs`, not hardcoded.

---

## Implementation Notes

- Grace is an end tick per survivor; eligibility is a pure function so the unit test covers it without a round.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Monster Abilities epic: reading eligibility before a lunge hit

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/downing-and-rescue/grace-and-eligibility_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: Story 004
