# Story 008: Queue positions for absent, reconnecting and new players (post-M1)

> **Epic**: Lobby & Role Assignment
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Post-M1 phase. Absent tokens are skipped but keep their place; a reconnect with the same token keeps its place; a new or lost token goes to the back. Clients can never request a role.

**GDD**: `design/gdd/lobby-role-assignment.md`
**Requirement**: `TR-lobby-004`, `TR-lobby-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Hosting, session join and reconnect
**ADR Decision Summary**: A server-issued session token keys the player across peers; reconnect evicts the stale peer and rebinds the stable player ID.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: As network-authority story 002.

**Control Manifest Rules (this layer)**:
- Forbidden: client-requested roles or role RPCs acting on state

---

## Acceptance Criteria

*From `lobby-role-assignment.md` AC-LB-14, AC-LB-17, AC-LB-18, scoped to this story:*

- [ ] Q_1 = [A, B, C, D, E], A in round 1, B absent for round 2 and present for round 3: C is the shapeshifter in round 2, the queue becomes [B, D, E, A, C], and B is the shapeshifter in round 3.
- [ ] A reconnect with the same token under a new peer ID keeps its queue position; a new token (lost token or first join after round 1) is appended at the back.
- [ ] A client role-request RPC is ignored and roles are unchanged.

---

## Implementation Notes

*Derived from `lobby-role-assignment.md` rule 10 and Edge Cases:*

- Absent tokens are never pruned (accepted: queues stay small).

---

## Out of Scope

- Kick (Story 011)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/lobby/rotation_queue_absent_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 007
- Unlocks: Story 011
