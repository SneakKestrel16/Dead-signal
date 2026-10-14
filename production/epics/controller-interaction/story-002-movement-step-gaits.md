# Story 002: Shared movement step and gaits

> **Epic**: First-Person Controller & Interaction
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

One movement function runs on the server and on the owning client. It turns an input frame into velocity through four gaits (crawl, crouch, walk, sprint) with a short acceleration ramp that the dodge budget depends on.

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-controller-001`, `TR-controller-003`, `TR-controller-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Movement, physics and collision layers (primary); ADR-0002: Authoritative simulation, tick and input; ADR-0006: Data-driven configuration
**ADR Decision Summary**: Horizontal velocity moves toward `input_dir × effective_speed` over `accel_time_s` 0.05; vertical from `get_gravity()`, zeroed on floor; floor settings (`floor_max_angle` 40.0°, `floor_snap_length` 0.4, stop on slope, constant speed, block on wall, `safe_margin`, `max_slides`, `wall_min_slide_angle`) from data; `is_on_floor()` read back for the snapshot; no jump. Gait speeds from `ControllerKnobs`.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: Verification (2): `safe_margin` 0.001, `max_slides` 6, `wall_min_slide_angle` 15° on 4.7.2; set them explicitly anyway. Floor state cannot be set, only recomputed with `apply_floor_snap()`.

**Control Manifest Rules (this layer)**:
- Required: one movement step function shared by server and owning client; floor and slide settings from data
- Forbidden: client-only movement code; assuming the previous floor state carries over after setting position

---

## Acceptance Criteria

*From `first-person-controller.md` Acceptance Criteria (Body and gaits) and Formulas (gait_speed, gait order, move_input cap), scoped to this story:*

- [ ] With `walk_speed` 4.0 and full input on flat ground, 1 s of simulated ticks per gait gives crawl 1.0, crouch 2.0, walk 4.0, survivor sprint 5.0 and true-form sprint 5.75 m/s (±0.05).
- [ ] With sprint held, move input 30°, 45° (≤ 45° + 1e-4 counts as inside), 46° and 180° off facing gives 5.0, 5.0, 4.0 and 4.0 m/s; crouched, Downed, Transforming or Holding with sprint held gives crouch 2.0, crawl 1.0, walk 4.0 and walk 4.0.
- [ ] A diagonal key input of length 1.41 walks at 4.0 m/s, not 5.66.
- [ ] From rest, horizontal speed reaches the gait speed in `accel_time_s` (0.05 s default, ≤ 0.09 s) ± 1 tick.

---

## Implementation Notes

*Derived from ADR-0007 Decision §3 and `first-person-controller.md` Formulas:*

- `MovementStep.step(body, frame, state, knobs) -> void` is the only place velocity is set; prediction (network-authority story 006) calls the same function.
- Gait order: Out/Downed → crawl, crouch → crouch, Holding/Transforming → walk, sprint within the 45° cone → sprint, else walk.
- Effective speed comes from Story 003's modifier set; stub it at 1.0 here.
- Run the tests headless on a flat box floor; no networking needed.

---

## Out of Scope

- Story 003: modifiers
- Story 004: steps, slopes and stand-up
- network-authority story 006: prediction and reconciliation

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/first-person-controller/movement_step_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: Stories 003, 004, 006, 015; network-authority story 006
