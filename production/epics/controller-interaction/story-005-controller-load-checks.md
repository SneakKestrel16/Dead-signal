# Story 005: Controller load-time checks

> **Epic**: First-Person Controller & Interaction
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Two balance limits must hold for the chase and dodge numbers to work, and the interaction ray must reach every owner's range. A bad data file must refuse to host, naming the rule.

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-controller-003`, `TR-controller-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Data-driven configuration
**ADR Decision Summary**: Typed `Resource` sections validated at load; cross-knob rules produce named errors that block hosting (data-config stories 003, 004).
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM
**Engine Notes**: None beyond data-config: `Resource` and `.tres` are stable since 4.0.

**Control Manifest Rules (this layer)**:
- Required: every cross-knob check has a source comment (data-config story 003)
- Forbidden: hardcoded gameplay values

---

## Acceptance Criteria

*From `first-person-controller.md` Acceptance Criteria (Hold-to-interact: joint cap; ray reach) and Formulas (gait speed joint cap, catch_gap, interact_ray_max), scoped to this story:*

- [ ] `walk_speed` 4.5 with `sprint_mult` 1.25 (5.63 m/s), or `monster_sprint_mult` 1.0, fails the load-time check naming the joint sprint cap; 4.0 × 1.35 = 5.4 passes (1e-4 m/s epsilon).
- [ ] With `player_radius_m` 0.35 and v_s 5.4, the `catch_gap ≥ 2 × radius` check fails.
- [ ] The check fails if `interact_ray_max_m` < max owner `range_m` + (`eye_height_m` − `capsule_height_m` / 2) for either posture.

---

## Implementation Notes

*Derived from data-config story 003 (cross-knob rule pattern) and `first-person-controller.md` Formulas:*

- Add the three rules to the cross-knob validator, each citing `first-person-controller.md` Formulas.
- Max owner `range_m` comes from the owners' sections at validation time, not a constant.

---

## Out of Scope

- The refuse-to-host UI (data-config story 004)

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/first-person-controller/controller_load_checks_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: data-config stories 002, 003
- Unlocks: none
