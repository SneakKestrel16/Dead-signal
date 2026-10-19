extends GdUnitTestSuite
## InputBindings and the settings screen's Controls tab (design/accessibility-requirements.md Motor, full input
## remapping): codes round-trip, a rebind replaces only its slot, conflicts are reported, stored bindings apply
## over the defaults and survive a save, and the screen captures the next input (Esc cancels).

var _path := ""


func before_test() -> void:
	_path = create_temp_dir("bindings") + "/settings.cfg"
	InputBindings.reset_all()


func after_test() -> void:
	InputBindings.reset_all() # the InputMap is global: leave the defaults for the next suite


func _key(code: Key) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.pressed = true
	return k


func test_codes_round_trip_and_unbindable_events_have_none() -> void:
	for e: InputEvent in [_key(KEY_F), InputBindings.decode("mouse:4"), InputBindings.decode("joybutton:3"),
			InputBindings.decode("joyaxis:5:1")]:
		assert_str(InputBindings.encode(InputBindings.decode(InputBindings.encode(e)))).is_equal(InputBindings.encode(e))
	var nudge := InputEventJoypadMotion.new()
	nudge.axis_value = 0.1
	assert_str(InputBindings.encode(nudge)).is_empty()
	assert_object(InputBindings.decode("key:x")).is_null()
	assert_object(InputBindings.decode("script:1")).is_null()


func test_a_rebind_replaces_only_its_slot() -> void:
	var pad_before := InputBindings.event_of(&"interact", InputBindings.Slot.PAD)
	InputBindings.bind(&"interact", _key(KEY_F))
	assert_str(InputBindings.encode(InputBindings.event_of(&"interact", InputBindings.Slot.KB))).is_equal("key:%d" % KEY_F)
	assert_object(InputBindings.event_of(&"interact", InputBindings.Slot.PAD)).is_same(pad_before)
	assert_int(InputMap.action_get_events(&"interact").size()).is_equal(2)


func test_a_shared_binding_is_reported_as_a_conflict() -> void:
	var w := InputBindings.event_of(&"move_forward", InputBindings.Slot.KB)
	assert_array(InputBindings.conflicts(&"interact", w)).contains_exactly([&"move_forward"])
	assert_array(InputBindings.conflicts(&"interact", _key(KEY_F12))).is_empty()


func test_stored_bindings_apply_save_and_reset() -> void:
	var s := PlayerSettings.new(_path, [])
	s.set_binding(&"flashlight", _key(KEY_L))
	s.save()
	InputBindings.reset_all()
	var loaded := PlayerSettings.new(_path, [])
	loaded.apply_bindings()
	assert_str(InputBindings.encode(InputBindings.event_of(&"flashlight", InputBindings.Slot.KB))).is_equal("key:%d" % KEY_L)
	loaded.reset_bindings()
	assert_str(InputBindings.encode(InputBindings.event_of(&"flashlight", InputBindings.Slot.KB))) \
			.is_equal(InputBindings.encode(InputBindings.defaults(&"flashlight")[0]))
	assert_dict(loaded.bindings).is_empty()


func test_screen_captures_the_next_key_and_esc_cancels() -> void:
	var settings := PlayerSettings.new(_path, [])
	var screen := SettingsScreen.new(settings, null)
	add_child(screen)
	screen.begin_capture(&"use_item", InputBindings.Slot.KB)
	screen._input(_key(KEY_ESCAPE))
	assert_bool(screen.is_capturing()).is_false()
	assert_str(InputBindings.encode(InputBindings.event_of(&"use_item", InputBindings.Slot.KB))) \
			.is_equal(InputBindings.encode(InputBindings.defaults(&"use_item")[0]))
	screen.begin_capture(&"use_item", InputBindings.Slot.KB)
	screen._input(InputBindings.decode("joybutton:0")) # wrong kind for the slot: still waiting
	assert_bool(screen.is_capturing()).is_true()
	screen._input(_key(KEY_W))
	assert_bool(screen.is_capturing()).is_false()
	assert_str(InputBindings.encode(InputBindings.event_of(&"use_item", InputBindings.Slot.KB))).is_equal("key:%d" % KEY_W)
	assert_str(screen.bind_note.text).contains(InputBindings.label_of(&"move_forward"))
	assert_str((screen.bind_buttons[&"use_item"][0] as Button).text).is_equal(InputGlyphs.event_text(_key(KEY_W)))
	screen.free()


func test_choices_write_their_index_and_the_microphone_its_name() -> void:
	var settings := PlayerSettings.new(_path, [])
	var screen := SettingsScreen.new(settings, null)
	add_child(screen)
	var o := screen.controls[&"window_mode"] as OptionButton
	o.select(2)
	o.item_selected.emit(2)
	assert_int(settings.window_mode).is_equal(2)
	var mic := screen.controls[&"mic_device"] as OptionButton
	mic.item_selected.emit(0)
	assert_str(settings.mic_device).is_equal(mic.get_item_text(0))
	settings.set_value(&"fps_limit", 99) # out of range: refused
	assert_int(settings.fps_limit).is_equal(0)
	screen.free()
