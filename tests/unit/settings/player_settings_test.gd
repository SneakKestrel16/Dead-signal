extends GdUnitTestSuite
## PlayerSettings (design/game-brief.md MVP settings menu): defaults, ConfigFile round trip, command-line flag
## override for the session only, clamping and rejection of mistyped file values.

var _path := ""


func before_test() -> void:
	_path = create_temp_dir("settings") + "/settings.cfg"


func test_defaults_without_a_file() -> void:
	var s := PlayerSettings.new(_path, [])
	for key: StringName in PlayerSettings.SPEC:
		assert_that(s.get(key)).is_equal(PlayerSettings.SPEC[key][0])
	assert_bool(s.reduced_motion).is_false()
	assert_float(s.master_volume).is_equal(0.8)


func test_save_then_load_round_trips() -> void:
	var s := PlayerSettings.new(_path, [])
	s.set_value(&"reduced_flash", true)
	s.set_value(&"voice_volume", 0.35)
	s.set_value(&"mouse_sensitivity", 0.004)
	assert_int(s.save()).is_equal(OK)
	var t := PlayerSettings.new(_path, [])
	assert_bool(t.reduced_flash).is_true()
	assert_float(t.voice_volume).is_equal_approx(0.35, 1e-6)
	assert_float(t.mouse_sensitivity).is_equal_approx(0.004, 1e-9)


func test_set_value_clamps_to_range() -> void:
	var s := PlayerSettings.new(_path, [])
	s.set_value(&"master_volume", 3.0)
	assert_float(s.master_volume).is_equal(1.0)
	s.set_value(&"hud_scale", 0.1)
	assert_float(s.hud_scale).is_equal(0.75)


func test_set_value_emits_changed() -> void:
	var s := PlayerSettings.new(_path, [])
	var seen: Array = []
	s.changed.connect(func(k: StringName) -> void: seen.append(k))
	s.set_value(&"stick_rate", 4.0)
	assert_array(seen).contains_exactly([&"stick_rate"])


func test_file_values_are_clamped_and_mistyped_ones_ignored() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(PlayerSettings.SECTION, "effects_volume", 9.0)
	cfg.set_value(PlayerSettings.SECTION, "reduced_motion", "yes")
	cfg.set_value(PlayerSettings.SECTION, "stick_rate", 2)
	cfg.save(_path)
	var s := PlayerSettings.new(_path, [])
	assert_float(s.effects_volume).is_equal(1.0)
	assert_bool(s.reduced_motion).is_false()
	assert_float(s.stick_rate).is_equal(2.0)


func test_flag_overrides_for_the_session_but_is_not_saved() -> void:
	var s := PlayerSettings.new(_path, ["--reduced-motion", "--reduced-flash"])
	assert_bool(s.reduced_motion).is_true()
	assert_bool(s.reduced_flash).is_true()
	s.save()
	var t := PlayerSettings.new(_path, [])
	assert_bool(t.reduced_motion).is_false()


func test_changing_a_flagged_setting_saves_the_choice() -> void:
	var s := PlayerSettings.new(_path, ["--reduced-motion"])
	s.set_value(&"reduced_motion", true)
	s.save()
	assert_bool(PlayerSettings.new(_path, []).reduced_motion).is_true()


func test_effective_flash_scale_is_zero_under_reduced_flash() -> void:
	var s := PlayerSettings.new(_path, [])
	s.set_value(&"flash_scale", 0.6)
	assert_float(s.effective_flash_scale()).is_equal_approx(0.6, 1e-6)
	s.set_value(&"reduced_flash", true)
	assert_float(s.effective_flash_scale()).is_zero()


func test_apply_audio_writes_each_bus_in_db() -> void:
	var s := PlayerSettings.new(_path, [])
	s.set_value(&"voice_volume", 0.5)
	var writes := {}
	s.apply_audio(func(bus: StringName, db: float) -> void: writes[bus] = db)
	assert_array(writes.keys()).contains_exactly_in_any_order([&"Master", &"SFX", &"Voice"])
	assert_float(writes[&"Voice"]).is_equal_approx(linear_to_db(0.5), 1e-4)
