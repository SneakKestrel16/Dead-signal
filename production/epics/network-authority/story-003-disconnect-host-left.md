# Story 003: Disconnect detection and host leaving

> **Epic**: Network Authority & Replication
> **Status**: In Progress
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

Unblocked 2026-10-13: ADR-0001..0008 Accepted. 

## Context

Dead peers are found by the ENet timeout and routed to whoever owns the phase: the lobby removes them at once, Match Flow starts the reconnect grace. If the host leaves, the session ends for everyone.

**GDD**: `design/gdd/lobby-role-assignment.md`, `design/gdd/match-flow.md`
**Requirement**: `TR-lobby-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Hosting, Session Join and Reconnect
**ADR Decision Summary**: `ENetPacketPeer.set_timeout` from data on both sides; on `peer_disconnected` Network maps to the player ID and notifies the phase owner; the grace clock starts at detection; clients receiving `server_disconnected` return to the main menu with "Host left" and record no result.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Verification results (1): default dead-peer detection 5.8 s on loopback; `set_timeout(32, 1000, 2000)` gives 3.0 s. Real-network timing is NOT RUN.

**Control Manifest Rules (this layer)**:
- Required: ENet timeout from data
- Forbidden: host migration
- Guardrail: none specific

---

## Acceptance Criteria

*From ADR-0001 §6–7; `lobby-role-assignment.md` AC-LB-29, scoped to this story:*

- [ ] A client killed without closing is reported dropped within the configured ENet timeout (± one tick) on the server.
- [ ] In Waiting and Countdown the player is removed from the lobby at once; in a round `PlayerConnectionChanged` is emitted and grace starts at detection.
- [ ] When the host quits in Waiting, Countdown or In Match, every client returns to the main menu with "Host left" and no result is recorded.

---

## Implementation Notes

*Derived from ADR-0001 Decision and Implementation Guidelines:*

- Set the timeout on the server in `peer_connected` and on the client after connecting.
- Network only routes; Lobby and Match Flow own what happens next.

---

## Out of Scope

- Match Flow epic: grace expiry and forfeit rules

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-003-2026-10-14.md` (/qa-plan, 2026-10-14). Implement against these and the Acceptance Criteria above.*

**What to test**:
- Server and client both call `ENetPacketPeer.set_timeout` with values from knobs (server in `peer_connected`, client after connecting). Assert the values read back match the knobs, not literals.
- A client killed without closing (stop polling its peer, no `close()`) is reported dropped on the server within the configured timeout ± one tick. Loopback reference: `set_timeout(32, 1000, 2000)` gives 3.0 s (story Engine Notes).
- Lobby in Waiting and in Countdown: the dropped player is removed from the lobby on the detection tick.
- In a round: `PlayerConnectionChanged` is emitted once, and the grace clock's start tick equals the detection tick.
- Host quits in Waiting, Countdown and In Match (three cases): every client receives `server_disconnected`, ends in the boot scene with "Host left", and no result is recorded.

**Edge cases to cover**:
- Disconnect in the same tick the countdown reaches 0: the lock re-checks rule 13 and returns to Waiting (lobby-role-assignment Edge Cases).
- The host is the shapeshifter and leaves mid-round: session closes, no forfeit, no result (lobby-role-assignment Edge Cases, rule 19).
- Network only routes: assert it calls the phase owner and does not itself remove players or start grace (Implementation Notes).
- No host migration path exists (control manifest Forbidden).

**Estimated test count**: ~8 integration tests

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/network/disconnect_host_left_test.gd` — must exist and pass; the real-network timeout is a documented two-PC test in `production/qa/evidence/`

**Status**: [x] `tests/integration/network/disconnect_host_left_test.gd` passes (11 tests); full suite 241/241, 0 orphans (2026-10-14). Dead-peer detection 1.22 s on loopback with `set_timeout(32, 1000, 2000)`; both timing tests fail (> 5 s) with `set_timeout` disabled. Screenshot: `production/qa/evidence/network-authority-003-host-left.png`. Real-network timing: NA-V NAV-14/15 (designer).

**Deviations**:
- No Match Flow exists, so `ConnectionRouter` (`src/core/session/`) starts grace and emits `PlayerConnectionChanged` in a round; the systems index names Match Flow as the emitter, which takes this over in its epic (AD-85).
- "Main menu" is the boot scene `src/main.tscn` (`Main.return_with`), until lobby-role-assignment story 005.
- "No result is recorded": no result store exists yet; `Main.return_with` writes nothing.

---

## Dependencies

- Depends on: Story 002
- Unlocks: None
