# Story 006: Facility scare state machine and RoundScript anchors

> **Epic**: Scare Events
> **Status**: Complete
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

- [x] All 5 clients enter Emergency state within one network round trip of `RoundPhaseChanged` to Evacuation.
- [x] A RoundScript scare fires only when a player reaches an authored anchor and the gating of story 002 allows it.
- [x] A client that reconnects mid-round shows the current facility scare state within one network round trip and replays no missed scare.

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

**Status**: [x] `tests/integration/scare-events/facility_scare_state_roundscript_test.gd` (5 cases, 2 over real ENet)

---

## Dependencies

- Depends on: Stories 001, 002
- Unlocks: Story 009

## Progress Notes (2026-10-15)

Merged from wt-se6. Full suite 1350/1350, no leak lines. Mutations caught: rejoin ignoring `full`, Evacuation mapped to Rising, firing every tick instead of on entry, phase filter removed, parked-body guard removed.

Notes:
- `FacilityScareState` (SCARE_EVENTS + 1) runs Low, Rising, Emergency, Results (Low straight to Emergency on an early Evacuation), with a Power Restored flag from the terminal; it never writes lighting. Sent as `EventBatch.FACILITY_SCARE` on change and in full on rejoin; nothing added to `catch_up`, so missed scares are never replayed.
- `RoundScript` (SCARE_EVENTS + 2) fires each RoundScript catalogue entry naming an anchor when a player enters the anchor's volume in a listed phase; gating (story 002) applies inside `fire()`.
- `FacilityScareDisplay` is the client stub; presentation is story 009.

**Resolved 2026-10-15 (was Open): the shipped map carries the scare anchors.** Designer approved the edit ("okay 8"): `data/maps/research_facility.tres` now has 9 `MapMarker` entries `type = &"scare_anchor"` (sd1 A3 (9.5,0,19), sd2 A4 (17.5,0,25.5), sd3 A6 (5.5,0,4.5), sd4 B1 (31.5,0,27.5), sd5 C2 (45.5,0,27.5), sd6 C5 (44.5,0,13.5), sg1 A3 (9.5,0,24), sg2 A4 (13.5,0,17), sg3 A7 (17.5,0,13.5)); `&"scare_anchor"` is in `MapData.MARKER_TYPES`; `map_data_test` counts and rooms updated. Positions are inference from the level doc's Scare anchors table, door positions and volume boxes (comment in the map file). Net ids unchanged: the 64 interactables compared before and after are identical. The scare-events tests no longer inject anchors; `monster_source_scares_test` ignores scares at anchor origins (spawns now enter anchor rooms).

Shipped-map evidence (2026-10-15): `round_host.gd -- --port=30990 --players=5 --self-clients --force=8:anchor`, no injection, logged `tick 481 ScareTriggered slammed_door source 2 origin (9.5, 0.0, 19.0) to 0` (and to 2, 3, 4): a RoundScript scare at sd1. Suites scare-events + facility-map (unit and integration) + event_catalog: 227/227, no leak lines. No Visual sign-off is required (Integration story); Status stays In Review only until `/story-done` closes it.

Deviations (inference):
- "Reaches an anchor" = enters the anchor's lighting volume; the GDD gives no trigger radius.
- Every live player receives a RoundScript scare until story 003's audible-range relevance lands.
- "Within one round trip" is checked as delivery in the same tick's reliable batch.
- Blackout is not part of the facility state (the map already replicates per-volume lighting).

## Closed (2026-10-15)

The designer approved the map edit (AD-241). The shipped map now holds the 9 scare anchors, and the 64 interactable net ids are unchanged. A standalone round on the shipped map fired `tick 481 ScareTriggered slammed_door source 2 origin (9.5, 0.0, 19.0)` with nothing injected. Full suite on merge: 1572 tests, 0 failures, 0 leak lines. Anchor positions are inference from the level doc.
