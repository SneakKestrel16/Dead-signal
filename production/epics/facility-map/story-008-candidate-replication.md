# Story 008: Candidate replication and discovery agreement

> **Epic**: Facility Map
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15


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

- [x] Over 10 rounds with 5 clients, every client shows the active fuse boxes and terminal from round start at the logged positions; the monster's client shows every active point from round start.
- [x] Each survivor client shows an active drive room or fuse spawn only after its discovery, at the logged position, and holds no data for an undiscovered one (capture check).

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

**Status**: [x] `tests/integration/facility-map/candidate_replication_test.gd` (1 test, 10 seeded rounds, real ENet with a capturing UDP proxy)

---

## Dependencies

- Depends on: Story 007; network-authority story 010
- Unlocks: Survivor Objectives epic

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-206):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 1110/1110 after the wave merge, no leak warnings.
- Split with SO-9 (QA plan overlap): FM-8 owns the channel and agreement test; SO-9 owns the sight rule. The test calls discover() directly in its place.
- Discovered points re-grant on reconnect via NetAuthority's per-player grant carry-over (tested in NA-10, not here). Spectators assumed to keep their survivor id (ADR-0004 §9, inference).
- end_round() queue_frees the entities while NetAuthority._visibility keeps references; reconnect code walking that list after a round could hit a freed object (pre-existing, unchanged).
- No settle delay: the absence check relies on round-start spawns and the first discovery sharing one reliable channel.
**Test Evidence**: Red run was a parse error. Mutations caught: hidden points granted to survivors at start, discover granting only the first survivor, monster not granted hidden points.
**Code Review**: Complete (orchestrator review at merge)
