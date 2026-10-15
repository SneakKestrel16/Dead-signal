# Story hud-results/012: a gamepad binding for every action (hud.md Platform Adaptation, Gamepad Partial).
# The pad layout is INFERENCE (no GDD or ADR names a button); a controls pass with a pad playtest settles it:
#   left stick move_*; right stick look (LocalInput) and wheel steering; LS click sprint; B crouch;
#   X interact; Y interact_alt; RT use_item; RB ping; LB callout_wheel (held, steered with the right
#   stick); D-pad up flashlight, down warning_ping; Back feed_scrollback; RS click lunge; D-pad left
#   false_signal, right blackout; LT form_picker (held, steered with the right stick). A and Start free.
# Every game action is live in the GAMEPLAY context (ADR-0014 §1), so no two share a pad input. The
# built-in ui_* actions reuse A, B and the D-pad, but they only drive focus in OVERLAY / MENU / MODAL,
# where `actions` is off, so the context stack keeps them exclusive.
extends GdUnitTestSuite

const VIEW_DIRECTION := preload("res://tests/unit/first-person-controller/view_direction_test.gd")


func _pad_events(action: StringName) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventJoypadButton or e is InputEventJoypadMotion:
			out.append(e)
	return out


func test_every_pinned_action_has_a_joypad_event_on_any_device() -> void:
	for a: String in VIEW_DIRECTION.ACTIONS:
		var pad := _pad_events(StringName(a))
		assert_int(pad.size()).override_failure_message(a + " has no joypad binding").is_greater(0)
		for e in pad:
			assert_int(e.device).override_failure_message(a + " pad event is not all-devices").is_equal(-1)


func test_movement_is_on_the_left_stick() -> void:
	var want := {&"move_left": [JOY_AXIS_LEFT_X, -1.0], &"move_right": [JOY_AXIS_LEFT_X, 1.0],
		&"move_forward": [JOY_AXIS_LEFT_Y, -1.0], &"move_back": [JOY_AXIS_LEFT_Y, 1.0]}
	for a: StringName in want:
		var m := _pad_events(a)[0] as InputEventJoypadMotion
		assert_object(m).override_failure_message(String(a) + " is not a stick axis").is_not_null()
		assert_int(m.axis).is_equal(want[a][0])
		assert_float(signf(m.axis_value)).is_equal(want[a][1])


func test_no_two_gameplay_actions_share_a_pad_input() -> void:
	var seen := {}
	for a: String in VIEW_DIRECTION.ACTIONS:
		for e in _pad_events(StringName(a)):
			var key := ""
			if e is InputEventJoypadButton:
				key = "button %d" % (e as InputEventJoypadButton).button_index
			else:
				var m := e as InputEventJoypadMotion
				key = "axis %d %s" % [m.axis, "+" if m.axis_value > 0 else "-"]
			assert_bool(seen.has(key)).override_failure_message("%s on %s, already %s" % [a, key,
					seen.get(key, "")]).is_false()
			seen[key] = a


func test_prompt_glyph_follows_the_last_device() -> void:
	var g := InputGlyphs.new()
	var key := g.glyph_text(&"interact")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	g.note_event(pad)
	assert_int(g.device).is_equal(InputGlyphs.Device.GAMEPAD)
	assert_str(g.glyph_text(&"interact")).is_equal("X")
	assert_str(g.glyph_text(&"form_picker")).is_equal("LT")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_E
	g.note_event(k)
	assert_str(g.glyph_text(&"interact")).is_equal(key)
	assert_str(key).is_equal("E")


func test_right_stick_turns_the_view_and_stops_on_release() -> void:
	var li: LocalInput = auto_free(LocalInput.new())
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 1.0
	li.handle(stick)
	li.stick_look(0.5)
	assert_float(li.yaw).is_less(0.0) ## stick right turns right (yaw falls), as the mouse does
	var turned := li.yaw
	stick.axis_value = 0.1 ## inside the dead zone
	li.handle(stick)
	li.stick_look(0.5)
	assert_float(li.yaw).is_equal(turned)
