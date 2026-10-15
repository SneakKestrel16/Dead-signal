# Story 006: Drive extraction at the exit

> **Epic**: Survivor Objectives
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

A Healthy carrier entering the open exit extracts the drives they carry; the survivor win is reported only when both drives are Extracted.

**GDD**: `design/gdd/survivor-objectives.md`
**Requirement**: `TR-objectives-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order
**ADR Decision Summary**: Server-only typed events on the `EventBus`; owner-written state in the `StateRegistry`; Objectives runs in the `SURVIVOR_OBJECTIVES` (600) slot after Holds.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Exit volume from `MapQueries`.

**Control Manifest Rules (this layer)**:
- Required: run in the `SURVIVOR_OBJECTIVES` tick slot via `server_tick(tick)`; hold owners emit their own catalog events from `on_complete` and `on_cancel`; fake holds take no lock, change no progress and never call the owner (ADR-0002, ADR-0005, ADR-0008)
- Forbidden: never let `HoldService` emit events; never emit an event from a client; never decide discovery from a client report, proximity alone or room entry (ADR-0005, ADR-0008, ADR-0012)
- Guardrail: every `duration_s` and `range_m` comes from `ObjectivesKnobs` (`data/knobs/objectives.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-objectives.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [ ] A Healthy survivor entering the open exit with 1 drive marks that drive Extracted; the win is reported to Match Flow only when the second drive is Extracted (rule 22).
- [ ] After activation ejects both drives, one survivor can pick up both and Extract them alone.
- [ ] A survivor entering the open exit with no drive is recorded Escaped by Match Flow and changes no objective state; a Downed survivor or the shapeshifter in the exit changes nothing (rules 23, 25).
- [ ] Every value this story uses is read from `ObjectivesKnobs`, not hardcoded.

---

## Implementation Notes

- React to `SurvivorEscaped` (Match Flow story 003 emits it for a Healthy survivor in the open exit): mark that survivor's carried drives Extracted and emit `ObjectiveProgressChanged`. Until Match Flow lands, tests emit `SurvivorEscaped` directly.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Match Flow story 003: deciding the escape and the outcome lock

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/survivor-objectives/extraction_test.gd` OR playtest doc

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 002, 005
- Unlocks: None
