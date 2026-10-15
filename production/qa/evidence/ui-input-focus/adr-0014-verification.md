# ADR-0014 Verification Required: evidence

Engine: Godot 4.7.2.stable.official.ed1daf0bf (Windows 11). Test: `tests/integration/ui-input-focus/adr_0014_verification_test.gd`, run headless (`--headless ... --ignoreHeadlessMode -c`, 6/6 pass) and windowed (same without `--headless`, 6/6 after the BUG-0014 fix; 5/6 before it). Events are injected with `Input.parse_input_event`, the dispatch path OS input takes. Numbers are the test's `ADR14` lines, 2026-10-15, build `73d873e`.

| # | Item | Result | Number | Test |
|---|---|---|---|---|
| 1 | Polling still reports keys a focused `Control` consumes | PASS (mask needed, as the ADR inferred) | Focused `LineEdit` typed `w`; `is_action_pressed(move_forward)` = true, `get_vector` = (0, 1); (0, 0) after release | `test_v1_polling_reports_keys_a_focused_control_consumes` |
| 2 | Push grabs focus; key/pad nav start there; hover does not move focus; pop restores after a click | PASS (windowed) | push -> b0; Down key -> b1; pad D-pad down -> b2; hover over b3 (hovered = true) -> focus stays b2; click b3 -> b3; pop -> `lower` (focused before push) | `test_v2_push_focus_nav_hover_click_pop` |
| 3 | NVDA reads focused results rows, polite feed announcement, countdown never announced | NOT ASSESSED (human-only) | - | Manual steps below |
| 4 | CAPTURED -> VISIBLE -> CAPTURED, first relative motion discarded | PASS after BUG-0014 fix (FAIL at `73d873e`) | Modes 2 -> 0 -> 2; first 400 px motion after recapture: yaw change 0.0000 rad (was -1.0000 before the fix); next 10 px -0.0250 rad. Headless regression: `tests/unit/ui-input-focus/recapture_motion_discard_test.gd` | `test_v4_first_motion_after_recapture_is_discarded` (windowed) |
| 5a | 40 markers projected and clamped per frame under 0.2 ms | PASS | `PingCalloutHud.place` x 40 x 1000 frames: windowed median 39 us, p99 47 us, max 52 us; headless median 39 us, p99 55 us, max 164 us | `test_v5_forty_markers_projected_and_clamped_under_budget` |
| 5b | Markers land on targets at `content_scale_factor` 1.0 and 1.5 | PASS | Worst marker-to-target error 0.000 px at both; viewport rect 1920x1080 at 1.0, 1280x720 at 1.5, physical 1920x1080 | `test_v5_markers_land_on_targets_at_scale_1_and_1_5` |
| 6 | `Input.mouse_mode`, `MOUSE_MODE_*`, `AccessibilityServer.AccessibilityLiveMode` names exist | PASS | `MouseMode` = VISIBLE, HIDDEN, CAPTURED, CONFINED, CONFINED_HIDDEN, MAX; `AccessibilityLiveMode` = LIVE_OFF, LIVE_POLITE, LIVE_ASSERTIVE; `Control.accessibility_live` property present | `test_v6_api_names_exist` |

## Limits
- Item 2 hover and click need a window (the headless root window has no size, so mouse events hit nothing); headless runs assert the push, key, pad and pop part only. Pad navigation was checked with an injected `InputEventJoypadButton`, not a physical SDL3 pad; a real pad would settle the driver side.
- Item 4 is skipped headless (headless ignores `Input.mouse_mode`). It checks our code against an injected motion; whether Windows itself sends a large first motion on recapture needs a real mouse (BUG-0014 notes).
- Item 5a times the projection and clamp (`place`, which `_draw` calls per marker), not label text measurement or drawing. The headless 164 us max is a single-frame outlier inside the budget.
- Item 5b checks `place()` in `get_viewport_rect()` space (what `_draw` passes) mapped through the window's final transform against an independent projection into physical pixels, in an embedded 1920x1080 `Window`. The project sets no stretch mode (ADR-0014 §9 notes it); re-run when it is set to `canvas_items`.

## Item 3 manual steps (NVDA, Windows)
1. Install NVDA (current release); start it with default settings.
2. Launch a windowed build; finish a round so the results screen shows.
3. Tab / arrow through the results rows. Expected: NVDA speaks each focused row's `accessibility_name`.
4. During a round, receive a callout. Expected: NVDA speaks the feed line once, without interrupting current speech (polite).
5. Watch the results countdown for 10 s. Expected: NVDA never announces the countdown.
6. Record PASS / FAIL per step here with NVDA and build versions.

## Sign-off
- [ ] QA lead
