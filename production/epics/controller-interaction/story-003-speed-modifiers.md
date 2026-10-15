# Story 003: Speed modifier set: lock, root and slow

> **Epic**: First-Person Controller & Interaction
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

## Context

Taser stuns, takedown commits, rescues and transforms all limit movement. Each owner adds and removes its own entry; the controller applies the most restrictive one, never a product.

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-controller-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Authoritative simulation, tick and input
**ADR Decision Summary**: §5–6: the server simulates movement from input frames and applies server-side state; effective speed = lock (0, no look change) > root (0) > the lowest slow multiplier, from a per-owner modifier set read by the shared movement step.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Plain GDScript; no engine API beyond Story 002's step.

**Control Manifest Rules (this layer)**:
- Required: one movement step function shared by server and owning client
- Forbidden: client-sent position, velocity, speed or progress [client_sent_position]

---

## Acceptance Criteria

*From `first-person-controller.md` Acceptance Criteria (Modifiers) and Formulas (effective_speed), scoped to this story:*

- [x] From a true-form sprint (5.75): slow 0.5 gives 2.875; slows 0.5 and 0.7 give 2.875 (not 2.01); a root gives 0; a lock and a slow give 0.
- [x] When the last modifier is removed with sprint still held, the next tick moves at 5.75 with no re-press.
- [x] With owners A and B each adding a modifier, removing A's leaves B's active.

---

## Implementation Notes

*Derived from ADR-0002 §5–6 and `first-person-controller.md` rule 6:*

- `SpeedModifiers.add(owner: StringName, kind, mult := 1.0)`, `remove(owner)`, `effective(base) -> float`; keyed by owner so removals never clobber.
- Lock also blocks look changes for the locked states named in the GDD; the view direction itself is Story 006.

---

## Out of Scope

- Owners that add modifiers (taser, takedown, rescue) belong to their own epics

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-004-2026-10-14.md` (/qa-plan, 2026-10-14). Implement against these and the Acceptance Criteria above.*

**Test file path**: `tests/unit/first-person-controller/speed_modifiers_test.gd`
**What to test**:
- From a true-form sprint 5.75 m/s: slow 0.5 gives 2.875; slows 0.5 and 0.7 together give 2.875 (the strongest wins, not the product 2.01); a root gives 0; a lock plus a slow gives 0.
- Last modifier removed with sprint still held: the next tick moves at 5.75 with no re-press.
- Owners A and B each add a modifier; removing A's leaves B's active.

**Edge cases to cover**:
- Removing a modifier that was never added changes nothing.
- The same owner adding twice replaces, not stacks (record the rule if the GDD is silent).

**Estimated test count**: ~6 unit tests

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/first-person-controller/speed_modifiers_test.gd` — must exist and pass

**Status**: [x] Created, 14 tests passing (suite 365/365)

---

## Dependencies

- Depends on: Story 002
- Unlocks: Survivor Defense, Monster Abilities and Downing epics

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: 3/3 passing (`tests/unit/first-person-controller/speed_modifiers_test.gd`, 14 tests).
**Deviations**:
- The set lives in the existing `MovementModifiers` seam (`src/foundation/network/movement_modifiers.gd`) rather than a new `SpeedModifiers` class. The movement step, `ServerMovement` and `OwnerPredictor` already read it.
- AC2 is verified as the step's target speed (5.75 on the next tick, no re-press). The body reaches that speed within `accel_time_s`, as `movement_step_test` covers after a root.
- A repeat `add` by the same owner replaces its entry. The GDD says nothing on this; the rule is recorded in the test.
**Code review**: two findings fixed, each with a regression test that was watched failing. (1) `set_from_scale` left the set stale, so a later add or remove dropped the snapshot's slow. It now files the snapshot as one entry. (2) A NaN or above-1 snapshot scale reads as full speed. The reviewer's claim that a NaN slow passes through `add` was disproved: a test shows it is ignored on 4.7.2. Deferred to story 006: a snapshot cannot tell lock from root, so the owning client predicts a locked body as rooted.
