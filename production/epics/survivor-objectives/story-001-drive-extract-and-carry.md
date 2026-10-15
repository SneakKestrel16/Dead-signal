# Story 001: Drive extract and carry

> **Epic**: Survivor Objectives
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

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

- [x] A survivor holding interact at a drive console for 5 s (`drive_extract_s`) receives the drive (Secured → Carried) and `ObjectiveProgressChanged` is emitted; releasing at 4 s gives nothing and resets the bar (rules 3, 8).
- [x] Only a Healthy survivor can start or continue the hold; start range is `interact_range_m`, keep range adds `hold_range_tolerance_m` (rule 2, Controller rules 13–16).
- [x] A survivor can carry two drives; with a data override of `max_drives_carried` = 1, a survivor carrying a drive cannot pick up the second (rule 9).
- [x] A client message claiming the extract completed early causes no state change (rule 1).
- [x] Every value this story uses is read from `ObjectivesKnobs`, not hardcoded.

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

*From `/qa-plan sprint` (production/qa/qa-plan-sprint-005-2026-10-14.md). Implement against these cases.*

- **AC-1**: 5 s hold gives the drive; release at 4 s resets
  - Given: a Healthy survivor at the active drive console
  - When: they hold 5 s; then another releases at 4 s
  - Then: first gets the drive (Carried) and `ObjectiveProgressChanged`; second gets nothing and progress is 0
  - Edge cases: release one tick before completion
- **AC-2**: Healthy only; range rules
  - Given: a Downed survivor, and a Healthy one at 2.1 m
  - When: each starts the hold
  - Then: Downed refused; 2.1 m refused at start but kept while holding up to 2.25 m
  - Edge cases: 2.25 m exactly
- **AC-3**: Carry cap
  - Given: a survivor carrying a drive, cap 2 then cap 1 (data override)
  - When: they extract a second drive
  - Then: cap 2 accepts, cap 1 refuses
  - Edge cases: cap override fails validation outside 1–2
- **AC-4**: Forged completion ignored
  - Given: a client
  - When: sends a fake "complete" message
  - Then: no state change
  - Edge cases: message during an active hold

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/survivor-objectives/drive_extract_and_carry_test.gd` OR playtest doc

**Status**: [x] Created; passes (18 tests)

---

## Dependencies

- Depends on: None (HoldService, Interactable, ObjectivesKnobs and the map markers exist)
- Unlocks: Stories 002, 003, 005, 007, 010

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: 5/5 passing (automated)
**Deviations** (AD-124):
- Implemented by gameplay-programmer in a git worktree, in parallel with MF-1 and BUG-0002; reviewed by godot-gdscript-specialist; fixes applied by the orchestrator.
- New Feature-layer folder `src/feature/objectives/`. `SurvivorObjectives.new(holds, map, is_healthy)`: the life-state source is an injected callable until Downing publishes a registry view (treated as Healthy when absent).
- Active drives are the first two authored drive markers: placeholder until story 008 (ADR-0012, Proposed).
- Drive state is not yet published in the `StateRegistry` (no `StateKeys` row); the module exposes `state_of`, `carrier_of`, `carried_by`, `drive_count`. Story 005 adds the registry view Match Flow needs.
- `ObjectiveProgressChanged.objective` id ranges: drives `DRIVE_ID` (0) + index, fuses 10+, fuse boxes 20+, terminal 30 (`SurvivorObjectives` constants), so one int names one point across kinds.
- A carried drive's event sets `discovered = true`, so survivor clients receive it (rule 10); real discovery is story 009.
- AC4: there is no client "complete" message to forge. The tests prove that a claim the server's ray does not confirm, a press on another target mid-hold, and a rival's press change no state.
- Review fixes: the consoles hold the module through a `WeakRef` (a strong back-reference was a RefCounted cycle through `HoldService` that leaked every round); `setup()` resets its arrays and reports a map with fewer than 2 drive markers; the Healthy callable result is typed.
- The test file is `drive_extract_and_carry_test.gd` (snake case, as the other suites), not the story's hyphenated name.
**Test Evidence**: `tests/integration/survivor-objectives/drive_extract_and_carry_test.gd`, 18 tests. Mutations caught: strong back-reference (cycle test), `discovered` unset (projection test), id base removed (3 tests); the cap check broken (cap test, agent). Equivalent: removing the `setup()` reset (the `ACTIVE_DRIVES` guard already stops duplicates).
**Code Review**: Complete (godot-gdscript-specialist; S2 cycle and S2 projection fixed; S3 id collision fixed; S3 setup reset fixed; test gaps for lock release and a carried drive added)
