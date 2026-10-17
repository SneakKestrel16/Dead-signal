extends GdUnitTestSuite
## SettingsScreen (interaction-patterns.md P15, P17, P20, P21): each control writes its setting, Back and
## Esc/B close, the screen pushes and pops its input context, focus runs top to bottom ending on Back, and
## closing saves.

var _path := ""
var _settings: PlayerSettings
var _stack: InputContextStack


func before_test() -> void:
	_path = create_temp_dir("settings_screen") + "/settings.cfg"
	_settings = PlayerSettings.new(_path, [])
	_stack = InputContextStack.new()


func _open(ctx: InputContextStack.Ctx = InputContextStack.Ctx.OVERLAY, in_round := true) -> SettingsScreen:
	var s := SettingsScreen.new(_settings, _stack, ctx, in_round)
	add_child(s)
	return s


func test_every_setting_has_a_control() -> void:
	var s := _open()
	assert_array(s.controls.keys()).contains_exactly_in_any_order(PlayerSettings.SPEC.keys())
	s.free()


func test_each_toggle_writes_its_setting() -> void:
	var s := _open()
	for key: StringName in [&"reduced_motion", &"reduced_flash"]:
		(s.controls[key] as CheckButton).button_pressed = true
		assert_bool(_settings.get(key)).is_true()
		assert_str((s.controls[key] as CheckButton).text).is_equal("On")
	(s.controls[&"camera_flinch"] as CheckButton).button_pressed = false
	assert_bool(_settings.camera_flinch).is_false()
	s.free()


func test_each_slider_writes_its_setting() -> void:
	var s := _open()
	for key: StringName in PlayerSettings.SPEC:
		var spec: Array = PlayerSettings.SPEC[key]
		if spec.size() < 3:
			continue
		var slider := s.controls[key] as HSlider
		slider.value = spec[1]
		assert_float(_settings.get(key)).is_equal_approx(spec[1], 1e-9)
	s.free()


func test_slider_steps_are_five_percent_of_range() -> void:
	var s := _open()
	var slider := s.controls[&"master_volume"] as HSlider
	assert_float(slider.step).is_equal_approx(0.05, 1e-9)
	s.free()


func test_every_slider_opens_on_its_default() -> void:
	# A default off the step grid snaps on open: hud_scale's range / 20 showed 1.0 as 101%.
	for key: StringName in PlayerSettings.SPEC:
		_settings.set(key, PlayerSettings.SPEC[key][0])
	var s := _open()
	for key: StringName in PlayerSettings.SPEC:
		var spec: Array = PlayerSettings.SPEC[key]
		if spec.size() == 3:
			assert_float((s.controls[key] as HSlider).value).override_failure_message(String(key)) 				.is_equal_approx(spec[0], 1e-9)
	s.free()


func test_backing_is_opaque_over_the_lobby_and_dim_over_a_round() -> void:
	var menu := _open(InputContextStack.Ctx.MENU, false)
	assert_float((menu.get_child(0) as ColorRect).color.a).is_equal(1.0)
	menu.free()
	var round_view := _open()
	assert_float((round_view.get_child(0) as ColorRect).color.a).is_less(1.0)
	round_view.free()


func test_readout_shows_percent() -> void:
	var s := _open()
	(s.controls[&"voice_volume"] as HSlider).value = 0.5
	assert_str(s.readouts[&"voice_volume"].text).is_equal("50%")
	(s.controls[&"stick_rate"] as HSlider).value = 6.0
	assert_str(s.readouts[&"stick_rate"].text).is_equal("200%")
	s.free()


func test_open_pushes_and_close_pops_the_context() -> void:
	var s := _open()
	assert_int(_stack.top()).is_equal(InputContextStack.Ctx.OVERLAY)
	s.free()
	assert_int(_stack.top()).is_equal(InputContextStack.Ctx.GAMEPLAY)


func test_a_reset_stack_is_not_popped_again() -> void:
	var s := _open()
	_stack.reset(InputContextStack.Ctx.MENU) # round end drops a stale overlay (ADR-0014 §1)
	await assert_error(s.free).is_success() # no "pop but top is MENU" error
	assert_int(_stack.top()).is_equal(InputContextStack.Ctx.MENU)


func test_back_button_closes() -> void:
	var s := _open()
	var closed := [false]
	s.closed.connect(func() -> void: closed[0] = true)
	s.back_button.pressed.emit()
	assert_bool(closed[0]).is_true()
	s.free()


func test_cancel_and_menu_close() -> void:
	for action: StringName in [&"ui_cancel", &"menu"]:
		var s := _open()
		var closed := [false]
		s.closed.connect(func() -> void: closed[0] = true)
		var e := InputEventAction.new()
		e.action = action
		e.pressed = true
		s._unhandled_input(e)
		assert_bool(closed[0]).override_failure_message(String(action)).is_true()
		s.free()


func test_focus_runs_down_the_rows_and_ends_on_back() -> void:
	var s := _open()
	var stops := s.focus_stops
	assert_object(stops[stops.size() - 1]).is_same(s.back_button)
	for i in stops.size() - 1:
		assert_object(stops[i].get_node(stops[i].focus_neighbor_bottom)).is_same(stops[i + 1])
		assert_object(stops[i + 1].get_node(stops[i + 1].focus_neighbor_top)).is_same(stops[i])
	assert_object(stops[0]).is_same(s.controls[&"reduced_motion"])
	s.free()


func test_round_note_only_in_round() -> void:
	var s := _open()
	assert_bool(s.round_note.visible).is_true()
	s.free()
	var t := _open(InputContextStack.Ctx.MENU, false)
	assert_bool(t.round_note.visible).is_false()
	t.free()


func test_closing_saves() -> void:
	var s := _open()
	(s.controls[&"reduced_flash"] as CheckButton).button_pressed = true
	s.free()
	assert_bool(PlayerSettings.new(_path, []).reduced_flash).is_true()
