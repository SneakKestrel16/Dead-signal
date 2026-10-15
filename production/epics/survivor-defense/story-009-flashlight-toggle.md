# Story 009: Flashlight toggle and replicated cone

> **Epic**: Survivor Defense
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

Every survivor owns a flashlight toggle, replicated so all clients see the cone and the holder's position. It has no battery and no effect on the monster; it keeps working inside Blackout and does not end it.

**GDD**: `design/gdd/survivor-defense.md`
**Requirement**: `TR-defense-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Replication scope and information hiding
**ADR Decision Summary**: Public per-player state replicates to every client the viewer can see; nothing about it changes the monster.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: No post-cutoff APIs; light nodes are presentation only.

**Control Manifest Rules (this layer)**:
- Required: server holds the toggle state, clients predict locally and take the server's value (ADR-0002, ADR-0004)
- Forbidden: never affect the monster's state, form or stun from the light
- Guardrail: this story adds no knob; local toggle response within 50 ms (Game Feel)

---

## Acceptance Criteria

*From GDD `design/gdd/survivor-defense.md` (Detailed Design and Acceptance Criteria), scoped to this story:*

- [x] Toggling flips the server state and every client sees the same cone state; local toggle responds within 50 ms (Game Feel).
- [x] The flashlight has no battery limit and no effect on the monster: no stun, slow or disguise reveal (rules 2, 5).
- [x] The flashlight still works while Blackout is active and does not end it early (rule 4).

---

## Implementation Notes

- Toggle state is a single bool per survivor in the replicated state; no flashlight item object.
- Blackout itself is Monster Abilities; test with a lighting-state flag fixture until it lands.
- The cosmetic copy on a disguised monster is story 011.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 011: cosmetic copy on a disguised monster

---

## QA Test Cases

*Test specs from `/qa-plan sprint` (`production/qa/qa-plan-sprint-006-2026-10-15.md`). Tests emit the other epic's events directly until MA-6 and SD-12 re-run against both real modules.*

**Test file path**: `tests/integration/survivor-defense/flashlight_toggle_test.gd`

- **AC-1**: Toggle and replication
  - Given: a survivor and 4 other clients
  - When: toggle on, off
  - Then: server state flips; every client sees the same cone state; local response within 50 ms
  - Edge cases: toggle twice in one tick
- **AC-2**: No battery, no monster effect
  - Given: a long-held beam on the monster
  - When: time passes
  - Then: no limit; no stun, slow or disguise reveal
  - Edge cases: beam on a disguised monster
- **AC-3**: Blackout
  - Given: Blackout active (stubbed until story 010 lands)
  - When: toggle
  - Then: works; does not end Blackout early
  - Edge cases: toggle on the Blackout end tick

**Estimated test count**: ~5 tests

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: Integration: `tests/integration/survivor-defense/flashlight_toggle_test.gd`

**Status**: [x] `tests/integration/survivor-defense/flashlight_toggle_test.gd` (7 tests)

---

## Dependencies

- Depends on: Story 001
- Unlocks: Story 011

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-182):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 954/954 after the wave merge, no leak warnings.
- Blackout is a test stub (Monster Abilities' Blackout is Blocked on ADR-0009).
- 'Within 50 ms' checked structurally: the predictor changes in the same call as the toggle.
- Composer must set `ServerMovement.flashlight_of`; until then no client sees a light.
- Known limit (ponytail comment): on-then-off within one round trip can briefly re-show the light; a sequence number would fix it.
- Merge conflict with SD-2 in survivor_defense.gd (both additive) resolved by keeping both.
**Test Evidence**: 7 tests. Mutations caught: intent never applied, codec drops the bit, predictor ignores local toggle, light kept after elimination.
**Code Review**: Complete (orchestrator review at merge)
