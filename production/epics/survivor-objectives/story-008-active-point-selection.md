# Story 008: Active point selection

> **Epic**: Survivor Objectives
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15


## Context

Each round the server draws the active drive rooms, fuse spawns, fuse boxes and terminal from the authored candidates under the placement constraints.

**GDD**: `design/gdd/survivor-objectives.md`
**Requirement**: `TR-objectives-002`, `TR-objectives-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Objective discovery (Proposed); secondary: ADR-0005, ADR-0006
**ADR Decision Summary**: Active points drawn with the injected seeded RNG from rule-6-valid placements; discovery through the one server `SightTest`; undiscovered points stay ungranted on survivor peers.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: LOW
**Engine Notes**: Seeded `RandomNumberGenerator` injected; never the global `randi()`.

**Control Manifest Rules (this layer)**:
- Required: run in the `SURVIVOR_OBJECTIVES` tick slot via `server_tick(tick)`; hold owners emit their own catalog events from `on_complete` and `on_cancel`; fake holds take no lock, change no progress and never call the owner (ADR-0002, ADR-0005, ADR-0008)
- Forbidden: never let `HoldService` emit events; never emit an event from a client; never decide discovery from a client report, proximity alone or room entry (ADR-0005, ADR-0008, ADR-0012)
- Guardrail: every `duration_s` and `range_m` comes from `ObjectivesKnobs` (`data/knobs/objectives.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-objectives.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [x] With a fixed seed, over 20 rounds the active points vary (at least 4 distinct drive pairs, all 3 terminal candidates appear), all come from authored candidates (6 drive, 7 fuse, 3 fuse box, 3 terminal), and no round breaks a rule 6 constraint.
- [x] Candidate counts come from data and must match the map; a mismatch fails load-time validation.
- [x] Every value this story uses is read from `ObjectivesKnobs`, not hardcoded.

---

## Implementation Notes

- Follow ADR-0012 once Accepted: draw from the load-time list of rule-6-valid placements with the injected RNG.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009: discovery

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/survivor-objectives/active_point_selection_test.gd` — must exist and pass

**Status**: [x] `tests/unit/survivor-objectives/active_point_selection_test.gd` (6 tests)

---

## Dependencies

- Depends on: Story 001
- Unlocks: Story 009

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-205):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 1110/1110 after the wave merge, no leak warnings.
- Rule-6 constraint checks, the 1,000-seed check and the 2,280 count are reused from FM-7's candidate_selection_test rather than re-tested.
- Active counts (2/2/2/1) stay constants: the GDD lists them as rules, not knobs; AC3 covers the candidate-count knobs.
- Ten existing integration suites pin `placement = FirstMarkers.of(map)` so their hard-coded positions hold.
- Test file snake_case, not the story's hyphenated name. A five_client_agreement_test failure in the agent's batch run passed alone (BUG-0003 class).
**Test Evidence**: 6 tests. Mutations caught: rng ignored, candidate-count check disabled, map order instead of the draw, placement override ignored.
**Code Review**: Complete (orchestrator review at merge)
