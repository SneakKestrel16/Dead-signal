# BUG-0015: the listen host's round end tears its seat RoundClient down cleanly. Real ENet, one host screen and
# three joined client screens in one process, as lobby_to_round_wiring_test.gd (whose knob minimums and forced
# round end this copies). From the round end until everyone is back in Waiting, no screen may log the seat's
# send after its peer closed (`no multiplayer peer is active`, from OwnerPredictor.predict) nor replication
# teardown on the wrong multiplayer (`nonexistent connection`, `tracked_nodes`, `!sync`).
# Ports 31000-31019 (this suite's own range).
extends GdUnitTestSuite

const CLIENTS := 3
const JOIN_S := 5.0
const MARGIN_S := 5.0 ## on top of the knob-defined wait each phase has
const BAD := ["no multiplayer peer is active", "nonexistent connection", "tracked_nodes", "\"!sync\""]

static var _next_port := 31000

var _knobs: Knobs
var _host: LobbyScreen
var _clients: Array[LobbyScreen] = []
var _log: ErrorLog


## Collects every engine and script error message logged while installed.
class ErrorLog extends Logger:
	var lines: PackedStringArray = []

	func _log_error(function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		lines.append("%s: %s %s" % [function, code, rationale])


func before_test() -> void:
	_knobs = Knobs.load_all()
	_knobs.lobby.lobby_countdown_s = 3.0
	_knobs.match_flow.results_duration_s = 10.0
	Engine.physics_ticks_per_second = _knobs.net.sim_tick_hz
	_clients = []
	_host = null
	_log = null


func after_test() -> void:
	if _log != null:
		OS.remove_logger(_log)
	_log = null
	for s: LobbyScreen in [_host] + _clients:
		if is_instance_valid(s):
			s._close("")
	await get_tree().process_frame
	for s: LobbyScreen in [_host] + _clients:
		if is_instance_valid(s):
			s.free()
	_clients.clear()
	_host = null
	await get_tree().process_frame


func _ignore_leave(_tree: SceneTree, _text: String) -> void:
	pass


func _screen(label: String) -> LobbyScreen:
	var s := LobbyScreen.new()
	s.name = label
	s.knobs = _knobs
	s.render_round = false
	s.leave_to = _ignore_leave
	add_child(s)
	s._name.text = label
	return s


func _until(cond: Callable, seconds: float, what: String) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end and not cond.call():
		await get_tree().physics_frame
	assert_bool(cond.call()).override_failure_message("timeout waiting for " + what).is_true()


func _running() -> bool:
	var c: RoundComposer = _host.round_host.composer
	return c != null and c.lifecycle.state() == RoundLifecycle.State.RUNNING


func _back_in_waiting() -> bool:
	return _host._lobby.state() == LobbyState.WAITING and _clients.all(func(c: LobbyScreen) -> bool:
		return not c._in_round and c._state.get("state", "") == "waiting")


func _bad_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	for line in _log.lines:
		if BAD.any(func(b: String) -> bool: return line.contains(b)):
			out.append(line)
	return out


func test_round_end_on_the_host_sends_nothing_after_the_seat_closes_and_tears_replication_down_cleanly() -> void:
	var port := _next_port
	_next_port += 1
	assert_int(port).is_less(31020)
	_host = _screen("Host")
	_host._port.value = port
	_host._on_host()
	for i in CLIENTS:
		var c := _screen("Client%d" % i)
		c._port.value = port
		c._on_join()
		_clients.append(c)
	await _until(func() -> bool: return _host._lobby.player_count() == CLIENTS + 1, JOIN_S, "joins")
	await _until(func() -> bool: return _clients.all(func(c: LobbyScreen) -> bool: return c._room.visible),
			JOIN_S, "client rooms")
	for s: LobbyScreen in [_host] + _clients:
		s._ready_button.button_pressed = true
		s._on_ready_toggled()
	await _until(func() -> bool: return _host.round_host.is_running(), _knobs.lobby.lobby_countdown_s + MARGIN_S,
			"round composed")
	await _until(_running, MARGIN_S, "every map loaded")
	await _until(func() -> bool: return _host.round_client.predictor.states_received > 0, MARGIN_S,
			"the seat predicting")
	_log = ErrorLog.new()
	OS.add_logger(_log)
	var c: RoundComposer = _host.round_host.composer
	for id in c.survivors:
		var e := EvSurvivorEliminated.new()
		e.survivor = id
		_host.round_host.server.bus.emit(e)
	await _until(_back_in_waiting, _knobs.match_flow.results_duration_s + MARGIN_S, "everyone back in Waiting")
	for i in 10: # the freed seat's last frames
		await get_tree().physics_frame
	assert_array(Array(_bad_lines())).is_empty()
