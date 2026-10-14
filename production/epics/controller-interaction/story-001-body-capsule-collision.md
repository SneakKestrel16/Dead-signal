# Story 001: Player body, capsules and collision layers

> **Epic**: First-Person Controller & Interaction
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 1.5 days
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

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

- [x] For a survivor, a disguised shapeshifter, a true-form shapeshifter and a Downed survivor, the capsule radius is 0.30 m; height is 1.8 m standing and 1.2 m crouched or Downed; no two players share a shape resource.
- [x] Two upright players walking into each other do not pass through; an upright player walks through a Downed survivor lying in a 0.9 m doorway.
- [x] An Eliminated or Escaped player's body has no collision and accepts no movement.
- [x] `project.godot` selects Jolt, and a test fails if any script under `src/` sets `collision_layer`, `collision_mask` or a query mask from a number literal instead of `PhysicsLayers`.

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

**Status**: [x] `tests/integration/first-person-controller/body_collision_test.gd` passes (11 tests); 5 mutations caught; suite 174/174 (2026-10-14)

---

## Dependencies

- Depends on: network-authority story 004 (TickRunner); data-config story 002 (`ControllerKnobs`)
- Unlocks: Stories 002, 004, 012

---

## Completion Notes
**Completed**: 2026-10-14
**Criteria**: 4/4 passing in `tests/integration/first-person-controller/body_collision_test.gd`
- AC1: `test_every_form_has_radius_030_and_heights_18_and_12_with_no_shared_shape` (8 distinct capsules; the forms share one class, so the form test is by construction) and `test_capsule_sizes_come_from_controller_knobs`.
- AC2: `test_two_upright_players_walking_into_each_other_do_not_pass`, `test_upright_player_walks_through_downed_survivor_in_a_09m_doorway` (with an upright control that blocks).
- AC3: `test_out_body_has_no_collision_and_no_movement` (layer, mask NONE, shape disabled; every frame consumed, no motion). Movement stops through `ServerMovement.set_frozen`, which the Out owner (Match Flow) must call with `set_out()`.
- AC4: `test_project_selects_jolt`; the literal scan covers assignments (incl. compound and multi-line), `set_collision_*`, `Query*.create(.., mask)` and saved scenes under src/, proven on a fixture. A literal stored in a variable first is not caught.
- Edge cases: stand-up and revive under a low ceiling stay low; Downed set on the same physics frame as a contact.
**Deviations** (advisory): AD-75 (capsule height knobs, set_frozen, PhysicsLayers.NONE, Jolt). Deferred review suggestions: TD-007.
**Test Evidence**: Integration: 11 tests; 5 mutations caught; suite 174/174.
**Run result**: N/A: no rendered body yet (no mesh or camera); collision verified headless with real Jolt bodies. The boot scene still loads with Jolt selected ("boot ok: knob problems=0").
**Code Review**: Complete: `/code-review` 2026-10-14, APPROVED WITH SUGGESTIONS (Godot: no blocking; QA: GAPS); applied: revive stand-up probe, scanner forms, movement-phase proof, true same-frame state change.
