# Story 004: Host session setting: proximity voice

> **Epic**: Lobby & Role Assignment
> **Status**: Ready
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

- [ ] A new session has proximity voice Off; a change from a non-host is rejected, a change from the host in Countdown or In Match is rejected, and a change from the host in Waiting is accepted.
- [ ] After the host toggles it in Waiting, every client reports the new value.

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
- Integration: `tests/integration/lobby/proximity_voice_setting_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001; network-authority story 001
- Unlocks: none
