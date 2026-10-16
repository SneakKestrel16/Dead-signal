extends GdUnitTestSuite
## Settings wiring (design/game-brief.md MVP; interaction-patterns.md P15): the lobby's Settings button opens the
## screen under MENU and Back closes it; a change applies live to the round client (apply_settings); an
## overlay or menu context sends no movement (P15). No network.

var _path := ""
var _settings: PlayerSettings
var _knobs: Knobs


func before_test() -> void:
	_path = create_temp_dir("settings_wiring") + "/settings.cfg"
	_settings = PlayerSettings.new(_path, [])
	_knobs = Knobs.load_all()


func after_test() -> void:
	Input.action_release(&"move_forward")


func _lobby() -> LobbyScreen:
	var s: LobbyScreen = auto_free(LobbyScreen.new())
	s.render_round = false
	s.settings = _settings
	add_child(s)
	s._show_room()
	return s


func _settings_button(s: LobbyScreen) -> Button:
	for b in s._room.find_children("*", "Button", true, false):
		if (b as Button).text == "Settings":
			return b
	return null


func test_lobby_button_opens_under_menu_and_back_closes() -> void:
	var s := _lobby()
	_settings_button(s).pressed.emit()
	assert_object(s.settings_view).is_not_null()
	assert_int(s._contexts.top()).is_equal(InputContextStack.Ctx.MENU)
	assert_bool(s.settings_view.round_note.visible).is_false()
	(s.settings_view.controls[&"reduced_motion"] as CheckButton).button_pressed = true
	s.settings_view.back_button.pressed.emit()
	assert_object(s.settings_view).is_null()
	await await_idle_frame()
	assert_bool(PlayerSettings.new(_path, []).reduced_motion).is_true()


func test_form_has_a_settings_button_too() -> void:
	var s: LobbyScreen = auto_free(LobbyScreen.new())
	s.settings = _settings
	add_child(s)
	var found := s._form.find_children("*", "Button", true, false).filter(
			func(b: Node) -> bool: return (b as Button).text == "Settings")
	assert_int(found.size()).is_equal(1)


func test_in_round_without_a_live_hud_does_not_open() -> void:
	var s := _lobby()
	s._in_round = true # Results or a non-rendering round: no GAMEPLAY context to cover
	s.open_settings()
	assert_object(s.settings_view).is_null()


func test_apply_settings_reaches_the_round_client() -> void:
	var c: RoundClient = auto_free(RoundClient.new(_knobs, Callable(), Callable(), MapData.load_map(), false))
	c.input = auto_free(LocalInput.new())
	var writes := {}
	c.scare_audio = auto_free(ScareAudio.new(ScareCatalogue.load_shipped(), _knobs,
			func(bus: StringName, db: float) -> void: writes[bus] = db))
	c.scares = auto_free(ScarePresenter.new(FlashLimiter.new(_knobs.facility.max_flashes_per_s)))
	_settings.set_value(&"reduced_motion", true)
	_settings.set_value(&"camera_flinch", false)
	_settings.set_value(&"mouse_sensitivity", 0.005)
	_settings.set_value(&"stick_rate", 5.0)
	_settings.set_value(&"stinger_volume", 0.5)
	_settings.set_value(&"reduced_flash", true)
	c.apply_settings(_settings)
	assert_bool(c.reduced_motion).is_true()
	assert_bool(c.flinch_enabled).is_false()
	assert_float(c.input.sensitivity).is_equal_approx(0.005, 1e-9)
	assert_float(c.input.stick_rate).is_equal(5.0)
	assert_float(c.scares.flash_scale).is_zero()
	assert_float(writes[&"Stinger"]).is_equal_approx(linear_to_db(0.5), 1e-4)


func test_overlay_sends_no_movement() -> void:
	var li: LocalInput = auto_free(LocalInput.new())
	li.contexts = InputContextStack.new()
	Input.action_press(&"move_forward")
	assert_float(li.sample().move.y).is_greater(0.0)
	li.contexts.push(InputContextStack.Ctx.OVERLAY, null)
	assert_vector(li.sample().move).is_equal(Vector2.ZERO)
	li.contexts.pop(InputContextStack.Ctx.OVERLAY)
	assert_float(li.sample().move.y).is_greater(0.0)
