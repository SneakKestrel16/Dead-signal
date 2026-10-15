# Manual test cases: CI-6 mouse look (controller story 006, AC4)

**Story**: `production/epics/controller-interaction/story-006-view-direction-input-actions.md`
**Story type**: Logic. AC4 is the manual part: it needs a running build and a person.
**Evidence location**: results go in the story's Completion Notes (AC4 line). Screenshots go in `production/qa/evidence/controller-006-*.png`.
**Gate level**: BLOCKING for AC4. The story is Complete with AC4 DEFERRED, and AC4 closes only on these cases.
**Tester**: designer, one Windows PC.
**Harness**: `tests/manual/mouse_look_check.tscn` (script `tests/manual/mouse_look_check.gd`). Pillars: red at yaw 0, green at yaw +90° (turned left), blue at yaw -90° (turned right). The label shows yaw, pitch (degrees) and window size. F11 halves the window. Esc releases the mouse.

## Facts the cases rely on (from source)

- Sensitivity is `LocalInput.sensitivity = 0.0025` rad per screen pixel (`src/core/controller/local_input.gd`). A 90° turn is therefore about 628 pixels of `screen_relative` travel.
- The pitch limit is `ViewState.PITCH_LIMIT = deg_to_rad(InputQueue.PITCH_LIMIT_DEG)`, where `PITCH_LIMIT_DEG = 85.0` (`src/foundation/network/input_queue.gd`). Positive pitch looks up.
- `LocalInput` clamps pitch each time it accumulates, so it does not remember overshoot past the limit.
- On `NOTIFICATION_APPLICATION_FOCUS_IN` the mouse is re-captured unconditionally. That includes after Esc (logged deviation AD-76). The harness has no click-to-capture.

## Common setup (every case)

1. **Stretch mode.** `project.godot` has no `[display]` stretch setting, so the stretch mode is the default, `disabled`. With stretch disabled, `relative` equals `screen_relative`. CI-6-01 then cannot detect the bug it exists for, which is sensitivity scaled by the `canvas_items` stretch. Before CI-6-01:
   - In the editor, set Project Settings > Display > Window > Stretch > Mode = `canvas_items`.
   - Run the scene with F6 (Run Current Scene).
   - Afterwards, revert the setting. Do not commit `project.godot`.
   - Record which stretch mode you used in Actual Result.
2. **Pointer acceleration.** Turn Windows "Enhance pointer precision" off for the session and restore it afterwards. This is an inference: it may affect the captured-mouse delta, and it would make hand travel non-repeatable.
3. **Launch.** Run from the editor (F6 on the scene), or from Git Bash:
   `"C:/Users/Ockey/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe" --path C:/Users/Ockey/dead-signal res://tests/manual/mouse_look_check.tscn`
   The command line has no stretch override, so use the editor for CI-6-01.

---

## Test Case: CI-6-01: The same mouse travel turns 90° at full and half window size

**Preconditions**:
- Common setup done, with stretch mode `canvas_items`.
- The scene is running in windowed mode at its launch size, and the label shows that size.
- The mouse is captured: no cursor is visible.
- On the desk, two physical stops for the mouse (for example a book edge and a ruler), placed in Step 2.

**Steps**:
1. Face the red pillar. The label reads yaw 0.0 ± 1°; nudge the mouse until it does.
2. With the mouse against the right-hand stop, slide it slowly to the left until the green pillar is centred and the label reads yaw +90°. Place the left-hand stop against the mouse there.
3. Return to the red pillar (yaw 0.0 ± 1°) with the mouse against the right-hand stop. Slide it stop to stop at a slow, steady speed. Record the yaw. Repeat 3 times in total.
4. Press F11 once. Confirm that the label's window size is half the launch size on both axes. Take a screenshot.
5. Repeat Step 3 three times at half size: re-centre on red at yaw 0, then slide stop to stop. Record each yaw.
6. Compare the mean of the three full-size readings with the mean of the three half-size readings.

**Expected Result**:
- All six readings are within 90° ± 5°.
- The two means differ by no more than 5°.
- At half size, the turn is not near 45° and not near 180°. Either of those is the signature of window-scaled sensitivity.

**Pass Criteria**: PASS if all six readings are in [85°, 95°] and |mean_full − mean_half| ≤ 5°. If the three full-size readings spread more than 5° among themselves, the method is too imprecise: record INCONCLUSIVE, tighten the stops and rerun. Neither a pass nor a fail can be claimed from it.

**Why ±5° (inference, not measured)**:
- The defect this case targets changes the turn by a factor of 2 at half size (45° or 180°), so ±5° separates pass from fail with a wide margin.
- ±5° is about 35 pixels of the 628-pixel travel. That is roughly the repeatability expected from a slow swipe between fixed stops.
- The spread of the three full-size readings settles whether the method meets that tolerance. That is why the INCONCLUSIVE rule exists.

**Actual Result**: Stretch `canvas_items` (temporary `override.cfg`, removed after; `project.godot` untouched). Full window: yaw 1 to 141 (140°). Half window (F11): yaw 6 to 146 (140°). Same travel between desk stops. Window sizes not recorded. Designer, 2026-10-15.
**Pass/Fail**: PASS

---

## Test Case: CI-6-02: Alt-tab away and back re-captures the mouse without a click

**Preconditions**:
- The scene is running and the mouse is captured: no cursor, and moving the mouse changes the yaw on the label.
- Another window (for example Explorer) is open.

**Steps**:
1. Press Alt+Tab to switch to the other window.
2. Move the mouse over the other window. Check that the cursor is visible and usable there.
3. Press Alt+Tab to return to the check scene. Do not click.
4. Move the mouse left and right.
5. Repeat Steps 1–4, but this time return by clicking the scene's taskbar button instead of using Alt+Tab.

**Expected Result**:
- Step 2: the cursor is visible outside the game.
- Steps 3–4 and Step 5: on return, the cursor is hidden and the yaw on the label changes with mouse motion, with no click inside the game window.

**Pass Criteria**: PASS if, in both return methods, the yaw changes on the first mouse motion after focus returns and no cursor is visible over the game. FAIL if either method needs a click, or if the cursor stays visible.

**Actual Result**: Alt-tab away and back re-captured the mouse without a click. Designer, 2026-10-15.
**Pass/Fail**: PASS

---

## Test Case: CI-6-03: Pitch clamps at ±85°

**Preconditions**:
- The scene is running and the mouse is captured.
- The label reads pitch 0.0 ± 1°.

**Steps**:
1. Move the mouse forward (up) steadily until the label's pitch stops rising. Keep moving another full mouse-pad length.
2. Record the pitch.
3. Move the mouse back (down) by a short distance, about 1 cm.
4. Move the mouse back until the pitch stops falling. Keep moving another full mouse-pad length.
5. Record the pitch.
6. Do one very fast flick up and record the pitch. This is a large single-frame delta past the clamp.

**Expected Result**:
- Step 2: pitch is +85.0°.
- Step 3: pitch drops below 85° at once. No overshoot is remembered, so you do not have to "unwind" the extra travel.
- Step 5: pitch is -85.0°.
- Step 6: pitch is +85.0°.
- At no point does the label show |pitch| > 85.0°, and the view never flips upside down.

**Pass Criteria**: PASS if the readings at Steps 2 and 6 are 85.0 and at Step 5 is -85.0 (the label shows one decimal), and Step 3 shows a value under 85.0 straight after the first downward motion.

**Actual Result**: Pitch stopped at +85 and -85. Designer, 2026-10-15.
**Pass/Fail**: PASS

---

## Test Case: CI-6-04: Esc releases the mouse

**Preconditions**: the scene is running and the mouse is captured.

**Steps**:
1. Press Esc.
2. Move the mouse across the game window.
3. Click inside the game window, then move the mouse again.
4. Press Alt+Tab away and back (see CI-6-02).

**Expected Result**:
- Steps 1–2: the cursor is visible, and the yaw and pitch on the label do not change while the mouse moves.
- Step 3: the mouse stays released. The harness has no click-to-capture, so this is not a failure.
- Step 4: the mouse is captured again. This is by design: recapture on focus is unconditional (AD-76) until ADR-0014's InputContextStack exists.

**Pass Criteria**: PASS if, after Esc, the yaw and pitch on the label stay constant (±0.1°) through at least 5 seconds of mouse motion, and the cursor is visible.

**Actual Result**: Esc released the mouse. Designer, 2026-10-15.
**Pass/Fail**: PASS
