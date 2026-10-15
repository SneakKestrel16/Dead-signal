# Story 003: Fuses, fuse boxes and power restored

> **Epic**: Survivor Objectives
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

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

- [x] Picking up a fuse is a `pickup_s` hold; a survivor carries at most one fuse, and may carry a fuse and a drive together (rule 15).
- [x] Installing at an empty active fuse box is a `fuse_install_s` hold; a box that already has a fuse refuses the install and the second fuse stays carried (rule 15).
- [x] Two installed fuses broadcast `ObjectiveProgressChanged` (power restored); installed fuses are permanent (rules 16, 17).
- [x] Every value this story uses is read from `ObjectivesKnobs`, not hardcoded.

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
- Integration: `tests/integration/survivor-objectives/fuses_and_power_test.gd` OR playtest doc

**Status**: [x] `tests/integration/survivor-objectives/fuses_and_power_test.gd` (15 tests)

---

## Dependencies

- Depends on: Story 001
- Unlocks: Stories 004, 005

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: all passing (automated)
**Deviations** (AD-129):
- Implemented by gameplay-programmer in a git worktree, in parallel with DR-1 and MF-2; reviewed and merged by the orchestrator.
- Active fuses and boxes are the first two authored `fuse` and `fuse_box` markers: placeholder until story 008 (ADR-0012, Proposed).
- `FUSES_REQUIRED` (2) and `MAX_FUSES_CARRIED` (1) are constants, not knobs: GDD rule 15 sets them and the GDD's Tuning Knobs table has no row for them. Durations and ranges come from `ObjectivesKnobs`.
- Power restored is `ObjectiveProgressChanged` with `objective = TERMINAL_ID`, `state = TerminalState.POWERED` (added last, so ARMED keeps its value for Match Flow). Each install also emits one fuse event and one box event.
- Merge fix (orchestrator): the agent's shared base was an inner class `Point` that the three point classes extended. In Godot 4.7.2 this leaked the whole script graph at exit (every suite loading the script printed "ObjectDB instances were leaked"). Found by bisecting after the merged full run; the base is now the top-level `ObjectivePoint` (`src/feature/objectives/objective_point.gd`). Recorded in `docs/engine-reference/godot/gotchas.md`.
- Dropped fuses can be picked up, but nothing sets DROPPED yet (story 002).
- Test file `fuses_and_power_test.gd` (snake case), not the story's hyphenated name.
**Test Evidence**: `tests/integration/survivor-objectives/fuses_and_power_test.gd`, 15 tests. Mutations caught: carry cap and empty-box check removed, power at 1 fuse, strong back-reference (cycle test), empty `lock_key`.
**Code Review**: Complete (orchestrator review; the exit-time script leak found and fixed at merge)
