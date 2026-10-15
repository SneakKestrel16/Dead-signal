# Story 015: Chase closing check and controller tick budget

> **Epic**: First-Person Controller & Interaction
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-15

## Context

The chase numbers in the GDD only hold if the movement step produces them on the server. The controller must also fit its share of the tick.

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-controller-003`, `TR-controller-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Authoritative simulation, tick and input (primary); ADR-0007: Movement, physics and collision layers
**ADR Decision Summary**: Server simulation at 60 Hz with the shared movement step; rotated move order; gait speeds from data.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Profile with the Jolt default on the exported build, not the editor.

**Control Manifest Rules (this layer)**:
- Required: one movement step function shared by server and owning client

---

## Acceptance Criteria

*From `first-person-controller.md` Acceptance Criteria (Chase closing; Performance), scoped to this story:*

- [x] A survivor sprinting at 5.0 m/s and a true-form shapeshifter at 5.75 m/s 10 m behind on a straight corridor reach a gap ≤ `catch_gap` (1.0 m) at 12 s ± 0.5 s; for a walking survivor (4.0) the gap is 1.9 m and is reached at 4.6 s ± 0.3 s.
- [x] With 6 players moving, 2 Holding and 1 slowed, 600 server ticks profiled give the controller's server cost (movement, hold checks, ray casts) ≤ 0.5 ms per tick at p95 (placeholder budget; report the measured number).

---

## Implementation Notes

*Derived from `first-person-controller.md` Formulas (chase_close_time) and ADR-0002:*

- The lunge connect itself is Monster Abilities; this story stops at the gap.
- Record the measured p95 in the story when closed; technical-director pins the real budget.

---

## Out of Scope

- Dodge AC (Monster Abilities epic; needs the lunge)
- Borrowed Face parity AC (borrowed-face epic)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/first-person-controller/chase_budget_test.gd` — must exist and pass

**Status**: [x] `tests/integration/first-person-controller/chase_closing_tick_budget_test.gd` (3 tests)

---

## Dependencies

- Depends on: Stories 002, 003, 008
- Unlocks: none

---

## Completion Notes

**Completed**: 2026-10-15
**Criteria**: all passing (automated)
**Deviations** (AD-156):
- Implemented by a worktree agent in the parallel wave; squash-merged by the orchestrator. Full suite 849/849 (prediction_reconcile 9 failures under parallel agent load; 9/9 alone, BUG-0003 class) after the wave merge, no leak warnings.
- Measured controller server cost p95 about 350 µs per tick against the 0.5 ms placeholder budget (dev machine, headless).
**Test Evidence**: 3 tests.
**Code Review**: Complete (orchestrator review at merge)
