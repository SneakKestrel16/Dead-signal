extends GdUnitTestSuite
## Story hud-results/008 (design/ux/results.md R1-R8, States, Interaction Map, Accessibility; ADR-0014 §1, §5,
## §9; ADR-0011 §4): the RoundEnded payload mapped to the screen's text field for field, a `missing` owner
## shown as "Results unavailable" (never 0), "Unknown player", the payload error state, the focus order,
## the MENU / MODAL contexts and the countdown.

const Fx := preload("res://tests/unit/hud-results/results_fixtures.gd")
const UNAVAILABLE := "Results unavailable"
const DURATION_S := 20.0

var _contexts: InputContextStack


func before_test() -> void:
	_contexts = InputContextStack.new()
	_contexts.viewport = get_viewport()


func _screen(payload: Dictionary, duration_s: float = DURATION_S) -> ResultsScreen:
	var s: ResultsScreen = auto_free(ResultsScreen.new(payload, duration_s, _contexts))
	add_child(s)
	return s


func test_survivors_win_maps_every_field() -> void:
	# Act: through the wire encoding, as a client receives it
	var v := ResultsScreen.present(bytes_to_var(var_to_bytes(Fx.survivors_win())))

	# Assert
	assert_str(v.outcome).is_equal("SURVIVORS WIN")
	assert_str(v.reason).is_equal("Evidence escaped  ·  8:12")
	assert_str(v.outcome_a11y).is_equal("Survivors win. Evidence escaped at 8 minutes 12")
	assert_bool(v.survivors_ok).is_true()
	var rows: Array = v.survivors
	assert_array(rows.map(func(r: Dictionary) -> Array: return [r.name, r.fate, r.phrase, r.detail])).is_equal([
		["Ana", "Escaped", "(2 drives)", "downs 1 · rescues 2 · stuns 1"],
		["Ben", "Eliminated", "(Bled out)", "downs 2 · rescues 0 · stuns 0"],
		["Cy", "Did not escape", "", "downs 0 · rescues 1 · stuns 1"],
		["Dee", "Disconnected", "", "downs 1 · rescues 0 · stuns 0"]])
	assert_array(rows.map(func(r: Dictionary) -> String: return r.a11y)).is_equal([
		"Ana, escaped with 2 drives, 1 down, 2 rescues, 1 stun landed",
		"Ben, eliminated, bled out, 2 downs, 0 rescues, 0 stuns landed",
		"Cy, did not escape, 0 downs, 1 rescue, 1 stun landed",
		"Dee, disconnected, 1 down, 0 rescues, 0 stuns landed"])
	assert_str(v.shapeshifter).is_equal("Shapeshifter: Eli")
	assert_bool(v.objectives_ok).is_true()
	assert_array((v.objectives as Array).map(func(o: Dictionary) -> Array: return [o.label, o.count, o.time])) \
		.is_equal([["Drives recovered", "2/2", "3:40"], ["Drives docked", "2/2", "5:55"],
			["Fuses installed", "2/2", "6:30"], ["Evacuation active", "Yes", "7:44"], ["Drives extracted", "2/2", "8:12"]])
	assert_bool(v.stats_ok).is_true()
	assert_array(v.stats).is_equal(["Match 8:12", "Takedowns 3", "Eliminations 1", "Lunges landed 4",
		"Lunges missed 3", "Lunges interrupted 1", "Stunned 2", "Form changes 5", "False Signals 3", "Blackouts 1",
		"Survivor stuns landed 2", "Rescues 3"])
	assert_array(v.errors).is_empty()


func test_shapeshifter_win_shows_dash_and_no_for_unfinished_objectives() -> void:
	var v := ResultsScreen.present(Fx.shapeshifter_win())

	assert_str(v.outcome).is_equal("SHAPESHIFTER WINS")
	assert_str(v.reason).is_equal("Evacuation deadline expired  ·  9:00")
	assert_str((v.survivors as Array)[1].phrase).is_equal("(Taken down)")
	assert_array((v.objectives as Array).map(func(o: Dictionary) -> Array: return [o.count, o.time])).is_equal([
		["1/2", "5:02"], ["1/2", "7:46"], ["0/2", "—"], ["No", "—"], ["0/2", "—"]])


func test_escaped_without_drives_has_no_drive_phrase_and_forfeit_names_disconnect() -> void:
	var p := Fx.survivors_win()
	p.survivors[0].drives_carried = 0
	p.reason = MatchFlow.Reason.FORFEIT

	var v := ResultsScreen.present(p)

	assert_str((v.survivors as Array)[0].phrase).is_equal("")
	assert_str((v.survivors as Array)[0].a11y).is_equal("Ana, escaped, 1 down, 2 rescues, 1 stun landed")
	assert_str(v.outcome).is_equal("SURVIVORS WIN")
	assert_str(v.shapeshifter).is_equal("Shapeshifter: Eli (disconnected)")
	assert_str(v.shapeshifter_a11y).is_equal("Shapeshifter: Eli, disconnected, forfeited")


func test_missing_defense_shows_unavailable_never_zero() -> void:
	var v := ResultsScreen.present(Fx.defense_missing())

	for r: Dictionary in v.survivors:
		assert_str(r.detail).ends_with("stuns " + UNAVAILABLE)
		assert_str(r.a11y).ends_with("stuns landed: " + UNAVAILABLE)
	assert_array(v.stats).contains(["Stunned " + UNAVAILABLE, "Survivor stuns landed " + UNAVAILABLE,
		"Takedowns 3", "Rescues 3"])
	assert_array(v.errors).is_empty()


func test_missing_objectives_hides_the_zone_and_the_drive_count() -> void:
	var p := Fx.survivors_win()
	p.missing = [StateKeys.STATS_OBJECTIVES]

	var v := ResultsScreen.present(p)

	assert_bool(v.objectives_ok).is_false()
	assert_str((v.survivors as Array)[0].phrase).is_equal("(drives: %s)" % UNAVAILABLE)


func test_empty_names_show_unknown() -> void:
	var p := Fx.survivors_win()
	p.survivors[2].name = ""
	p.shapeshifter_name = ""

	var v := ResultsScreen.present(p)

	assert_str((v.survivors as Array)[2].name).is_equal("Unknown player")
	assert_str(v.shapeshifter).is_equal("Shapeshifter: unknown")


func test_corrupted_fields_mark_only_their_zone() -> void:
	var p := Fx.survivors_win()
	p.survivors[1].downs = "two"
	p.monster[&"blackouts"] = -1
	p.outcome = 7

	var v := ResultsScreen.present(p)

	assert_str(v.outcome).is_equal(UNAVAILABLE)
	assert_str(v.reason).is_equal("Evidence escaped  ·  8:12")
	assert_bool(v.survivors_ok).is_false()
	assert_bool(v.stats_ok).is_false()
	assert_bool(v.objectives_ok).is_true()
	assert_array(v.errors).contains(["outcome", "survivors[1]", "monster.blackouts"])


func test_empty_payload_builds_the_error_screen_without_crashing() -> void:
	var s := _screen({"survivors": "garbage", "objectives": 3, "monster": null, "missing": 9})

	assert_str(s.outcome_label.text).is_equal(UNAVAILABLE)
	assert_int(s.focus_stops.size()).is_equal(5) # outcome, R4, objectives, stats, Leave
	assert_str(s.countdown.text).is_equal("Returning to lobby in 20")


func test_focus_stops_follow_the_spec_order_with_names_and_no_initial_focus() -> void:
	var s := _screen(Fx.survivors_win())
	await await_idle_frame()

	assert_object(get_viewport().gui_get_focus_owner()).is_null()
	assert_int(s.focus_stops.size()).is_equal(9) # outcome, 4 rows, R4, objectives, stats, Leave
	assert_object(s.focus_stops[8]).is_same(s.leave_button)
	assert_str(s.focus_stops[1].accessibility_name).is_equal("Ana, escaped with 2 drives, 1 down, 2 rescues, 1 stun landed")
	for i in s.focus_stops.size():
		var c := s.focus_stops[i]
		assert_int(c.focus_mode).is_equal(Control.FOCUS_ALL)
		assert_str(c.accessibility_name).is_not_empty()
		if i + 1 < s.focus_stops.size():
			assert_object(c.get_node(c.focus_neighbor_bottom)).is_same(s.focus_stops[i + 1])
			assert_object(c.find_next_valid_focus()).is_same(s.focus_stops[i + 1])
			assert_object(s.focus_stops[i + 1].get_node(s.focus_stops[i + 1].focus_neighbor_top)).is_same(c)


func test_menu_pushed_on_show_and_popped_on_hide() -> void:
	var s := _screen(Fx.survivors_win())
	assert_int(_contexts.top()).is_equal(InputContextStack.Ctx.MENU)

	remove_child(s)

	assert_int(_contexts.top()).is_equal(InputContextStack.Ctx.GAMEPLAY)


func test_leave_opens_the_confirm_on_stay_and_the_countdown_closes_it() -> void:
	var s := _screen(Fx.survivors_win())
	var left := [0]
	s.leave_confirmed.connect(func() -> void: left[0] += 1)

	s.leave_button.pressed.emit()
	await await_idle_frame()

	assert_bool(s.confirm.visible).is_true()
	assert_int(_contexts.top()).is_equal(InputContextStack.Ctx.MODAL)
	assert_object(s.confirm.gui_get_focus_owner()).is_same(s.confirm.get_cancel_button()) # the dialog is its own Window
	s._process(5.0)
	assert_str(s.countdown.text).is_equal("Returning to lobby in 15")
	assert_str(s.leave_button.accessibility_name).is_equal("Leave session, returning to lobby in 15 seconds")
	s._process(15.0)
	assert_bool(s.confirm.visible).is_false()
	assert_int(_contexts.top()).is_equal(InputContextStack.Ctx.MENU)
	assert_int(left[0]).is_equal(0)


func test_confirming_leave_emits_once() -> void:
	var s := _screen(Fx.survivors_win())
	var left := [0]
	s.leave_confirmed.connect(func() -> void: left[0] += 1)
	s.leave_button.pressed.emit()

	s.confirm.get_ok_button().pressed.emit()

	assert_int(left[0]).is_equal(1)
	assert_int(_contexts.top()).is_equal(InputContextStack.Ctx.MENU)


func test_missing_knob_hides_the_countdown() -> void:
	var s := _screen(Fx.survivors_win(), NAN)
	s._process(1.0)
	assert_bool(s.countdown.visible).is_false()


func test_every_label_is_at_least_menu_size() -> void:
	var s := _screen(Fx.survivors_win())
	for l: Label in s.find_children("*", "Label", true, false):
		assert_int(l.get_theme_font_size(&"font_size")).is_greater_equal(ResultsScreen.BODY_PX)
	assert_int(s.outcome_label.get_theme_font_size(&"font_size")).is_greater_equal(48)
