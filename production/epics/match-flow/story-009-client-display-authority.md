# Story 009: Clients display server phase and outcome only

> **Epic**: Match Flow & Win Conditions
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

## Context

Clients show the clock and phase the server replicates and never decide anything; a modified client cannot change the round.

**GDD**: `design/gdd/match-flow.md`
**Requirement**: `TR-matchflow-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Event catalog, state registry and tick order; secondary: ADR-0002, ADR-0004
**ADR Decision Summary**: Server-only typed events on the `EventBus`; owner-written state in the `StateRegistry`; Match Flow runs in the `MATCH_FLOW_BEGIN` (100) and `MATCH_FLOW_RESOLVE` (900) slots.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Real ENet on loopback; timing assertions use the tick count, with the 200 ms bound checked against loopback only.

**Control Manifest Rules (this layer)**:
- Required: implement `server_tick(tick)` and register with `TickRunner` in the `MATCH_FLOW_BEGIN` / `MATCH_FLOW_RESOLVE` slots; never rely on `_physics_process` (ADR-0002, ADR-0005)
- Forbidden: never emit an event from a client (ADR-0005); never let Match Flow tally other systems' stats or call into their modules (ADR-0011, Proposed)
- Guardrail: every tuning value comes from `MatchFlowKnobs` (`data/knobs/match_flow.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/match-flow.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [x] All 5 clients show the same phase within 200 ms of each `RoundPhaseChanged`, and the same outcome, reason and results payload at round end.
- [x] A modified client that sends a fake "round won" or "phase change" message has no effect on any client's state.
- [x] A client whose local clock drifts corrects its display to the server value; its phase changes only on `RoundPhaseChanged`.

---

## Implementation Notes

- Clients receive phase and clock through the existing event projection (NA-9) and snapshots; there is no client-to-server message for phase or outcome, so a fake one has no handler — the test sends raw bytes to prove it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- HUD epic: the clock and phase widgets

---

## QA Test Cases

*From `/qa-plan sprint` (production/qa/qa-plan-sprint-005-2026-10-14.md). Implement against these cases.*

- **AC-1**: Same phase on all clients
  - Given: 5 clients on loopback
  - When: each `RoundPhaseChanged`
  - Then: every client shows it within 200 ms; same outcome and payload at round end
  - Edge cases: phase change during a reconnect
- **AC-2**: Fake messages ignored
  - Given: a modified client
  - When: sends raw "round won" / "phase change" bytes
  - Then: no client state changes
  - Edge cases: malformed packet
- **AC-3**: Clock drift corrected
  - Given: a client with a skewed local clock
  - When: snapshots arrive
  - Then: display matches the server value; phase changes only on the event
  - Edge cases: client clock ahead by 10 s

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/match-flow/client_display_authority_test.gd` OR playtest doc

**Status**: [x] `tests/integration/match-flow/client_display_authority_test.gd` (5 tests)

---

## Dependencies

- Depends on: Story 004
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: 3/3 passing (automated; real ENet loopback for AC-1 and AC-2)
**Deviations** (AD-135):
- Implemented by network-programmer in a git worktree, in parallel with SO-2; reviewed and merged by the orchestrator.
- New client-only `MatchDisplay` (`src/feature/match_flow/match_display.gd`, not `*_view.gd`: that suffix means a getter-only registry view to `state_registry_test`). It applies only packets from the server peer; phase changes only on a RoundPhaseChanged entry, outcome/reason/results only on RoundEnded; bad payloads are rejected and counted.
- No new wire field, key or knob for the clock: a client derives `elapsed = (snapshot tick - tick of the RoundPhaseChanged(Infiltration) batch) / sim_tick_hz`, which equals MatchFlow's tick count (clock 0 at begin, rule 3); the RoundEnded batch tick freezes it. Local time only extrapolates between snapshots; each newer snapshot snaps to the server value, an older reordered one never moves it back.
- A client reconnecting mid-round has no clock or phase until the server re-sends round state (story 007).
- Investigation is not reached over ENet (7200 ticks); the hand-fed AC-3 test covers it.
**Test Evidence**: `tests/integration/match-flow/client_display_authority_test.gd`, 5 tests (5 real clients for AC-1; 7 fake packets for AC-2); green 3 runs. Mutations caught: server-peer filter removed, snap to server value removed.
**Code Review**: Complete (orchestrator review)
