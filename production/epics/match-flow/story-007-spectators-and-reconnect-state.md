# Story 007: Spectators and full state on reconnect

> **Epic**: Match Flow & Win Conditions
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Eliminated and Escaped players watch a living survivor; a reconnecting player gets the whole current state, not a diff. NA-10 built the spectator stream and the handle reset; this story decides who watches whom and when.

**GDD**: `design/gdd/match-flow.md`
**Requirement**: `TR-matchflow-006`, `TR-matchflow-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication scope and information hiding; secondary: ADR-0001
**ADR Decision Summary**: Per-peer handles and relevance; spectators get the stream of the survivor they watch; a reconnecting client gets a full fresh state (handle reset).
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: Uses NA-10's `ServerMovement.watch` / handle reset; real ENet on loopback.

**Control Manifest Rules (this layer)**:
- Required: implement `server_tick(tick)` and register with `TickRunner` in the `MATCH_FLOW_BEGIN` / `MATCH_FLOW_RESOLVE` slots; never rely on `_physics_process` (ADR-0002, ADR-0005)
- Forbidden: never emit an event from a client (ADR-0005); never let Match Flow tally other systems' stats or call into their modules (ADR-0011, Proposed)
- Guardrail: every tuning value comes from `MatchFlowKnobs` (`data/knobs/match_flow.tres`)

---

## Acceptance Criteria

*From GDD `design/gdd/match-flow.md` (Acceptance Criteria and Core Rules), scoped to this story:*

- [x] When a survivor is Eliminated or Escaped, the server makes them a spectator of a living survivor; they receive exactly that survivor's stream and can send no ping or callout to living players (rule 10, `match-flow.md` TR-matchflow-009).
- [x] When the watched survivor is eliminated or escapes, the spectator is moved to another living survivor; when none is left, spectating ends with the round.
- [x] A client reconnecting mid-round receives the current clock, phase, roster and every replicated state it needs, with an entirely new handle set (ADR-0004 §9).

---

## Implementation Notes

- Call `ServerMovement.watch(spectator, target)`; NA-10's tests already prove the stream and the RESET.
- Pick the next target deterministically (lowest player id still living) so tests are stable; a spectator switch request is the HUD epic's.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- HUD epic: spectator UI and switch requests

---

## QA Test Cases

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/match-flow/spectators_and_reconnect_state_test.gd` OR playtest doc

**Status**: [x] `tests/integration/match-flow/spectators_and_reconnect_state_test.gd` (7 tests)

---

## Dependencies

- Depends on: Stories 003, 005
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-158):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 849/849 (prediction_reconcile 9 failures under parallel agent load; 9/9 alone, BUG-0003 class) after the wave merge, no leak warnings.
- `server_movement.gd` merge kept both the NA-7 `history` and MF-7 `catch_up` blocks.
- Composer must register the catch-up callables (no round composer yet).
**Test Evidence**: 7 tests.
**Code Review**: Complete (orchestrator review at merge)
