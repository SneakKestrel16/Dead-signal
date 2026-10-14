# Story 004: Steps, slopes and the stand-up check

> **Epic**: First-Person Controller & Interaction
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] Test geometry with steps of 0.18, 0.35 and 0.40 m and ramps of 40° and 41°: a player climbs the 0.18 and 0.35 m steps (each with its ramp collider) and the 40° ramp, and is blocked by the 0.40 m step and the 41° ramp.
- [ ] A crouched player under a 1.5 m ceiling who releases crouch stays at 1.2 m until reaching open floor, then stands within 1 tick.
- [ ] A player whose head room is blocked only by another player's capsule stays crouched (analytic test), and stands once that player leaves.
- [ ] No jump action exists in the input map (test reads `InputMap`).

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

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/first-person-controller/steps_stand_up_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001, 002
- Unlocks: facility-map collision authoring
