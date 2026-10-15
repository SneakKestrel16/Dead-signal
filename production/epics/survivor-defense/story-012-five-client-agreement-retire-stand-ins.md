# Story 012: Five-client agreement and retiring the stand-ins

> **Epic**: Survivor Defense
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Closes the epic: with five clients connected, all five agree on stun state (as visible to their role), charges, hiding occupancy and barricade state after each event. The `StubDefense` classes and fixture hide/search/barricade interactables in Borrowed Face tests are replaced by the real module and those tests re-run green.

**GDD**: `design/gdd/survivor-defense.md`
**Requirement**: `TR-defense-001, TR-defense-003, TR-defense-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Authoritative simulation, tick rate and input; secondary: ADR-0004, ADR-0005
**ADR Decision Summary**: All five clients agree on every server-owned state as their role permits, and merged stories stop depending on stand-ins.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Uses the existing multi-client harness in `tests/integration/network/`.

**Control Manifest Rules (this layer)**:
- Required: every server-owned state replicates through the registry; role-based projection (ADR-0004, ADR-0005)
- Forbidden: never leave a copy of the stand-in behaviour in tests once the real module covers it
- Guardrail: the whole suite passes unchanged apart from the replaced stubs

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-defense.md` (Detailed Design and Acceptance Criteria), scoped to this story:*

- [x] With 5 clients, all agree on stun state (as visible to their role), charges, hiding occupancy and barricade state after each event (acceptance 9).
- [x] `StubDefense` in `transform_state_machine_test.gd`, `transform_immunity_test.gd` and `stun_projection_test.gd` is replaced by the real module and all three pass; `disguise_gates_test.gd` runs its hide, barricade and search rows against the real interactables.
- [x] Every Tuning Knob is loaded from data; a test asserts no hardcoded value (acceptance 20).

---

## Implementation Notes

- Stand-in test files to re-run and edit: `tests/unit/borrowed-face/transform_state_machine_test.gd`, `tests/unit/borrowed-face/transform_immunity_test.gd`, `tests/integration/borrowed-face/stun_projection_test.gd`, `tests/integration/borrowed-face/disguise_gates_test.gd`.
- Run the whole suite before and after; only the stub removals should differ.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- None

---

## QA Test Cases

*Test specs from `/qa-plan sprint` (`production/qa/qa-plan-sprint-006-2026-10-15.md`). Tests emit the other epic's events directly until MA-6 and SD-12 re-run against both real modules.*

**Test file path**: `tests/integration/survivor-defense/five_client_agreement_test.gd`

- **AC-1**: Five-client agreement
  - Given: 5 clients
  - When: after each stun, charge, hide, barricade event
  - Then: all agree on stun state as visible to their role, charges, hiding occupancy, barricade state
  - Edge cases: a reconnect, if in scope
- **AC-2**: Retire `StubDefense`
  - Given: `transform_state_machine_test.gd`, `transform_immunity_test.gd`, `stun_projection_test.gd`
  - When: re-run on the real module
  - Then: all three pass; `disguise_gates_test.gd` hide, barricade and search rows run on the real interactables
  - Edge cases: stub removed from the tree, not only unused
- **AC-3**: No hardcoded knobs
  - Given: every Tuning Knob
  - When: loaded and scanned
  - Then: all from data; test asserts no hardcoded value
  - Edge cases: a knob changed in data changes behaviour

**Re-run against the real module**: `tests/unit/borrowed-face/transform_state_machine_test.gd`; `tests/unit/borrowed-face/transform_immunity_test.gd`; `tests/integration/borrowed-face/stun_projection_test.gd`; `tests/integration/borrowed-face/disguise_gates_test.gd`

**Estimated test count**: ~6 tests

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: Integration: `tests/integration/survivor-defense/five_client_agreement_test.gd` plus the re-run list above

**Status**: [x] `tests/integration/survivor-defense/five_client_agreement_test.gd` (1 test), `tests/unit/survivor-defense/defense_knob_literals_test.gd` (3 tests); Borrowed Face transform_state_machine, transform_immunity, disguise_gates and stun_projection tests on the real module

---

## Dependencies

- Depends on: Stories 004, 005, 006, 008
- Unlocks: None

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-195):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 1057/1057 after the wave merge, no leak warnings.
- Replication scope per AD-194 (Pending designer review): charges to owner, occupancy to occupant, barricades to all.
- No catch-up for reconnecting clients: a client down on the tick a change happens misses it until the next change (Downing's ring has the same gap). Fix: ServerMovement replays provider state on rejoin.
- Spectators receive the watched survivor's charges and hiding spot (follows ServerMovement's provider call for the watched player).
- Five-client test drives module entry points (shock, hide_completed, search_completed, complete, break_barricade, fire intent) inside a tick, not holds and input. Disguised-monster stun not covered there (no Borrowed Face wired); SD-5 covers it.
- Knob scan skips values 0 and 1 (indistinguishable from indexes); four literals allow-listed with reasons. The data-change test covers the rest by behaviour.
- transform_immunity_test now expects one PlayerShocked on the monster for an immune hit out of true form (SD-5 resisted-hit choice).
- Tests written after the providers; mutations stand in for the red run.
**Test Evidence**: Mutations caught: hiding sent to every viewer, charges sent to every viewer, lockout end missing from change check, knob literal 1.5 reintroduced; AC-2 mutations: survivor-only gate true for all, locked always false, search_completed no-op.
**Code Review**: Complete (orchestrator review at merge)
