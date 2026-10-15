# Story 009: Objective discovery

> **Epic**: Survivor Objectives
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15


## Context

Fuse boxes and the terminal are always known to survivors; a drive room or fuse spawn becomes known to all survivors once any survivor has seen it within range.

**GDD**: `design/gdd/survivor-objectives.md`
**Requirement**: `TR-objectives-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Objective discovery (Proposed); secondary: ADR-0004
**ADR Decision Summary**: Active points drawn with the injected seeded RNG from rule-6-valid placements; discovery through the one server `SightTest`; undiscovered points stay ungranted on survivor peers.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Server `SightTest` in TickRunner physics phases (ADR-0012).

**Control Manifest Rules (this layer)**:
- Required: run in the `SURVIVOR_OBJECTIVES` tick slot via `server_tick(tick)`; hold owners emit their own catalog events from `on_complete` and `on_cancel`; fake holds take no lock, change no progress and never call the owner (ADR-0002, ADR-0005, ADR-0008)
- Forbidden: never let `HoldService` emit events; never emit an event from a client; never decide discovery from a client report, proximity alone or room entry (ADR-0005, ADR-0008, ADR-0012)
- Guardrail: every `duration_s` and `range_m` comes from `ObjectivesKnobs` (`data/knobs/objectives.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-objectives.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [x] A drive room or fuse spawn appears on all survivor clients once any survivor has had it in view within `discover_range_m`, and not before; a survivor client receives no data for an undiscovered point (rule 7).
- [x] The shapeshifter is told every active point at round start; hidden survivors and the shapeshifter never discover.
- [x] Every value this story uses is read from `ObjectivesKnobs`, not hardcoded.

---

## Implementation Notes

- Follow ADR-0012 once Accepted: one server `SightTest`; an undiscovered point stays ungranted on every survivor peer (NA-10 grant/hidden spawner).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- HUD epic: drawing the markers

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/survivor-objectives/discovery_test.gd` OR playtest doc

**Status**: [x] `tests/integration/survivor-objectives/discovery_test.gd` (4 tests)

---

## Dependencies

- Depends on: Story 008
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-212):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 1151/1151 after the wave merge, no leak warnings.
- Borrowed Face's _observable not moved onto SightTest (other epic's file; its rule rays to all body points). Follow-up.
- SightTest takes a line_clear Callable (MapQueries.clear_sight) instead of the ADR's (space, doors: DoorBoxes); no DoorBoxes type exists.
- One sample point per objective: marker raised by capsule_height_m/2 (inference; authored per-room sample points would settle it).
- Replication and the monster's round-start grant are FM-8's test.
**Test Evidence**: 4 tests. Mutations caught: range check removed, cone check removed, hidden check removed, once-only removed.
**Code Review**: Complete (orchestrator review at merge)
