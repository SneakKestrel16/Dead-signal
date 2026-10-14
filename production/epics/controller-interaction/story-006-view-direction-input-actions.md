# Story 006: View direction, mouse look and input actions

> **Epic**: First-Person Controller & Interaction
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: [fill before sprint planning]
> **Manifest Version**: 2026-10-13
> **Last Updated**: [set by /dev-story when implementation begins]

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

- [ ] In every state except Hidden, yaw covers 360° and pitch clamps at ±85°.
- [ ] With every root, slow, lock, Downed, Seized, Transforming and Holding state applied, the server view direction follows input only.
- [ ] `InputMap` holds exactly the eleven named actions of ADR-0007 §11 and no jump; a test fails if any script under `src/` compares `event.device` with 0.
- [ ] Mouse sensitivity is the same in a full-size and a half-size window (`screen_relative`), and the mouse is re-captured when the window regains focus.

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

*Test cases not yet defined — run /qa-plan to generate them.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/first-person-controller/view_direction_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: network-authority story 005 (input frames)
- Unlocks: Stories 007, 013
