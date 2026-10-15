# Story match-flow/013 (TR-match-001, TR-lobby-007; ADR-0001 Â§1, Â§7): the shipped lobby screen starts the
# composed round and takes it back. Real ENet, one host screen and three joined client screens in one process
# (each screen is its own multiplayer root): the countdown locks the roster, the host's RoundHost composes the
# round over it, every client adopts the lobby session for the round scene (no second session) and reports its
# map loaded (AC-1); after Results everyone is back in Waiting on the same session, Ready cleared, the
# shapeshifter moved to the back of the queue (AC-2); a cancelled round (a client dropped while Loading) does
# not advance the queue, and a host that quits mid-round sends every client to "Host left" (AC-3).
# Knobs: lobby_countdown_s, results_duration_s and load_timeout_s at their range minimum (3 s, 10 s, 30 s) so
# the waits stay bounded; the round end is forced with SurvivorEliminated on the server bus (round_duration_s
# cannot go under 420 s), as tests/manual/round_host.gd --force does.
extends GdUnitTestSuite

const CLIENTS := 3
const JOIN_S := 5.0
const MARGIN_S := 5.0 ## on top of the knob-defined wait each phase has

static var _next_port := 31100

var _knobs: Knobs
var _host: LobbyScreen
var _clients: Array[LobbyScreen] = []
var _left: Array[String] = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_knobs.lobby.lobby_countdown_s = 3.0
	_knobs.match_flow.results_duration_s = 10.0
	_knobs.match_flow.load_timeout_s = 30.0
	Engine.physics_ticks_per_second = _knobs.net.sim_tick_hz
	_left = []
	_clients = []
	_host = null


func after_test() -> void:
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


func _record_leave(_tree: SceneTree, text: String) -> void:
	_left.append(text)


func _screen(label: String) -> LobbyScreen:
	var s := LobbyScreen.new()
	s.name = label
	s.knobs = _knobs
	s.render_round = false
	s.leave_to = _record_leave
	add_child(s)
	s._name.text = label
	return s


func _until(cond: Callable, seconds: float, what: String) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end and not cond.call():
		await get_tree().physics_frame
	assert_bool(cond.call()).override_failure_message("timeout waiting for " + what).is_true()


## Host plus CLIENTS joined clients, everyone Ready; returns once the host's round runs and every player
## (the host's seat too) reported its map loaded. `drop_one`: the last client drops as soon as the round is
## composed instead, so Loading never completes; returns while Loading.
func _to_running_round(drop_one := false) -> void:
	var port := _next_port
	_next_port += 1
	assert_int(port).is_less(31200)
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
	if drop_one:
		var gone: LobbyScreen = _clients.pop_back()
		gone.free()
		return
	await _until(_running, MARGIN_S, "every map loaded")


func _running() -> bool:
	var c: RoundComposer = _host.round_host.composer
	return c != null and c.lifecycle.state() == RoundLifecycle.State.RUNNING


func _waiting() -> bool:
	return _host._lobby.state() == LobbyState.WAITING


func _clients_waiting() -> bool:
	return _clients.all(func(c: LobbyScreen) -> bool:
		return is_instance_valid(c) and not c._in_round and c._state.get("state", "") == "waiting")


func test_countdown_starts_the_composed_round_on_every_client_over_the_lobby_session() -> void:
	await _to_running_round()
	var c: RoundComposer = _host.round_host.composer
	assert_int(c.roster.player_count()).is_equal(CLIENTS + 1)
	var ids := c.roster.player_ids()
	ids.sort()
	assert_array(c.lifecycle.loaded_ids()).is_equal(ids) # every player, the host's seat included
	for s in _clients:
		assert_bool(s._in_round).is_true()
		assert_bool(s.round_client.is_ready()).is_true()
		assert_object(s.round_client.net).is_same(s._net) # the lobby's session, no second ENet session
	assert_int(_host._net.peer_id_of(_host._net.local_player_id)).is_not_equal(-1) # the seat is a peer


func test_results_return_everyone_to_waiting_on_the_same_session_with_the_queue_advanced() -> void:
	await _to_running_round()
	var c: RoundComposer = _host.round_host.composer
	var ids_before: Array[int] = []
	for s in _clients:
		ids_before.append(s._net.local_player_id)
	var queue: PackedStringArray = _host._handoff.queue_order()
	var picked: String = _host._net.token_of(c.monster)
	for id in c.survivors:
		var e := EvSurvivorEliminated.new()
		e.survivor = id
		_host.round_host.server.bus.emit(e)
	await _until(_waiting, _knobs.match_flow.results_duration_s + MARGIN_S, "Results to end")
	await _until(_clients_waiting, MARGIN_S, "clients back in the room")
	var expected := Array(queue)
	expected.erase(picked)
	expected.append(picked)
	assert_array(Array(_host._handoff.queue_order())).is_equal(expected) # Ended: the shapeshifter to the back
	assert_int(_host._lobby.player_count()).is_equal(CLIENTS + 1) # the host's seat leaving is no lobby leave
	for t in _host._lobby.tokens():
		assert_bool(_host._lobby.is_ready(t)).is_false()
	for i in _clients.size():
		var s := _clients[i]
		assert_int(s._net.local_player_id).is_equal(ids_before[i]) # same session, no re-join
		assert_int(s.multiplayer.multiplayer_peer.get_connection_status()) \
				.is_equal(MultiplayerPeer.CONNECTION_CONNECTED)
		assert_bool(s._room.visible).is_true()
		assert_bool(s.round_client.is_ready()).is_false() # a fresh round scene waits for the next round
	assert_object(_host.round_client).is_null()
	assert_array(_left).is_empty()


func test_load_timeout_cancels_back_to_the_lobby_without_advancing_the_queue() -> void:
	await _to_running_round(true)
	var queue: PackedStringArray = _host._handoff.queue_order()
	await _until(_waiting, _knobs.match_flow.load_timeout_s + MARGIN_S, "load timeout")
	await _until(_clients_waiting, MARGIN_S, "clients back in the room")
	assert_array(Array(_host._handoff.queue_order())).is_equal(Array(queue)) # Cancelled: not advanced
	assert_int(_host._lobby.player_count()).is_equal(CLIENTS) # the dropped client left; the host stays


func test_host_quitting_mid_round_sends_every_client_to_host_left() -> void:
	await _to_running_round()
	_host._on_leave()
	await _until(func() -> bool: return _left.size() == CLIENTS, MARGIN_S, "Host left on every client")
	for text in _left:
		assert_str(text).is_equal("Host left")
