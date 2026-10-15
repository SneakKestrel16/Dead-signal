# Story 007: Candidate point selection and placement constraints

> **Epic**: Facility Map
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15


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

- [x] Over 1,000 seeded selections no round breaks a placement constraint (drives in different rooms; fuses in different zones; nothing in A1; fuse boxes in Zone B; T3 and d6 never both).
- [x] Over 20 seeded rounds, at least 4 different drive pairs and all 3 terminals appear.

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

**Status**: [x] `tests/unit/facility-map/candidate_selection_test.gd` (6 tests)

---

## Dependencies

- Depends on: Story 001; ADR-0012 Accepted
- Unlocks: Story 008

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-202):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 1076/1076 after the wave merge, no leak warnings.
- Counts are parameters defaulting to 2/2/2/1 from SurvivorObjectives constants: the story's ObjectivesKnobs fields do not exist and the GDD calls rule 15 a rule, not a knob. No knob added.
- 'Fuse boxes in Zone B' checked only in the test: a fact of the authored data, not a selection rule.
- Reads MapData directly in src/core/facility instead of ADR-0012's ObjectiveCandidates type on SurvivorObjectives (that type does not exist); SO-8 wires it in.
- Uniform over valid combinations is ADR-0012's reading of 'uniformly at random' (inference, marked in code).
- Spawn room derived from survivor_spawn markers; link corridors count as their own zone.
**Test Evidence**: 6 tests incl. 1,000 seeded draws, exact valid count 2,280, determinism, impossible counts. Mutations caught: same-room check dropped, different-zone check dropped, pick always first, spawn-room filter removed.
**Code Review**: Complete (orchestrator review at merge)
