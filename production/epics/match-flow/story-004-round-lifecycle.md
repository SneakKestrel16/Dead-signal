# Story 004: Loading barrier, spawn, round end and return to lobby

> **Epic**: Match Flow & Win Conditions
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Everything around the clock: the server waits for every client to load, spawns them, and after the result returns everyone to the lobby with all round state reset. This is the story that turns the parts into a round a player can enter.

**GDD**: `design/gdd/match-flow.md`
**Requirement**: `TR-matchflow-003`, `TR-matchflow-010`, `TR-matchflow-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order; secondary: ADR-0001
**ADR Decision Summary**: Server-only typed events on the `EventBus`; owner-written state in the `StateRegistry`; Match Flow runs in the `MATCH_FLOW_BEGIN` (100) and `MATCH_FLOW_RESOLVE` (900) slots.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Uses the existing `RoundServer`, `RosterHandoff` and the network layer over real ENet on loopback in tests; watch for real-ENet flakiness (BUG-0003).

**Control Manifest Rules (this layer)**:
- Required: implement `server_tick(tick)` and register with `TickRunner` in the `MATCH_FLOW_BEGIN` / `MATCH_FLOW_RESOLVE` slots; never rely on `_physics_process` (ADR-0002, ADR-0005)
- Forbidden: never emit an event from a client (ADR-0005); never let Match Flow tally other systems' stats or call into their modules (ADR-0011, Proposed)
- Guardrail: every tuning value comes from `MatchFlowKnobs` (`data/knobs/match_flow.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/match-flow.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [ ] After the roster hand-off (LB-2), the server waits until all clients report the map loaded, then spawns survivors at S1–S5 and the shapeshifter at M1–M3, sets `elapsed_s = 0` and enters Infiltration (rules 2, 3).
- [ ] If one client fails to load within `load_timeout_s`, the round is Cancelled, all players return to the lobby and no result is recorded; the rotation queue does not advance (`RosterHandoff.end_round(false)`).
- [ ] When an outcome is final the server freezes gameplay input, sends `RoundEnded`, shows Results for `results_duration_s`, then returns every player to the lobby with `RosterHandoff.end_round(true)`; a second round started afterwards holds no state from the first (rules 17, 27).
- [ ] If the host leaves, the session closes for every player and the round ends with no result recorded and no forfeit (`lobby-role-assignment.md` rule 19; NA-3 already returns clients to the boot scene).

---

## Implementation Notes

- The loading barrier is a server-side set of peers that sent "map loaded"; the RPC is client-to-server input, never an event (ADR-0005 forbids client events).
- Spawn points come from Facility Map data; the round's modules are built and torn down by `RoundServer.start_round` / `end_round`, which already clears the bus and registry.
- Freezing input: stop applying gameplay intents after Ended (the controller reads `RoundEnded` per the controller GDD).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009: what clients display (clock, phase, outcome)
- Main menu and round scene presentation: a later UI story

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/match-flow/round-lifecycle_test.gd` OR playtest doc

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001, 002
- Unlocks: Stories 005, 006, 007, 009
