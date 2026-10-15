# Story 004: Steps, slopes and the stand-up check

> **Epic**: First-Person Controller & Interaction
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

## Context

Players climb stairs through invisible ramps, never jump, and stay crouched until there is head room. These checks run against the real physics space, so they need geometry in the test scene.

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-controller-002`, `TR-controller-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Movement, physics and collision layers
**ADR Decision Summary**: §2 stand-up uses `intersect_shape` with the standing capsule raised 0.01 m, `margin = 0`, own RID excluded, mask `world | glass | doors`, other players tested analytically (§6a); §3 `floor_max_angle` 40.0° with `floor_block_on_wall`; §4 ramp colliders ≤ 40° for steps up to 0.35 m; §11 no jump action.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Verification (9): the floor limit is `floor_max_angle` + about 0.5°, so 40.0 lets 40° climb and blocks 41°. Verification (4), (6) PASS (`intersect_shape` with `margin = 0`; no seam snag with large floor boxes). Verification (7): other players must be tested analytically, not through the space.

**Control Manifest Rules (this layer)**:
- Required: climb steps through ramp colliders
- Forbidden: custom step-up code

---

## Acceptance Criteria

*From `first-person-controller.md` Acceptance Criteria (Body and gaits) and Edge Cases (standing up blocked), scoped to this story:*

- [x] Test geometry with steps of 0.18, 0.35 and 0.40 m and ramps of 40° and 41°: a player climbs the 0.18 and 0.35 m steps (each with its ramp collider) and the 40° ramp, and is blocked by the 0.40 m step and the 41° ramp.
- [x] A crouched player under a 1.5 m ceiling who releases crouch stays at 1.2 m until reaching open floor, then stands within 1 tick.
- [x] A player whose head room is blocked only by another player's capsule stays crouched (analytic test), and stands once that player leaves.
- [x] No jump action exists in the input map (test reads `InputMap`).

---

## Implementation Notes

*Derived from ADR-0007 Decision §2–4, §6a:*

- Build the test geometry in code in the test, with large box floors.
- The analytic player test reuses ADR-0003's capsule maths at current-tick positions from the history buffer (network-authority story 007); stub the history here if that story is not done.

---

## Out of Scope

- Hide-exit placement (Survivor Defense epic)
- Camera smoothing over ramps (presentation)

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-004-2026-10-14.md` (/qa-plan, 2026-10-14). Implement against these and the Acceptance Criteria above.*

**Test file path**: `tests/integration/first-person-controller/steps_stand_up_test.gd`
**What to test**:
- Steps 0.18 and 0.35 m (with ramp colliders) and a 40° ramp are climbed; a 0.40 m step and a 41° ramp block.
- Crouched under a 1.5 m ceiling, releasing crouch stays at 1.2 m until open floor, then stands within 1 tick.
- Head room blocked only by another capsule: stays crouched (analytic test), stands once it leaves.
- No jump action in `InputMap`.

**Estimated test count**: ~6 integration tests

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/first-person-controller/steps_stand_up_test.gd` — must exist and pass

**Status**: [x] Created; passes (10 tests). AC4 is `tests/unit/first-person-controller/view_direction_test.gd` `test_input_map_holds_exactly_the_eleven_actions_and_no_jump` (story 005)

---

## Dependencies

- Depends on: Stories 001, 002
- Unlocks: facility-map collision authoring

---

## Completion Notes

**Completed**: 2026-10-14
**Criteria**: 4/4 passing (automated; AC4 by an existing test)
**Deviations** (AD-111):
- `PlayerBody.set_low(low, others)` takes other players' capsules as `Vector4(feet x, y, z, height)` at current-tick positions and tests them analytically (`PlayerBody.capsules_overlap`, ADR-0003 §6 maths; a capsule shorter than 2r is clamped to a sphere). The physics probe still tests world, glass and doors only.
- Step ramp colliders are tested at 35° and at the 40° maximum (ADR-0007 §4); the 0.40 m step has no ramp, as §4 gives ramps only to steps up to 0.35 m.
- Not wired yet: nothing in production calls `set_low(crouch, others)` once per tick, and the `others` feed from current-tick positions is not built. AC2 ("stands within 1 tick") and AC3 are proven on a test loop that does what that caller must do. The caller belongs to the story that first drives PlayerBody from ServerMovement and the owner's prediction (no scene drives MovementStep yet; see story 002 notes).
- The margin-0 probe clears a float hair before the exact geometric edge; the test allows the stand one tick either side of the computed clear tick and asserts the body is crouched on every tick it is still under the ceiling.
**Test Evidence**: Integration: `tests/integration/first-person-controller/steps_stand_up_test.gd`; 8 mutations each caught. Full suite 455/455.
**Code Review**: Complete (godot-gdscript-specialist and qa-tester; S2 test gap fixed: 40° step ramps; S2 wiring gap recorded above)
