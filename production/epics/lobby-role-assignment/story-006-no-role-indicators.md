# Story 006: No name tags or role indicators on bodies

> **Epic**: Lobby & Role Assignment
> **Status**: In Review
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Roles are public in the lobby, but in a round nothing on a body says who it is or what it is; only character look and colour identify it. This is the premise of the whole game.

**GDD**: `design/gdd/lobby-role-assignment.md`
**Requirement**: `TR-lobby-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication scope and information hiding
**ADR Decision Summary**: Bodies reach peers only through per-peer snapshots under opaque handles; no player ID, role or character name in any body payload or node path.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: None beyond network-authority stories 008 and 010.

**Control Manifest Rules (this layer)**:
- Forbidden: role or player identity on bodies (ADR-0004)

---

## Acceptance Criteria

*From `lobby-role-assignment.md` AC-LB-31, scoped to this story:*

- [ ] In a running round, looking at any other body shows no name tag or role indicator; only character look and colour identify it (retained screenshot in `production/qa/evidence/`).
- [ ] A survivor client's body nodes carry no role, player ID or display-name property (inspected in the remote scene tree).

---

## Implementation Notes

*Derived from ADR-0004 and network-authority story 010:*

- Network-authority story 010 already asserts node paths; this story checks what is drawn.

---

## Out of Scope

- Disguise rendering (borrowed-face epic)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: retained screenshot or capture in `production/qa/evidence/` + sign-off in `production/qa/evidence/no-role-indicators-evidence.md`

**Status**: [x] Created: `production/qa/evidence/no-role-indicators-evidence.md` (sign-off pending)

---

## Dependencies

- Depends on: Story 002; network-authority stories 008, 010
- Unlocks: none
