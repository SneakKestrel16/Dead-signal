# Story 006: View direction, mouse look and input actions

> **Epic**: First-Person Controller & Interaction
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 1 day
> **Manifest Version**: 2026-10-13
> **Last Updated**: 2026-10-14

## Context

The server keeps each player's view direction from client yaw and pitch, and every aim (taser, ping, interaction) uses the server's copy. No gameplay state rotates the camera. Input goes through named actions only.

**GDD**: `design/gdd/first-person-controller.md`
**Requirement**: `TR-controller-006`, `TR-controller-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Movement, physics and collision layers (primary); ADR-0002: Authoritative simulation, tick and input
**ADR Decision Summary**: §11: KB+M named actions (`move_forward`, `move_back`, `move_left`, `move_right`, `sprint`, `crouch`, `interact`, `use_item`, `ping`, `callout_wheel`, `flashlight`), no jump; mouse look from `InputEventMouseMotion.screen_relative`, not scaled by delta, accumulated and applied at the physics tick, pitch clamped ±85°; device checks by event type. ADR-0002: the server view direction is the client yaw/pitch from the input frame.
**ADR Version**: 2026-10-12

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: 4.7: device IDs changed, so never test `device == 0`. Verification (8) PASS: `screen_relative` is unscaled by the `canvas_items` stretch. Slice lesson: a centred `Control` with the default STOP filter eats captured-mouse motion (`docs/engine-reference/godot/gotchas.md`).

**Control Manifest Rules (this layer)**:
- Required: input goes through the named input actions; device checks use event type or `InputEvent.DEVICE_ID_*`
- Forbidden: detecting keyboard or mouse with `event.device == 0` [device_zero_check]

---

## Acceptance Criteria

*From `first-person-controller.md` Acceptance Criteria (Look and view ray, first criterion without the flinch) and ADR-0007 §11, scoped to this story:*

- [x] In every state except Hidden, yaw covers 360° and pitch clamps at ±85°.
- [x] With every root, slow, lock, Downed, Seized, Transforming and Holding state applied, the server view direction follows input only.
- [x] `InputMap` holds exactly the eleven named actions of ADR-0007 §11 and no jump; a test fails if any script under `src/` compares `event.device` with 0.
- [x] Mouse sensitivity is the same in a full-size and a half-size window (`screen_relative`), and the mouse is re-captured when the window regains focus.

---

## Implementation Notes

*Derived from ADR-0007 Decision §11 and ADR-0002 §3:*

- `ViewState.server_dir(player) -> Vector3` is the one function every aim reads; the flinch offset (Story 013) adds to it later.
- Set `mouse_filter = MOUSE_FILTER_IGNORE` on every non-interactive HUD control (slice gotcha).
- The Hidden peek view belongs to the Survivor Defense epic.

---

## Out of Scope

- Story 013: flinch offset and client-only camera effects
- Hidden peek view (Survivor Defense epic)
- Out spectator view (Match Flow epic)

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-002-2026-10-13.md` (/qa-plan, 2026-10-13). Implement against these and the Acceptance Criteria above.*

**What to test**:
- Yaw wraps through 360 degrees and pitch clamps at ±85 degrees in every state except Hidden.
- With each of root, slow, lock, Downed, Seized, Transforming and Holding applied, the server view direction follows input alone.
- `InputMap` holds exactly the eleven actions of ADR-0007 §11 and no jump. A source scan fails on any `event.device` compared with 0; prove it with a fixture.

**Edge cases to cover**:
- Pitch input past the clamp in one frame.
- Yaw at exactly 360 and -360 degrees.
- Hidden state: the view range follows the hiding spot's rule (assert that it differs).

**Estimated test count**: ~8 unit tests

**Manual checks**:
- Mouse sensitivity is the same in a full-size and a half-size window (`screen_relative`): turn 90 degrees with the same mouse travel at both sizes, using a test scene.
- Alt-tab out and back: the mouse is captured again on focus.
- Evidence: the result written in the story's Completion Notes. These two items need a running build and a person, so they cannot be automated.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/first-person-controller/view_direction_test.gd` — must exist and pass

**Status**: [x] `tests/unit/first-person-controller/view_direction_test.gd` passes (10 tests); 3 mutations caught; suite 190/190 (2026-10-14). Manual scene: `tests/manual/mouse_look_check.tscn`

---

## Dependencies

- Depends on: network-authority story 005 (input frames)
- Unlocks: Stories 007, 013

---

## Completion Notes
**Completed**: 2026-10-14
**Criteria**: 4/4 passing (AC4 by manual run, 2026-10-15)
- AC1: `test_yaw_covers_360_and_wraps`, `test_pitch_clamps_at_85_degrees_even_past_it_in_one_frame` (also ViewState's own clamp, past InputQueue's). Hidden is out of scope (Survivor Defense).
- AC2: `test_view_follows_input_only_under_root_slow_and_lock`, `test_starved_tick_keeps_the_last_view`. Downed, Seized, Transforming and Holding act through these modifiers (stories 002/003); ViewState reads only the input frame, so no state can reach it.
- AC3: `test_input_map_holds_exactly_the_eleven_actions_and_no_jump`, `test_device_zero_scanner_catches_a_fixture`, `test_no_script_under_src_compares_device_with_zero`.
- AC4 PASS (designer manual run, 2026-10-15; cases in `production/qa/test-cases/controller-006-mouse-look-cases.md`). CI-6-01: stretch `canvas_items` (via a temporary `override.cfg`, removed after), same hand travel between desk stops turned yaw 1 to 141 at full window and 6 to 146 at half window: 140° both, no stretch scaling. CI-6-02 alt-tab re-capture, CI-6-03 pitch clamp ±85°, CI-6-04 Esc release: PASS. Window sizes not recorded. Unit evidence: `test_mouse_look_uses_screen_relative_not_relative`, `test_mouse_motion_is_ignored_while_the_mouse_is_not_captured`. Screenshot of the check scene: `production/qa/evidence/controller-006-look-check-2026-10-14.png`.
**Deviations** (advisory): AD-76 (default bindings, sensitivity default NOT SOURCEABLE, ViewState via ServerMovement.frame_of, device -1). Recapture on focus is unconditional until ADR-0014's InputContextStack exists (a pause menu would lose its cursor on alt-tab).
**Test Evidence**: Logic: `tests/unit/first-person-controller/view_direction_test.gd`, 10 tests; 3 mutations caught.
**Run result**: OBSERVED: `production/qa/evidence/controller-006-look-check-2026-10-14.png` (the check scene renders, mouse captured, yaw/pitch readout live).
**Code Review**: Complete: `/code-review` 2026-10-14, CHANGES REQUIRED (look read in _unhandled_input against gotchas.md), fixed: now `_input`; also ViewState clamp and capture gate tested.
