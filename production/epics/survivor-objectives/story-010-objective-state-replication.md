# Story 010: Objective state replication to clients

> **Epic**: Survivor Objectives
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Every client sees the same objective state, driven only by server state; the carried drive shows on the carrier for everyone who can see them.

**GDD**: `design/gdd/survivor-objectives.md`
**Requirement**: `TR-objectives-009`, `TR-objectives-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication scope and information hiding; secondary: ADR-0005
**ADR Decision Summary**: Per-peer handles and relevance; a peer receives only what it may know; dropped and carried items replicate through the projection, never with identity leaks.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Real ENet on loopback; watch for flakes (BUG-0003).

**Control Manifest Rules (this layer)**:
- Required: run in the `SURVIVOR_OBJECTIVES` tick slot via `server_tick(tick)`; hold owners emit their own catalog events from `on_complete` and `on_cancel`; fake holds take no lock, change no progress and never call the owner (ADR-0002, ADR-0005, ADR-0008)
- Forbidden: never let `HoldService` emit events; never emit an event from a client; never decide discovery from a client report, proximity alone or room entry (ADR-0005, ADR-0008, ADR-0012)
- Guardrail: every `duration_s` and `range_m` comes from `ObjectivesKnobs` (`data/knobs/objectives.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-objectives.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [ ] All 5 clients show identical objective state (checklist, carriers by name, docked and installed counts, terminal state) at every `ObjectiveProgressChanged` (rules 10, 27).
- [ ] Downing a carrier drops the drive at their position on all 5 clients within 200 ms.
- [ ] When evacuation activates, both drives eject at the terminal on all 5 clients.
- [ ] Every value this story uses is read from `ObjectivesKnobs`, not hardcoded.

---

## Implementation Notes

- Project `ObjectiveProgressChanged` through NA-9's event projection; a disguise never shows a carried drive (the shapeshifter cannot carry).
- The HUD display itself is ADR-0014 (Proposed) and the HUD epic's; this story proves the data reaches every client.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- HUD epic: the checklist widget (ADR-0014, Proposed)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/survivor-objectives/objective-state-replication_test.gd` OR playtest doc

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 002, 005
- Unlocks: None
