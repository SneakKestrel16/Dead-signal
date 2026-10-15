# Story 008: Stun events projected by the form shown

> **Epic**: Borrowed Face
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

A stunned disguise must look exactly like a shocked survivor. The server projects the event by the body survivors see, never by the true role.

**GDD**: `design/gdd/borrowed-face.md`
**Requirement**: `TR-borrowedface-002`, `TR-borrowedface-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication scope and information hiding (primary); ADR-0005: Event catalog, state registry and tick order
**ADR Decision Summary**: Every client-bound event is projected per recipient (`project()`); `PlayerShocked` is byte-identical for a disguised shapeshifter and a survivor.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: As Story 007.

**Control Manifest Rules (this layer)**:
- Required: every catalog event has `project()`

---

## Acceptance Criteria

*From `borrowed-face.md` Acceptance Criteria (stun during transformation; stunned disguise), scoped to this story:*

- [x] A stun during a transformation out of a disguise sends survivor clients `PlayerShocked` and no `MonsterStunned`; out of true form they get `MonsterStunned`.
- [x] A stunned disguised shapeshifter stays in the borrowed form on every client, and survivor clients receive the borrowed survivor's shock payload with no monster pain cry event; a true-form stun sends the monster stagger and pain cry.

---

## Implementation Notes

*Derived from ADR-0004 projection table and network-authority story 009:*

- Network-authority story 009 asserts byte identity of `PlayerShocked`; this story asserts which event is chosen by form.

---

## Out of Scope

- Stagger animation and audio (Story 009)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/borrowed-face/stun_projection_test.gd` — must exist and pass

**Status**: [x] `tests/integration/borrowed-face/stun_projection_test.gd` (4 tests)

---

## Dependencies

- Depends on: Stories 004, 007; network-authority story 009
- Unlocks: Survivor Defense epic

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-166):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 895/895 after the wave merge, no leak warnings.
- StubDefense in the Survivor Defense slot (reads BorrowedFace.form); replace with the real module when it lands.
- 'On every client' checked through appearance_of (BF-7 proves it over ENet); PlayerShocked byte identity belongs to NA-9.
- Passed on first run (behaviour present); mutations stand in for the red run.
**Test Evidence**: 4 tests. Mutations caught: true-form check removed from EvMonsterStunned.project, stun not stopping the transformation, PlayerShocked not sent for the shapeshifter's body.
**Code Review**: Complete (orchestrator review at merge)
