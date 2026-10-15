extends GdUnitTestSuite
## Story hud-results/009 (design/ux/results.md Entry & Exit Points, R9, AD-31; lobby-role-assignment.md UI
## Requirements; ADR-0014 §1, §5): the lobby's Last round button reopens the stored RoundEnded payload in
## the Results screen with no countdown; Back (button or Esc) closes it and focus returns to the button.
## The button is absent before any round and once the session closes (the host left). No network: the round
## end is the lobby's own _show_results over a MatchDisplay holding a fixture payload.

const Fx := preload("res://tests/unit/hud-results/results_fixtures.gd")

var _left: Array[String] = []


func _record_leave(_tree: SceneTree, text: String) -> void:
	_left.append(text)


func _lobby() -> LobbyScreen:
	var s: LobbyScreen = auto_free(LobbyScreen.new())
	s.render_round = false
	s.leave_to = _record_leave
	add_child(s)
	s._show_room()
	return s


## The lobby as after a round: RoundEnded showed the live Results screen, the round dropped, the room shows.
func _after_round(s: LobbyScreen, payload: Dictionary) -> void:
	s._display = MatchDisplay.new(s._knobs)
	s._display._results = payload
	s._show_results()
	s._drop_round()
	s._show_room()


func test_button_absent_before_any_round() -> void:
	var s := _lobby()

	assert_bool(s._last_round_button.visible).is_false()


func test_button_opens_the_stored_payload_with_no_countdown() -> void:
	var s := _lobby()
	_after_round(s, Fx.shapeshifter_win())
	assert_bool(s._last_round_button.is_visible_in_tree()).is_true()
	assert_str(s._last_round_button.text).is_equal("Last round")

	s._last_round_button.pressed.emit()
	await await_idle_frame()

	var v := s._last_round_view
	assert_object(v).is_not_null()
	assert_str(v.outcome_label.text).is_equal("SHAPESHIFTER WINS")
	assert_str(v.title_label.text).is_equal("Last round")
	assert_bool(v.countdown.visible).is_false()
	assert_object(v.leave_button).is_null() # R9 replaces R7 and R8
	assert_object(v.focus_stops.back()).is_same(v.back_button)
	assert_object(get_viewport().gui_get_focus_owner()).is_same(v.back_button) # initial focus on R9
	assert_int(s._contexts.top()).is_equal(InputContextStack.Ctx.MENU)
	assert_int(s._contexts._stack.size()).is_equal(2)
	v._process(30.0) # no countdown: nothing closes it
	assert_bool(is_instance_valid(v) and v.is_inside_tree()).is_true()


func test_back_closes_to_the_lobby_with_focus_on_the_button() -> void:
	var s := _lobby()
	_after_round(s, Fx.survivors_win())
	s._last_round_button.grab_focus()
	s._last_round_button.pressed.emit()
	await await_idle_frame()

	s._last_round_view.back_button.pressed.emit()
	await await_idle_frame()

	assert_object(s._last_round_view).is_null()
	assert_int(s._contexts._stack.size()).is_equal(1)
	assert_object(get_viewport().gui_get_focus_owner()).is_same(s._last_round_button)


func test_escape_closes_the_view() -> void:
	var s := _lobby()
	_after_round(s, Fx.survivors_win())
	s._last_round_button.grab_focus()
	s._last_round_button.pressed.emit()
	await await_idle_frame()
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true

	s._last_round_view._unhandled_input(esc)
	await await_idle_frame()

	assert_object(s._last_round_view).is_null()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(s._last_round_button)


func test_button_absent_after_host_leaves() -> void:
	var s := _lobby()
	_after_round(s, Fx.survivors_win())
	s._last_round_button.pressed.emit()
	await await_idle_frame()

	s._on_host_left()
	await await_idle_frame()

	assert_array(_left).is_equal(["Host left"])
	assert_object(s._last_round_view).is_null()
	assert_int(s._contexts._stack.size()).is_equal(1)
	s._show_room() # a later session in the same screen starts without a last round
	assert_bool(s._last_round_button.visible).is_false()


func test_a_new_round_closes_the_open_view() -> void:
	var s := _lobby()
	_after_round(s, Fx.survivors_win())
	s._last_round_button.pressed.emit()
	await await_idle_frame()

	s._close_last_round()
	await await_idle_frame()

	assert_object(s._last_round_view).is_null()
	assert_int(s._contexts._stack.size()).is_equal(1)
