# Story 001: Player body, capsules and collision layers

> **Epic**: First-Person Controller & Interaction
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Every player, in every form, is the same Jolt `CharacterBody3D` capsule, and every query in the game agrees on what blocks what through four named layers. Downed bodies must not plug doorways; Out bodies take no space at all.

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-controller-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Movement, physics and collision layers
**ADR Decision Summary**: A `CharacterBody3D` per player with two `CapsuleShape3D` resources built with `.new()` (standing 0.30/1.8, low 0.30/1.2, shape placed at y = height / 2); layers 1 `world`, 2 `glass`, 3 `doors`, 4 `players`; fixed masks per query purpose in a `PhysicsLayers` class; shape `disabled` and layer changes made directly from TickRunner phases.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Jolt is the default since 4.6 but the root `project.godot` must still set `3d/physics_engine="Jolt Physics"`. Verification (5) PASS: code-built shapes are not shared. Verification (7) FAIL: a moved body is invisible to queries until the next physics step; a disabled or shrunk shape is seen at once.

**Control Manifest Rules (this layer)**:
- Required: Jolt `CharacterBody3D` players; each player owns its capsule resources (built with `.new()`)
- Required: every physics query uses a `PhysicsLayers` mask (`MOVE_SERVER`, `MOVE_PREDICT`, `SIGHT`, `PROJECTILE`)
- Forbidden: `RigidBody3D` players or a hand-written kinematic controller; inline layer or mask numbers [inline_layer_numbers]; sharing a shape between players [shared_player_shape]; `WorldBoundaryShape3D`

---

## Acceptance Criteria

*From `first-person-controller.md` Acceptance Criteria (Body and gaits; Cross-system movement: Collision) and ADR-0007 §1, §2, §5, scoped to this story:*

- [ ] For a survivor, a disguised shapeshifter, a true-form shapeshifter and a Downed survivor, the capsule radius is 0.30 m; height is 1.8 m standing and 1.2 m crouched or Downed; no two players share a shape resource.
- [ ] Two upright players walking into each other do not pass through; an upright player walks through a Downed survivor lying in a 0.9 m doorway.
- [ ] An Eliminated or Escaped player's body has no collision and accepts no movement.
- [ ] `project.godot` selects Jolt, and a test fails if any script under `src/` sets `collision_layer`, `collision_mask` or a query mask from a number literal instead of `PhysicsLayers`.

---

## Implementation Notes

*Derived from ADR-0007 Decision §1, §2, §5 and §6:*

- `PhysicsLayers` holds the four layer bits and the four query masks; nothing else defines a layer number.
- Downed: swap to the low capsule and drop the `players` bit from the layer so upright movers pass; the dash-block check in Monster Abilities is its own analytic test.
- Out (Eliminated, Escaped): layer and mask 0, movement step skipped.
- Hidden survivors (layer and mask 0, hide point) belong to the Survivor Defense epic; leave the hook.

---

## Out of Scope

- Story 002: the movement step and gaits
- Story 004: stand-up check and step ramps

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-002-2026-10-13.md` (/qa-plan, 2026-10-13). Implement against these and the Acceptance Criteria above.*

**What to test**:
- For a survivor, a disguised shapeshifter, a true-form shapeshifter and a Downed survivor: capsule radius 0.30 m; height 1.8 m standing and 1.2 m crouched or Downed; no two players share a shape resource (instance ids differ).
- Two upright players walking into each other do not overlap after N physics ticks. An upright player walks through a Downed survivor lying in a 0.9 m doorway.
- An Eliminated or Escaped body has no collision layer and ignores movement input.
- `project.godot` selects Jolt. A source scan fails on any `collision_layer`, `collision_mask` or query mask set from a number literal instead of `PhysicsLayers`; prove it with a fixture that holds a literal.

**Edge cases to cover**:
- Crouch to stand under a low ceiling (stand-up is story 004: assert only that the height stays 1.2 m here).
- Changing state on the same tick as a collision.
- Every knob value comes from `ControllerKnobs`, not literals.

**Estimated test count**: ~8 integration tests

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/first-person-controller/body_collision_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: network-authority story 004 (TickRunner); data-config story 002 (`ControllerKnobs`)
- Unlocks: Stories 002, 004, 012
