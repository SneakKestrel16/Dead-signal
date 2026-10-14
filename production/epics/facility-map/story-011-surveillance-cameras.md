# Story 011: Surveillance cameras at the C1 monitor

> **Epic**: Facility Map
> **Status**: Blocked
> **Layer**: Core
> **Type**: Visual/Feel
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

BLOCKED: ADR-0009 is Proposed — accept it with `/architecture-decision accept ADR-0009` once decided.

## Context

Four cameras feed the C1 monitor so survivors can watch the map. Feed content is server-owned, including how a disguise appears on it.

**GDD**: `design/levels/research-facility.md`
**Requirement**: `TR-facility-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009: Lighting states and Blackout (Proposed) §8
**ADR Decision Summary**: Camera feeds rendered from server-owned state at the C1 monitor; feeds follow the lighting state.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Per ADR-0009 once Accepted; `SubViewport` cost to be measured.

**Control Manifest Rules (this layer)**:
- Required: (Proposed) rules per ADR-0009

---

## Acceptance Criteria

*From `research-facility.md` Defense, Surveillance and Lighting Fixtures, scoped to this story:*

- [ ] The C1 monitor shows the four camera feeds at the positions in the level doc, following each volume's lighting (retained screenshot).
- [ ] A disguised shapeshifter appears on a feed as its disguise, never as true form.

---

## Implementation Notes

*Derived from ADR-0009 (Proposed) §8:*

- Feed render cost is measured and recorded.

---

## Out of Scope

- Camera scares (Scare Events epic)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: retained screenshot or capture in `production/qa/evidence/` + sign-off in `production/qa/evidence/surveillance-cameras-evidence.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 002, 009; borrowed-face story 009; ADR-0009 Accepted
- Unlocks: Scare Events epic
