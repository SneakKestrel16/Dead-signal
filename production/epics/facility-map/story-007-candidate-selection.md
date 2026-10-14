# Story 007: Candidate point selection and placement constraints

> **Epic**: Facility Map
> **Status**: Blocked
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

BLOCKED: ADR-0012 is Proposed — accept it with `/architecture-decision accept ADR-0012` once decided.

## Context

Each round the server picks 2 of 6 drives, 2 of 7 fuses, 2 of 3 fuse boxes and 1 of 3 terminals, within placement constraints, so routes cannot be memorised.

**GDD**: `design/levels/research-facility.md`
**Requirement**: `TR-facility-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Objective discovery (Proposed)
**ADR Decision Summary**: Seeded server-side selection from authored candidate points; survivors learn drive rooms and fuse spawns only on discovery.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Per ADR-0012 once Accepted.

**Control Manifest Rules (this layer)**:
- Required: (Proposed) rules per ADR-0012 — re-check the control manifest once it is Accepted

---

## Acceptance Criteria

*From `research-facility.md` Authored Candidate Points and Acceptance Criteria 5, scoped to this story:*

- [ ] Over 1,000 seeded selections no round breaks a placement constraint (drives in different rooms; fuses in different zones; nothing in A1; fuse boxes in Zone B; T3 and d6 never both).
- [ ] Over 20 seeded rounds, at least 4 different drive pairs and all 3 terminals appear.

---

## Implementation Notes

*Derived from ADR-0012 (Proposed):*

- Counts come from `ObjectivesKnobs` (`data_drives_required`, `fuses_required`).

---

## Out of Scope

- Story 008: replication and discovery

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/facility-map/candidate_selection_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001; ADR-0012 Accepted
- Unlocks: Story 008
