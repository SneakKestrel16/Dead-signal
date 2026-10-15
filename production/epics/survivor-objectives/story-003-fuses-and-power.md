# Story 003: Fuses, fuse boxes and power restored

> **Epic**: Survivor Objectives
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Survivors pick up fuses and install them at the active fuse boxes; two installed fuses restore power. Until story 008 (active point selection, Blocked on ADR-0012) lands, tests and the round use a fixed placement: the first authored candidate of each type in `data/maps/research_facility.tres`.

**GDD**: `design/gdd/survivor-objectives.md`
**Requirement**: `TR-objectives-001`, `TR-objectives-004`, `TR-objectives-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Hold-to-interact protocol; secondary: ADR-0005
**ADR Decision Summary**: One `HoldService` times every hold; owners register `Interactable`s and emit their own events from `on_complete` / `on_cancel`; fake holds take no lock and never call the owner.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff APIs.

**Control Manifest Rules (this layer)**:
- Required: run in the `SURVIVOR_OBJECTIVES` tick slot via `server_tick(tick)`; hold owners emit their own catalog events from `on_complete` and `on_cancel`; fake holds take no lock, change no progress and never call the owner (ADR-0002, ADR-0005, ADR-0008)
- Forbidden: never let `HoldService` emit events; never emit an event from a client; never decide discovery from a client report, proximity alone or room entry (ADR-0005, ADR-0008, ADR-0012)
- Guardrail: every `duration_s` and `range_m` comes from `ObjectivesKnobs` (`data/knobs/objectives.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-objectives.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [ ] Picking up a fuse is a `pickup_s` hold; a survivor carries at most one fuse, and may carry a fuse and a drive together (rule 15).
- [ ] Installing at an empty active fuse box is a `fuse_install_s` hold; a box that already has a fuse refuses the install and the second fuse stays carried (rule 15).
- [ ] Two installed fuses broadcast `ObjectiveProgressChanged` (power restored); installed fuses are permanent (rules 16, 17).
- [ ] Every value this story uses is read from `ObjectivesKnobs`, not hardcoded.

---

## Implementation Notes

- Same module and `Interactable` pattern as story 001.
- "One interaction per point" is `HoldService`'s exclusive lock: a second survivor's start at a busy box is refused by the service (CI-8).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: install noise and the monster alert

---

## QA Test Cases

*From `/qa-plan sprint` (production/qa/qa-plan-sprint-005-2026-10-14.md). Implement against these cases.*

- **AC-1**: Pickup and carry limits
  - Given: a survivor carrying a fuse
  - When: they try to pick up a second fuse, then a drive
  - Then: second fuse refused, drive accepted
  - Edge cases: pickup interrupted at `pickup_s` − 1 tick
- **AC-2**: Install and refusal
  - Given: an empty box and a box with a fuse
  - When: a survivor holds install 8 s at each
  - Then: empty box Installed; full box refused and the fuse stays carried
  - Edge cases: two survivors start on one box the same tick
- **AC-3**: Power restored
  - Given: one fuse installed
  - When: the second install completes
  - Then: one `ObjectiveProgressChanged` (power restored); installed fuses stay
  - Edge cases: both installs complete the same tick

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/survivor-objectives/fuses-and-power_test.gd` OR playtest doc

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: Stories 004, 005
