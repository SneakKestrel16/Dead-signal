# Story 009: Per-volume lighting state machine and precedence

> **Epic**: Facility Map
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]


## Context

Each lighting volume has a base state from the round (Low Power, Investigation, Power Restored, Evacuation) and overlays such as Blackout. The server resolves precedence; clients only show it.

**GDD**: `design/levels/research-facility.md`
**Requirement**: `TR-facility-004`, `TR-facility-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009: Lighting states and Blackout (Proposed)
**ADR Decision Summary**: Server-owned per-volume lighting state with base states and overlays, precedence rules and a reset on `RoundEnded`.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Per ADR-0009 once Accepted.

**Control Manifest Rules (this layer)**:
- Required: (Proposed) rules per ADR-0009 — re-check the control manifest once it is Accepted

---

## Acceptance Criteria

*From `research-facility.md` Lighting States, Edge Cases and Acceptance Criteria 12, scoped to this story:*

- [ ] Terminal armed during Infiltration goes Power Restored straight to Evacuation; the Investigation flicker never plays.
- [ ] A Blackout in a room when Power Restored lands keeps it dark for the rest of the Blackout, then shows Power Restored; in the active terminal room Evacuation ends the Blackout at once, elsewhere it runs out first.
- [ ] Both fuses, then Evacuation, then a Blackout in a Zone B room: the room is dark with emergency strips; when the Blackout ends it shows Evacuation, not Power Restored.
- [ ] After `RoundEnded` every volume is Low Power with no overlays.

---

## Implementation Notes

*Derived from ADR-0009 (Proposed) and `research-facility.md` Lighting States:*

- Pure state logic per volume; rendering is Story 010.

---

## Out of Scope

- Story 010: rendering and replication

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/facility-map/lighting_state_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001; ADR-0009 Accepted
- Unlocks: Story 010; Monster Abilities (Blackout), Scare Events epics
