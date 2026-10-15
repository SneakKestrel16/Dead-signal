# Story 008: Candidate replication and discovery agreement

> **Epic**: Facility Map
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]


## Context

Survivors see fuse boxes and the terminal from the start, but a drive room or fuse spawn only once someone discovers it. The monster sees everything. No survivor client may hold data it has not discovered.

**GDD**: `design/levels/research-facility.md`
**Requirement**: `TR-facility-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Objective discovery (primary, Proposed); ADR-0004: Replication scope and information hiding
**ADR Decision Summary**: Hidden candidate entities use `MultiplayerSynchronizer` per-peer visibility; discovery grants visibility per peer.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: As network-authority story 010.

**Control Manifest Rules (this layer)**:
- Required: (Proposed) rules per ADR-0012
- Required: hidden entities never reach an ungranted peer (ADR-0004)

---

## Acceptance Criteria

*From `research-facility.md` Acceptance Criteria 4 and Edge Cases, scoped to this story:*

- [ ] Over 10 rounds with 5 clients, every client shows the active fuse boxes and terminal from round start at the logged positions; the monster's client shows every active point from round start.
- [ ] Each survivor client shows an active drive room or fuse spawn only after its discovery, at the logged position, and holds no data for an undiscovered one (capture check).

---

## Implementation Notes

*Derived from ADR-0012 (Proposed) and network-authority story 010:*

- Discovery rules belong to Survivor Objectives; stub the discovery trigger.

---

## Out of Scope

- Discovery rules (Survivor Objectives epic)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/facility-map/candidate_replication_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 007; network-authority story 010
- Unlocks: Survivor Objectives epic
