# Story 004: Loading barrier, spawn, round end and return to lobby

> **Epic**: Match Flow & Win Conditions
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

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

- [x] After the roster hand-off (LB-2), the server waits until all clients report the map loaded, then spawns survivors at S1–S5 and the shapeshifter at M1–M3, sets `elapsed_s = 0` and enters Infiltration (rules 2, 3).
- [x] If one client fails to load within `load_timeout_s`, the round is Cancelled, all players return to the lobby and no result is recorded; the rotation queue does not advance (`RosterHandoff.end_round(false)`).
- [x] When an outcome is final the server freezes gameplay input, sends `RoundEnded`, shows Results for `results_duration_s`, then returns every player to the lobby with `RosterHandoff.end_round(true)`; a second round started afterwards holds no state from the first (rules 17, 27).
- [x] If the host leaves, the session closes for every player and the round ends with no result recorded and no forfeit (`lobby-role-assignment.md` rule 19; NA-3 already returns clients to the boot scene).

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

*From `/qa-plan sprint` (production/qa/qa-plan-sprint-005-2026-10-14.md). Implement against these cases.*

- **AC-1**: Loading barrier then spawn
  - Given: a locked roster of 5 on loopback
  - When: every client reports map loaded
  - Then: survivors at S1–S5, shapeshifter at M1–M3, `elapsed_s` 0, Infiltration
  - Edge cases: the last client loads at `load_timeout_s` − 1 tick
- **AC-2**: Load timeout cancels
  - Given: one client never reports loaded
  - When: `load_timeout_s` passes
  - Then: Cancelled, all back in the lobby, no result, rotation queue unchanged
  - Edge cases: client loads on the timeout tick
- **AC-3**: Round end and return
  - Given: a round ended by the deadline
  - When: `results_duration_s` passes
  - Then: input frozen after `RoundEnded`, everyone in the lobby, `end_round(true)`, a second round starts with no state from the first
  - Edge cases: a hold in progress at `RoundEnded` is cancelled
- **AC-4**: Host leaves
  - Given: a running round
  - When: the host process quits
  - Then: clients return to the boot scene, no result recorded
  - Edge cases: host quits during Loading

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/match-flow/round_lifecycle_test.gd` OR playtest doc

**Status**: [x] `tests/integration/match-flow/round_lifecycle_test.gd` (6 tests)

---

## Dependencies

- Depends on: Stories 001, 002
- Unlocks: Stories 005, 006, 007, 009

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: all passing (automated; AC-4 by an ENet loopback test)
**Deviations** (AD-130):
- Implemented by gameplay-programmer (its worktree was cleaned up mid-run, so it worked in the main checkout); reviewed and merged by the orchestrator.
- New `RoundLifecycle` (`src/feature/match_flow/round_lifecycle.gd`) owns the round's MatchFlow and takes both Match Flow slots. States Loading, Running, Results, Over.
- The "map loaded" report is client-to-server bytes on the reliable channel (`map_loaded_packet()` / `is_map_loaded_packet()`, capped at 64 B), never an event. Reports from players off the roster, repeats, and reports outside Loading are ignored.
- A report seen on the tick that reaches `load_timeout_s` still starts the round ("up to", rule 2).
- Survivors spawn at S1.. in roster order; the shapeshifter at one of M1-M3 on an injected rng ("chosen by the server", level doc).
- `spawn`, `freeze` and `over` are Callable hooks for the round composition root, which does not exist yet: nothing outside the test wires `peer_packet`, the body spawn, `ServerMovement.set_frozen` / `HoldService.cancel` or `RoundServer.end_round` + `RosterHandoff.end_round`. The hold-cancel edge case of AC-3 is the `freeze` hook's job and is tested only as "freeze fires once per player on the RoundEnded tick".
- `MatchFlow.begin()` emits `RoundPhaseChanged(INFILTRATION)` once when the barrier opens (rule 3).
- Clients are not yet told about Cancelled or the return to the lobby (story 009 or later UI); "back in the lobby" is verified server-side (lobby Waiting; rotation advances only for Ended).
- AC-4 needs no server code: a host that quits ends the process and `over` is never called.
- Trap found: `StringName` `<` does not sort by text; recorded in `docs/engine-reference/godot/gotchas.md`.
- Test file `round_lifecycle_test.gd` (snake case), not the story's hyphenated name.
**Test Evidence**: `tests/integration/match-flow/round_lifecycle_test.gd`, 6 tests (one real ENet loopback); green in 4 consecutive runs. Mutations caught: load timeout `>=` to `>`, results duration `>=` to `>`, roster check dropped, clock left running in Results.
**Code Review**: Complete (orchestrator review; weak resolve step, untrusted-packet cap, hook wiring gap recorded)
