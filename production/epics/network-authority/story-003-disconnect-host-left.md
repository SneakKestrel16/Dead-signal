# Story 003: Disconnect detection and host leaving

> **Epic**: Network Authority & Replication
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

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

*N/A — no qa-lead specs at this tier (QL-STORY-READY skipped, lean review mode); implement against the Acceptance Criteria above.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/network/disconnect_host_left_test.gd` — must exist and pass; the real-network timeout is a documented two-PC test in `production/qa/evidence/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002
- Unlocks: None
