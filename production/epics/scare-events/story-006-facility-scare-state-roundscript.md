# Story 006: Facility scare state machine and RoundScript anchors

> **Epic**: Scare Events
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

On `RoundPhaseChanged` and `ObjectiveProgressChanged` the server sets the facility scare state (Low, Rising, Emergency, Results, plus Blackout and Power Restored overlays). RoundScript environment scares fire only at authored anchors from per-phase, per-zone lists. Facility Map owns lighting; this system adds only flicker. A reconnecting client gets the current state, never a replay.

**GDD**: `design/gdd/scare-events.md` rules 6, 22, 23; States and Transitions
**Requirement**: `TR-scare-007`, `TR-scare-004`, `TR-scare-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009: Lighting states and Blackout; secondary: ADR-0005, ADR-0006
**ADR Decision Summary**: Only `FacilityMap` writes lighting; Scare reads `LightingView` and requests no lighting state.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API; plain GDScript over existing Foundation and Core modules.

**Control Manifest Rules (this layer)**:
- Forbidden: Scare never writes lighting state
- Required: RoundScript fires only at the map's 9 authored scare anchors

---

## Acceptance Criteria

*From GDD `design/gdd/scare-events.md`, scoped to this story:*

- [ ] All 5 clients enter Emergency state within one network round trip of `RoundPhaseChanged` to Evacuation.
- [ ] A RoundScript scare fires only when a player reaches an authored anchor and the gating of story 002 allows it.
- [ ] A client that reconnects mid-round shows the current facility scare state within one network round trip and replays no missed scare.

---

## Implementation Notes

- Scare anchors are in `data/maps/research_facility.tres` (TR-facility-001 lists 9); check the loader exposes them.
- Send the state on the existing reconnect catch-up path (match-flow story 012).

---

## Out of Scope

- Story 009: strobe and beacon visuals.

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (lean review); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/scare-events/facility_scare_state_roundscript_test.gd` (real ENet where the AC names clients)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001, 002
- Unlocks: Story 009
