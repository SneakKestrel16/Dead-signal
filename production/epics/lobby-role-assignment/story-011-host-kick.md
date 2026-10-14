# Story 011: Host kick (post-M1)

> **Epic**: Lobby & Role Assignment
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] In Waiting, a host kick removes the player, keeps their queue position, and they can rejoin.
- [ ] A kick from a non-host, or by the host outside Waiting, is rejected.

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

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 008
- Unlocks: none
