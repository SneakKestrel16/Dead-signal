# Story 002: Item drops and pickups

> **Epic**: Survivor Objectives
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

## Context

Carried drives and fuses drop when their carrier is downed, eliminated or disconnects, or on purpose, and stay where they fell until a Healthy survivor picks them up.

**GDD**: `design/gdd/survivor-objectives.md`
**Requirement**: `TR-objectives-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order; secondary: ADR-0008
**ADR Decision Summary**: Server-only typed events on the `EventBus`; owner-written state in the `StateRegistry`; Objectives runs in the `SURVIVOR_OBJECTIVES` (600) slot after Holds.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff APIs; item positions snap to the nearest valid floor point, no physics.

**Control Manifest Rules (this layer)**:
- Required: run in the `SURVIVOR_OBJECTIVES` tick slot via `server_tick(tick)`; hold owners emit their own catalog events from `on_complete` and `on_cancel`; fake holds take no lock, change no progress and never call the owner (ADR-0002, ADR-0005, ADR-0008)
- Forbidden: never let `HoldService` emit events; never emit an event from a client; never decide discovery from a client report, proximity alone or room entry (ADR-0005, ADR-0008, ADR-0012)
- Guardrail: every `duration_s` and `range_m` comes from `ObjectivesKnobs` (`data/knobs/objectives.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-objectives.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [x] Downing a carrier drops every item they carry at their position, and another Healthy survivor can pick it up with a `pickup_s` hold; a rescued former carrier does not get it back automatically (rule 12).
- [x] Elimination or disconnect drops carried items at the last position at once; a dropped item never despawns, respawns or is destroyed, and is placed at the nearest valid floor point (rule 13, edge cases).
- [x] A survivor can drop a drive or fuse on purpose (instant) (rules 11, 15).
- [x] Every value this story uses is read from `ObjectivesKnobs`, not hardcoded.

---

## Implementation Notes

- React to `SurvivorDowned`, `SurvivorEliminated` and `PlayerConnectionChanged` (disconnect); Downing and Match Flow emit them — tests emit them directly until those epics land.
- A dropped item is a new `Interactable` (pickup hold) at the drop point.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 010: replication of drops to clients within 200 ms

---

## QA Test Cases

*From `/qa-plan sprint` (production/qa/qa-plan-sprint-005-2026-10-14.md). Implement against these cases.*

- **AC-1**: Down drops, pickup by another
  - Given: a carrier with a drive
  - When: `SurvivorDowned`, then another survivor holds pickup
  - Then: drive Dropped at the position, then Carried by the other; rescue does not return it
  - Edge cases: carrier with drive and fuse drops both
- **AC-2**: Elimination and disconnect drops
  - Given: carriers
  - When: `SurvivorEliminated` / disconnect
  - Then: items drop at once at the nearest valid floor point and never despawn
  - Edge cases: drop point inside geometry
- **AC-3**: Manual drop
  - Given: a carrier
  - When: drops on purpose
  - Then: item Dropped instantly
  - Edge cases: drop during a hold

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/survivor-objectives/drops_and_pickups_test.gd` OR playtest doc

**Status**: [x] `tests/integration/survivor-objectives/drops_and_pickups_test.gd` (18 tests)

---

## Dependencies

- Depends on: Story 001
- Unlocks: Story 006

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: all passing (automated)
**Deviations** (AD-137):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 748/748 after the wave merge, no leak warnings.
- Carried drives and fuses drop on SurvivorDowned, SurvivorEliminated and disconnect; `drop(actor, objective)` is the deliberate drop; `dropped_at(objective)` gives the pickup point.
- Drop point = `position_of(actor)` snapped to the nearest map volume's floor (inference: no floor data finer than volumes; props not avoided). Without `position_of`, items drop at the terminal.
- Moved pickup points instead of the story's new Interactable per drop: net ids stay stable, no unregister. FuseSpawn is eligible only while UNFOUND.
- Nothing in the input layer calls `drop()` yet; drop replication is story 010.
**Test Evidence**: 18 tests. Mutations caught: drop on every connection status, fuse spawn eligible while DROPPED, floor snap 0, ejection not resetting the pickup (test added).
**Code Review**: Complete (orchestrator review at merge)
