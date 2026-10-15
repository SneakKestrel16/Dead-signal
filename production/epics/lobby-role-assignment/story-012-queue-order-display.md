# Story 012: Lobby queue order and preference display (post-M1)

> **Epic**: Lobby & Role Assignment
> **Status**: In Review
> **Layer**: Core
> **Type**: UI
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]


## Context

Post-M1 phase. Every client shows the server's queue order and who is next to be the shapeshifter, and lets players pick a preferred character.

**GDD**: `design/gdd/lobby-role-assignment.md`
**Requirement**: `TR-lobby-005`, `TR-lobby-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0014: UI and input focus (Proposed)
**ADR Decision Summary**: Stock `Control` UI on fixed `CanvasLayer`s; screens display server state only.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: As Story 005.

**Control Manifest Rules (this layer)**:
- Required: (Proposed) UI rules per ADR-0014 — re-check the control manifest once it is Accepted

---

## Acceptance Criteria

*From `lobby-role-assignment.md` AC-LB-19, scoped to this story:*

- [ ] With an absent token at the queue head, every client displays the server's queue order and names the first present token as the next shapeshifter (retained screenshot).
- [ ] The preference picker is disabled while Ready (retained screenshot).

---

## Implementation Notes

*Derived from ADR-0014 (Proposed) and `lobby-role-assignment.md` UI Requirements:*

- Extends Story 005's screen.

---

## Out of Scope

- Final lobby art

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: retained screenshot or capture in `production/qa/evidence/` + sign-off in `production/qa/evidence/lobby-queue-order-evidence.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 005, 008, 010; ADR-0014 Accepted
- Unlocks: none
