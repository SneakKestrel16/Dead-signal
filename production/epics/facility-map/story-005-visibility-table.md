# Story 005: Per-volume visibility table for relevance

> **Epic**: Facility Map
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Relevance filtering needs to know which volumes can see which. The table was authored in the level doc on 2026-10-13 (AD-51); this story loads it and wires it to ADR-0004 relevance.

**GDD**: `design/levels/research-facility.md`
**Requirement**: `TR-facility-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication scope and information hiding
**ADR Decision Summary**: Bodies reach a peer only when relevant through an authored room PVS; handles are re-issued on re-entry.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `modules/networking.md` is a 4.6 snapshot.

**Control Manifest Rules (this layer)**:
- Required: relevance from the authored PVS (ADR-0004)

---

## Acceptance Criteria

*From `research-facility.md` Visibility sets and ADR-0004 Validation Criteria, scoped to this story:*

- [ ] The table loads all 25 volumes; a test fails if it is not symmetric or a volume is missing.
- [ ] `MapQueries.volume_at(point)` returns the volume for a point in each of the 25 volumes.
- [ ] A body in a volume outside a peer's visible set is not sent to that peer; inside it is (with network-authority story 008).

---

## Implementation Notes

*Derived from ADR-0004 and `research-facility.md` Visibility sets:*

- The greybox sightline pass may refine the table (AD-51); keep it data so edits need no code.

---

## Out of Scope

- Handle re-issue (network-authority story 008)

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-004-2026-10-14.md` (/qa-plan, 2026-10-14). Implement against these and the Acceptance Criteria above.*

**Test file path**: `tests/integration/facility-map/visibility_table_test.gd`
**What to test**:
- All 25 volumes have a `sees` table entry; a test fails if the table is not symmetric or a volume is missing (`MapVolume.sees`, NA-8).
- `MapQueries.volume_at(point)` returns each of the 25 volumes for a point inside it.
- A body in a volume outside a peer's visible set is not sent; inside it is (through `ReplicationScope`).

**Edge cases to cover**:
- A door entry is cut while that door is closed (`MapQueries.visible_set` with `door_closed`).

**Estimated test count**: ~5 integration tests

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/facility-map/visibility_table_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001; network-authority story 008
- Unlocks: none
