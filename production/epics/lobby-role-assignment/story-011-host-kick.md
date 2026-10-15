# Story 011: Host kick (post-M1)

> **Epic**: Lobby & Role Assignment
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Post-M1 phase. The host can remove a player who never readies. The kicked player keeps their queue position and may rejoin.

**GDD**: `design/gdd/lobby-role-assignment.md`
**Requirement**: `TR-lobby-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Hosting, session join and reconnect
**ADR Decision Summary**: Host actions are server-validated requests; tokens key queue position across disconnects.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: As network-authority story 003 (disconnect handling).

**Control Manifest Rules (this layer)**:
- Required: host actions validated on the server role

---

## Acceptance Criteria

*From `lobby-role-assignment.md` AC-LB-30, scoped to this story:*

- [x] In Waiting, a host kick removes the player, keeps their queue position, and they can rejoin.
- [x] A kick from a non-host, or by the host outside Waiting, is rejected.

---

## Implementation Notes

*Derived from `lobby-role-assignment.md` rule 20:*

- Kick disconnects the peer with a reason; no ban list in MVP.

---

## Out of Scope

- Ban lists

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/lobby/host_kick_test.gd` — must exist and pass

**Status**: [x] `tests/unit/lobby/host_kick_test.gd` (8 tests), `tests/integration/lobby/host_kick_net_test.gd` (2 tests)

---

## Dependencies

- Depends on: Story 008
- Unlocks: none

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-162):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 880/880 after the wave merge, no leak warnings.
- No client-to-server host action path: the host is the listen-server's local player, so its UI calls `lobby.kick` directly; nothing calls it in the shipped game yet.
- Host cannot kick themselves: inference ('any other player').
- Wire reason is `var_to_bytes({"kicked": "kicked"})`, matched byte for byte on the client (decoding every packet broke the 200 ms loopback bound).
**Test Evidence**: 10 tests. Mutations caught: Waiting check removed, host_left raised when kicked, unbind removed.
**Code Review**: Complete (orchestrator review at merge)
