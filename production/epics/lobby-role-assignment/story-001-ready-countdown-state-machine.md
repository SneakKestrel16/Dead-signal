# Story 001: Ready and countdown state machine

> **Epic**: Lobby & Role Assignment
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

## Context

The lobby moves Waiting → Countdown → In Match → Closed on the server clock. The countdown starts only when every connected player is Ready and the minimum is met, restarts on any change, and re-checks at lock. Phase M1.

**GDD**: `design/gdd/lobby-role-assignment.md`
**Requirement**: `TR-lobby-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Authoritative simulation, tick and input
**ADR Decision Summary**: All timers are tick-counted on the server clock (`Knobs.ticks`); clients only display the state the server replicates.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Plain GDScript on an injected clock; no engine API.

**Control Manifest Rules (this layer)**:
- Required: timers in ticks from data (`Knobs.ticks`)
- Forbidden: client-decided state transitions

---

## Acceptance Criteria

*From `lobby-role-assignment.md` AC-LB-05, AC-LB-21, AC-LB-22, AC-LB-23, scoped to this story:*

- [x] With an injected clock and 5 players all Ready at t = 100.0, remaining = 1.8 at t = 103.2, the roster locks at t = 105.0, and remaining stays within [0, 5]; the countdown does not start while `ready_count < connected`.
- [x] During a countdown, an un-ready, a leave or a join each alone returns the lobby to Waiting; when all are Ready again the countdown restarts at the full `lobby_countdown_s`.
- [x] A disconnect processed in the same tick remaining reaches 0 makes the lock re-check rule 13, return to Waiting and hand no roster to Match Flow.
- [x] With 3 connected players all Ready the lobby stays in Waiting and the roster holds only the 3 human tokens (no bot seat).

---

## Implementation Notes

*Derived from `lobby-role-assignment.md` Detailed Design (states, rule 13) and ADR-0002:*

- `LobbyState` owns state, ready set and remaining ticks; inject the clock and `LobbyKnobs`.
- `min_players` / `max_players` from `LobbyKnobs` (MVP 5/5, code supports 4–6).

---

## Out of Scope

- Story 002: roster lock and hand-off
- Join validation (network-authority story 001)

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-002-2026-10-13.md` (/qa-plan, 2026-10-13). Implement against these and the Acceptance Criteria above.*

**What to test**:
- Injected clock, 5 players all Ready at t = 100.0: remaining = 1.8 at t = 103.2, the roster locks at t = 105.0, and remaining stays in [0, 5]. The countdown does not start while `ready_count < connected`.
- During a countdown, an un-ready, a leave or a join alone each return the lobby to Waiting. Once all are Ready again, the countdown restarts at the full `lobby_countdown_s`.
- A disconnect processed in the same tick that remaining reaches 0 makes the lock re-check rule 13, return to Waiting, and hand no roster to Match Flow.
- With 3 connected players all Ready, the lobby stays in Waiting and the roster holds only the 3 human tokens.

**Edge cases to cover**:
- Remaining exactly 0 on a tick boundary.
- All players un-ready at once.
- The value comes from `lobby_countdown_s` in data (a test with a fixture value).

**Estimated test count**: ~9 unit tests

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/lobby/lobby_state_test.gd` — must exist and pass

**Status**: [x] `tests/unit/lobby/lobby_state_test.gd` passes (13 tests). 7 mutants were caught: the min_players check, each cancel trigger, a stale start tick, the Ready check and a double lock. Suite 214/214 (2026-10-14).

---

## Dependencies

- Depends on: data-config story 002 (`LobbyKnobs`); network-authority story 004
- Unlocks: Stories 002, 005

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: 4/4 passing, all automated in `tests/unit/lobby/lobby_state_test.gd` (13 tests).
**Deviations**:
- There is no explicit lock-time re-check of rule 13. Every trigger (un-ready, leave, join) cancels the moment it is applied, so the lock tick cannot be reached with rule 13 false. Both reviewers confirmed this. AC3 is tested by its behaviour (AD-78).
- In Match, the lobby is dormant. Membership changes are kept for the return to Waiting (AC-LB-27, a later story). The locked roster is not touched.
**Code review**: godot-gdscript-specialist and qa-tester. Nothing blocking. Applied:
- Renamed `_ready` to `_ready_by_token` and the `ready` parameter to `is_ready`.
- The dictionary is now typed.
- The Ready check no longer allocates.
- New tests: the min_players boundary (4 vs 5), a repeated join and an unknown leave, and the roster locking only once with later In Match changes ignored.
Not applied:
- An assert against a non-monotonic tick. It is harmless today because `remaining` clamps.
- An empty-lobby guard. The `min_players` range is 4..5, enforced by the knob validator.
**Not wired yet**: nothing creates a LobbyState at runtime. NetAuthority still takes an injected lobby object; Story 002 (roster hand-off) and Story 005 (lobby screen) connect it.
**Test Evidence**: Logic: `tests/unit/lobby/lobby_state_test.gd`.
