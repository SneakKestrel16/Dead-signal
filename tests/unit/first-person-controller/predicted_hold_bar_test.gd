# Story controller-interaction/016: predicted hold bar (ADR-0008 §8; first-person-controller.md
# Acceptance Criteria, Feel). The owner's bar appears on the press tick when the local target query
# found a target, cancels when the acknowledging snapshot shows no hold, otherwise follows the server.
# Latency is simulated by withholding snapshots: 150 ms at 60 Hz is 9 ticks each way.
extends GdUnitTestSuite

const DURATION_S := 2.0
const NET_ID := 7
const LATENCY_MS := 150.0

var _knobs: Knobs
var _bar: PredictedHoldBar
var _seq := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_bar = auto_free(PredictedHoldBar.new())
	_bar.setup(_knobs)
	_seq = 0


func _frame(interact: bool, target: int = NET_ID, is_body: bool = false) -> InputFrame:
	_seq += 1
	var f := InputFrame.new()
	f.seq = _seq
	f.interact = interact
	f.interact_target = target
	f.target_is_body = is_body
	return f


func _own(seq: int, hold_net_id: int, elapsed: int) -> Dictionary:
	return {"own": true, "seq": seq, "hold_net_id": hold_net_id, "hold_elapsed_ticks": elapsed}


func _latency_ticks() -> int:
	return ceili(LATENCY_MS / 1000.0 * _knobs.net.sim_tick_hz)


func _duration_ticks() -> int:
	return _knobs.ticks(DURATION_S)


func test_bar_appears_on_the_press_tick_under_150ms_latency() -> void:
	_bar.advance(_frame(false), true, DURATION_S)
	assert_bool(_bar.visible).is_false()
	_bar.advance(_frame(true), true, DURATION_S)
	# The press tick itself: no snapshot has arrived, so the bar cannot have waited for one.
	assert_bool(_bar.visible).is_true()
	assert_float(_bar.value).is_equal_approx(1.0 / _duration_ticks(), 1e-6)
	var ms_per_tick := 1000.0 / _knobs.net.sim_tick_hz
	assert_float(ms_per_tick).is_less_equal(100.0) ## AC: <= 100 ms after the press
	for i in _latency_ticks() * 2: ## round trip with no snapshot: the bar keeps predicting
		_bar.advance(_frame(true), true, DURATION_S)
	assert_bool(_bar.visible).is_true()
	assert_float(_bar.value).is_equal_approx((1.0 + _latency_ticks() * 2) / _duration_ticks(), 1e-6)


func test_bar_needs_a_local_target() -> void:
	_bar.advance(_frame(true), false, DURATION_S)
	assert_bool(_bar.visible).is_false()


func test_instant_interaction_shows_no_bar() -> void:
	_bar.advance(_frame(true), true, 0.0)
	assert_bool(_bar.visible).is_false()


func test_rejected_start_cancels_at_the_ack_without_progress_flash() -> void:
	var press := _frame(true)
	_bar.advance(press, true, DURATION_S)
	var shown: Array[float] = []
	for i in _latency_ticks() * 2:
		_bar.advance(_frame(true), true, DURATION_S)
		shown.append(_bar.value)
		# Snapshots from before the press reached the server say nothing about it.
		_bar.on_snapshot(_own(press.seq - 1, -1, 0))
		assert_bool(_bar.visible).is_true()
	var predicted: float = _bar.value
	_bar.on_snapshot(_own(press.seq + 1, -1, 0))
	assert_bool(_bar.visible).is_false()
	assert_float(_bar.value).is_less_equal(predicted)
	for v in shown:
		assert_float(v).is_less_equal(predicted)


## AD-217: a press names a map index; the server's hold carries a net id that differs from it (a hiding
## spot's Hide or Search). Any hold at the ack is this press's (a press ends the old hold).
func test_map_index_press_follows_a_hold_whose_net_id_differs() -> void:
	var press := _frame(true, 3)
	_bar.advance(press, true, DURATION_S)
	_bar.on_snapshot(_own(press.seq, 42, 1))
	assert_bool(_bar.visible).is_true()


func test_accepted_start_follows_the_server_plus_unacked_ticks() -> void:
	var press := _frame(true)
	_bar.advance(press, true, DURATION_S)
	for i in 10:
		_bar.advance(_frame(true), true, DURATION_S)
	# Server acked press.seq + 2 with 30 ticks elapsed (stored progress); 8 frames since are unacked.
	_bar.on_snapshot(_own(press.seq + 2, NET_ID, 30))
	assert_bool(_bar.visible).is_true()
	assert_float(_bar.value).is_equal_approx(38.0 / _duration_ticks(), 1e-6)
	_bar.advance(_frame(true), true, DURATION_S)
	assert_float(_bar.value).is_equal_approx(39.0 / _duration_ticks(), 1e-6)


func test_body_target_accepts_any_held_net_id() -> void:
	var press := _frame(true, 3, true) ## a handle, not a net id: the server resolves it
	_bar.advance(press, true, DURATION_S)
	_bar.on_snapshot(_own(press.seq, 42, 1))
	assert_bool(_bar.visible).is_true()


func test_release_hides_at_once_and_server_end_hides_later() -> void:
	var press := _frame(true)
	_bar.advance(press, true, DURATION_S)
	_bar.advance(_frame(false), true, DURATION_S)
	assert_bool(_bar.visible).is_false()
	press = _frame(true)
	_bar.advance(press, true, DURATION_S)
	_bar.on_snapshot(_own(press.seq, NET_ID, 1))
	_bar.on_snapshot(_own(press.seq + 5, -1, 0)) ## completed or cancelled by the server
	assert_bool(_bar.visible).is_false()


func test_held_key_without_new_press_does_not_restart() -> void:
	var press := _frame(true)
	_bar.advance(press, true, DURATION_S)
	_bar.on_snapshot(_own(press.seq, -1, 0))
	_bar.advance(_frame(true), true, DURATION_S)
	assert_bool(_bar.visible).is_false()


func test_bar_ignores_the_mouse() -> void:
	assert_int(_bar.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
