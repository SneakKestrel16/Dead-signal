# Story 004: Host session setting: proximity voice

> **Epic**: Lobby & Role Assignment
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

The host can switch proximity voice on or off in Waiting only. The server validates the change and every client sees the new value.

**GDD**: `design/gdd/lobby-role-assignment.md`
**Requirement**: `TR-lobby-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Hosting, session join and reconnect
**ADR Decision Summary**: Listen server with a separable server role; every host action is a server-validated request, not a client-side write.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `modules/networking.md` is a 4.6 snapshot; the 4.7 migration guide lists no multiplayer changes.

**Control Manifest Rules (this layer)**:
- Required: host actions validated on the server role
- Forbidden: client-sent state writes

---

## Acceptance Criteria

*From `lobby-role-assignment.md` AC-LB-25, AC-LB-26, scoped to this story:*

- [x] A new session has proximity voice Off; a change from a non-host is rejected, a change from the host in Countdown or In Match is rejected, and a change from the host in Waiting is accepted.
- [x] After the host toggles it in Waiting, every client reports the new value.

---

## Implementation Notes

*Derived from ADR-0001 and `lobby-role-assignment.md` rule 20:*

- The voice feature itself is out of MVP; this is the setting only.

---

## Out of Scope

- Proximity voice audio

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/lobby/proximity_voice_replication_test.gd` (AC-LB-26, real ENet)
  and `tests/unit/lobby/proximity_voice_setting_test.gd` (AC-LB-25, the lobby's validation)

**Status**: [x] Both exist and pass. Deviation: the evidence is split across these two files rather
than the single integration file named originally; the server-side validation needs no sockets.

Replication: the server sends one of two fixed reliable packets (`NetAuthority.send_proximity_voice`)
on every accepted change and to each joining or rejoining player; the client matches them byte for
byte (never decodes server packets) and exposes `NetAuthority.proximity_voice`. Wired in
`ConnectionRouter`.

---

## Dependencies

- Depends on: Story 001; network-authority story 001
- Unlocks: none

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-168):
- Server-side setting and host/phase checks merged in the earlier wave; AC-LB-26 (every client reports the value) added by a worktree agent and squash-merged as c3b0e76.
- Transport: two fixed reliable packets (on/off) sent on every accepted change and to each joining or rejoining player; the client matches them byte for byte and never decodes server packets (decoding every snapshot broke a 200 ms loopback bound in LB-11).
- A rejoining player gets the value in any phase, not only Waiting (the setting carries across rounds).
- Evidence is the existing unit test plus the new integration test (story named one file).
**Test Evidence**: `tests/unit/lobby/proximity_voice_setting_test.gd`, `tests/integration/lobby/proximity_voice_replication_test.gd` (2 tests, real ENet). Mutations caught: no send on join, size-only client match, send to the first player only.
**Code Review**: Complete (orchestrator review at merge)
