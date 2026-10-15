# Story 007: Shapeshifter fake interactions

> **Epic**: Survivor Objectives
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

The shapeshifter can play the interaction at any objective point in any form, but changes nothing, takes no lock and makes no install noise.

**GDD**: `design/gdd/survivor-objectives.md`
**Requirement**: `TR-objectives-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Hold-to-interact protocol; secondary: ADR-0005
**ADR Decision Summary**: One `HoldService` times every hold; owners register `Interactable`s and emit their own events from `on_complete` / `on_cancel`; fake holds take no lock and never call the owner.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Fake holds through `HoldService` (ADR-0008 §fake holds).

**Control Manifest Rules (this layer)**:
- Required: run in the `SURVIVOR_OBJECTIVES` tick slot via `server_tick(tick)`; hold owners emit their own catalog events from `on_complete` and `on_cancel`; fake holds take no lock, change no progress and never call the owner (ADR-0002, ADR-0005, ADR-0008)
- Forbidden: never let `HoldService` emit events; never emit an event from a client; never decide discovery from a client report, proximity alone or room entry (ADR-0005, ADR-0008, ADR-0012)
- Guardrail: every `duration_s` and `range_m` comes from `ObjectivesKnobs` (`data/knobs/objectives.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-objectives.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [ ] A shapeshifter (disguised or not) interacting with any objective changes no objective state on any client and does not count toward the terminal zone (rule 25).
- [ ] A survivor starting a real interaction at a point where the shapeshifter is faking starts normally, and the fake is cancelled.
- [ ] A fake fuse install plays only the quiet interact loop: no install noise and no alert (rule 26).
- [ ] Every value this story uses is read from `ObjectivesKnobs`, not hardcoded.

---

## Implementation Notes

- Register the fake path per ADR-0008: a fake hold takes no lock and never calls the owner's `on_complete`; the survivor's real start cancels it (CI-9's "another hold started" cancel).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Borrowed Face epic: what a disguise looks like while faking

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/survivor-objectives/shapeshifter-fake-interactions_test.gd` OR playtest doc

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: None
