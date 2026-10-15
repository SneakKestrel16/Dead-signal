# Story 006: Drive extraction at the exit

> **Epic**: Survivor Objectives
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

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

- [x] A Healthy survivor entering the open exit with 1 drive marks that drive Extracted; the win is reported to Match Flow only when the second drive is Extracted (rule 22).
- [x] After activation ejects both drives, one survivor can pick up both and Extract them alone.
- [x] A survivor entering the open exit with no drive is recorded Escaped by Match Flow and changes no objective state; a Downed survivor or the shapeshifter in the exit changes nothing (rules 23, 25).
- [x] Every value this story uses is read from `ObjectivesKnobs`, not hardcoded.

---

## Implementation Notes

- React to `SurvivorEscaped` (Match Flow story 003 emits it for a Healthy survivor in the open exit): mark that survivor's carried drives Extracted and emit `ObjectiveProgressChanged`. Until Match Flow lands, tests emit `SurvivorEscaped` directly.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Match Flow story 003: deciding the escape and the outcome lock

---

## QA Test Cases

*From `/qa-plan sprint` (production/qa/qa-plan-sprint-005-2026-10-14.md). Implement against these cases.*

- **AC-1**: One drive extracts
  - Given: a carrier with 1 drive, exit open
  - When: `SurvivorEscaped` for them
  - Then: that drive Extracted; win not reported until the second
  - Edge cases: carrier with 2 drives
- **AC-2**: One survivor carries both out
  - Given: both drives ejected
  - When: one survivor picks both up and escapes
  - Then: both Extracted, win reported
  - Edge cases: cap override 1 prevents this
- **AC-3**: No-drive escape and non-survivors
  - Given: a survivor without drives, a Downed survivor, the shapeshifter
  - When: each enters the open exit
  - Then: no objective change
  - Edge cases: shapeshifter disguised

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/survivor-objectives/extraction_test.gd` OR playtest doc

**Status**: [x] `tests/integration/survivor-objectives/extraction_test.gd` (6 tests)

---

## Dependencies

- Depends on: Stories 002, 005
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: all passing (automated)
**Deviations** (AD-134):
- Implemented by gameplay-programmer in a git worktree, in parallel with MF-3; reviewed and merged by the orchestrator.
- The agent first built its own escape detection (exit radius knob, `SurvivorEscaped` emitted by Survivor Objectives). MF-3 built the same in Match Flow, which the GDD and the event file name as the emitter, so the orchestrator had SO-6 reworked: Survivor Objectives now only reacts to `SurvivorEscaped` (rule 22), marking every drive that survivor carries EXTRACTED and emitting one `ObjectiveProgressChanged` per drive. No knob added.
- Merge fix (orchestrator): with MF-3's outcome lock, extracting both drives while survivors remain inside locks the win instead of ending the round; the carry-both test now asserts `is_locked()` and no RoundEnded yet.
- Test file `extraction_test.gd` (snake case); tests emit `EvSurvivorEscaped` directly, since escape detection is Match Flow's and is tested there.
**Test Evidence**: `tests/integration/survivor-objectives/extraction_test.gd`, 6 tests. Mutations caught: every carried drive extracted instead of the escaper's, no EXTRACTED event emitted.
**Code Review**: Complete (orchestrator review; duplicate escape ownership resolved in Match Flow's favour)
