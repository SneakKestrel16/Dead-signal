# Story 008: Active point selection

> **Epic**: Survivor Objectives
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]


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

- [ ] With a fixed seed, over 20 rounds the active points vary (at least 4 distinct drive pairs, all 3 terminal candidates appear), all come from authored candidates (6 drive, 7 fuse, 3 fuse box, 3 terminal), and no round breaks a rule 6 constraint.
- [ ] Candidate counts come from data and must match the map; a mismatch fails load-time validation.
- [ ] Every value this story uses is read from `ObjectivesKnobs`, not hardcoded.

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
- Logic: `tests/unit/survivor-objectives/active-point-selection_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: Story 009
