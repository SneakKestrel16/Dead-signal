# Story 001: Drive extract and carry

> **Epic**: Survivor Objectives
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

The module's first slice: a new `SurvivorObjectives` module that owns drive state, registers each active drive console as an `Interactable` with `HoldService`, and gives the drive to the survivor who completes the hold. Until story 008 (active point selection, Blocked on ADR-0012) lands, tests and the round use a fixed placement: the first authored candidate of each type in `data/maps/research_facility.tres`.

**GDD**: `design/gdd/survivor-objectives.md`
**Requirement**: `TR-objectives-001`, `TR-objectives-004`, `TR-objectives-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Hold-to-interact protocol; secondary: ADR-0005, ADR-0006
**ADR Decision Summary**: One `HoldService` times every hold; owners register `Interactable`s and emit their own events from `on_complete` / `on_cancel`; fake holds take no lock and never call the owner.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Builds on `HoldService` (CI-8, CI-9) and `Interactable`; no post-cutoff APIs.

**Control Manifest Rules (this layer)**:
- Required: run in the `SURVIVOR_OBJECTIVES` tick slot via `server_tick(tick)`; hold owners emit their own catalog events from `on_complete` and `on_cancel`; fake holds take no lock, change no progress and never call the owner (ADR-0002, ADR-0005, ADR-0008)
- Forbidden: never let `HoldService` emit events; never emit an event from a client; never decide discovery from a client report, proximity alone or room entry (ADR-0005, ADR-0008, ADR-0012)
- Guardrail: every `duration_s` and `range_m` comes from `ObjectivesKnobs` (`data/knobs/objectives.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-objectives.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [ ] A survivor holding interact at a drive console for 5 s (`drive_extract_s`) receives the drive (Secured → Carried) and `ObjectiveProgressChanged` is emitted; releasing at 4 s gives nothing and resets the bar (rules 3, 8).
- [ ] Only a Healthy survivor can start or continue the hold; start range is `interact_range_m`, keep range adds `hold_range_tolerance_m` (rule 2, Controller rules 13–16).
- [ ] A survivor can carry two drives; with a data override of `max_drives_carried` = 1, a survivor carrying a drive cannot pick up the second (rule 9).
- [ ] A client message claiming the extract completed early causes no state change (rule 1).
- [ ] Every value this story uses is read from `ObjectivesKnobs`, not hardcoded.

---

## Implementation Notes

- New module `src/feature/objectives/survivor_objectives.gd` with `setup(tick_runner, bus, registry, knobs)` / `server_tick(tick)`, registered at `TickOrder.SURVIVOR_OBJECTIVES`.
- Drive state lives in the module and is published read-only in the registry; carriers are player ids, never node references.
- The console is an `Interactable` with `duration_s = drive_extract_s` and `range_m = interact_range_m`; `on_complete` emits `ObjectiveProgressChanged` (ADR-0008: owners emit, `HoldService` never does).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: dropping and picking drives up
- Story 007: the shapeshifter's fake interactions

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/survivor-objectives/drive-extract-and-carry_test.gd` OR playtest doc

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (HoldService, Interactable, ObjectivesKnobs and the map markers exist)
- Unlocks: Stories 002, 003, 005, 007, 010
