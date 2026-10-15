# Story 002: Item drops and pickups

> **Epic**: Survivor Objectives
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] Downing a carrier drops every item they carry at their position, and another Healthy survivor can pick it up with a `pickup_s` hold; a rescued former carrier does not get it back automatically (rule 12).
- [ ] Elimination or disconnect drops carried items at the last position at once; a dropped item never despawns, respawns or is destroyed, and is placed at the nearest valid floor point (rule 13, edge cases).
- [ ] A survivor can drop a drive or fuse on purpose (instant) (rules 11, 15).
- [ ] Every value this story uses is read from `ObjectivesKnobs`, not hardcoded.

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

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/survivor-objectives/drops-and-pickups_test.gd` OR playtest doc

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: Story 006
