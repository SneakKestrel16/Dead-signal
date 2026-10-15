# Story match-flow/004: loading barrier, spawn, round end and return to lobby (design/gdd/match-flow.md
# rules 2, 3, 17, 27; lobby-role-assignment.md rule 19). A real LobbyState and RosterHandoff hand the
# roster to a stand-in composition root (_begin), which builds a RoundLifecycle and starts the round on a
# RoundServer kept out of the tree, so only step() advances it. The "map loaded" report is driven
# directly except in the one real-ENet test, which sends it from a client over loopback.
extends GdUnitTestSuite

const SEED := 4004
const SESSION := "s-4"
const VERSION := "test-1.0+mf4"
const WAIT_S := 5.0

static var _next_port := 25700

var _knobs: Knobs
var _lobby: LobbyState
var _handoff: RosterHandoff
var _server: RoundServer
var _lc: RoundLifecycle
var _rounds := 0
var _lobby_tick := 0
var _spawns: Dictionary[int, Vector3] = {}
var _frozen: Array[int] = []
var _over: Array[bool] = []
var _phases: Array[int] = []
var _roots: Array[Node] = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_lobby = LobbyState.new(_knobs)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_handoff = RosterHandoff.new(_lobby, _info, _knobs, rng, SESSION)
	_handoff.handed_off.connect(_begin)
	_server = auto_free(RoundServer.new())
	_rounds = 0
	_lobby_tick = 0


func after_test() -> void:
	if _server != null:
		_server.end_round()
	_lc = null
	for r in _roots:
		for c in r.get_children():
			if c is NetAuthority:
				c.close()
		get_tree().set_multiplayer(null, r.get_path())
		r.free()
	_roots.clear()


## Test stand-in for NetAuthority: token "t<n>" is player n, named "P<n>".
func _info(token: String) -> Dictionary:
	var n := token.trim_prefix("t").to_int()
	return {"player_id": n, "name": "P%d" % n}


## Stand-in composition root at hand-off: a fresh lifecycle per round, hooks recorded.
func _begin(roster: Roster) -> void:
	_rounds += 1
	_spawns = {}
	_frozen = []
	_over = []
	_phases = []
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + _rounds
	_lc = RoundLifecycle.new(roster, MapData.load_map(), rng)
	_lc.spawn = func(id: int, pos: Vector3) -> void: _spawns[id] = pos
	_lc.freeze = func(id: int) -> void: _frozen.append(id)
	_lc.over = _on_over
	var errs := _server.start_round({TickOrder.MATCH_FLOW_BEGIN: _lc,
		TickOrder.MATCH_FLOW_RESOLVE: _lc.resolve_step()}, _knobs)
	assert_array(errs).is_empty()
	_handoff.publish(_server.registry)
	_server.bus.subscribe(&"RoundPhaseChanged", func(e: ServerEvent) -> void:
		_phases.append((e as EvRoundPhaseChanged).phase))


## Stand-in root at round end: tear the round down, return the lobby (Ended advances the rotation).
func _on_over(ended: bool) -> void:
	_over.append(ended)
	_server.end_round()
	_handoff.end_round(ended)


## Joins and readies t1..t<n> (first call only joins) and runs the lobby countdown to the hand-off.
func _lock(n := 5) -> void:
	for i in n:
		var t := "t%d" % (i + 1)
		if not _lobby.tokens().has(t):
			_lobby.join(t)
		_lobby.set_ready(t, true)
	for i in _knobs.ticks(_knobs.lobby.lobby_countdown_s) + 2:
		_lobby_tick += 1
		_lobby.server_tick(_lobby_tick)
	assert_object(_handoff.roster).is_not_null()


func _step() -> int:
	_server.tick_runner.step()
	return _server.tick_runner.current_tick()


func _ids() -> Array[int]:
	return _handoff.roster.player_ids()


func _monster() -> int:
	for id in _ids():
		if _handoff.roster.entry(id).role == Roster.SHAPESHIFTER:
			return id
	return -1


func _marker_pos(id: StringName) -> Vector3:
	for m in MapData.load_map().markers:
		if m.id == id:
			return m.position
	return Vector3.INF


func _timeout_ticks() -> int:
	return _knobs.ticks(_knobs.match_flow.load_timeout_s)


# --- AC-1: loading barrier, then spawn --------------------------------------------

func test_round_waits_for_every_client_then_spawns_and_enters_infiltration() -> void:
	_lock()
	var ids := _ids()
	# Four load early; the last loads so it is seen on load_timeout_s - 1 tick (QA edge case).
	for id in ids.slice(0, 4):
		_lc.report_loaded(id)
	while _server.tick_runner.current_tick() < _timeout_ticks() - 2:
		_step()
	assert_int(_lc.state()).is_equal(RoundLifecycle.State.LOADING)
	assert_dict(_spawns).is_empty()
	assert_array(_phases).is_empty()
	_lc.report_loaded(ids[4])
	_step()
	assert_int(_lc.state()).is_equal(RoundLifecycle.State.RUNNING)
	assert_array(_phases).is_equal([MatchFlow.Phase.INFILTRATION])
	assert_float(_lc.match_flow().elapsed_s()).is_equal(0.0)
	var clock := _server.registry.view(StateKeys.ROUND_CLOCK, MatchFlow.ClockView) as MatchFlow.ClockView
	assert_float(clock.elapsed_s()).is_equal(0.0)
	# Survivors on S1.. in roster order; the shapeshifter on one of M1-M3.
	var survivor_spawns := [&"S1", &"S2", &"S3", &"S4", &"S5"]
	var next := 0
	for id in ids:
		if id == _monster():
			assert_array([&"M1", &"M2", &"M3"]).contains([_lc.spawn_points()[id]])
		else:
			assert_str(String(_lc.spawn_points()[id])).is_equal(String(survivor_spawns[next]))
			next += 1
		assert_vector(_spawns[id]).is_equal(_marker_pos(_lc.spawn_points()[id]))
	assert_int(_spawns.size()).is_equal(5)
	_step()
	assert_float(_lc.match_flow().elapsed_s()).is_equal(1.0 / _knobs.net.sim_tick_hz)
	assert_array(_over).is_empty()


func test_loaded_on_the_timeout_tick_still_starts() -> void:
	_lock()
	var ids := _ids()
	for id in ids.slice(0, 4):
		_lc.report_loaded(id)
	while _server.tick_runner.current_tick() < _timeout_ticks() - 1:
		_step()
	_lc.report_loaded(ids[4])
	assert_int(_step()).is_equal(_timeout_ticks())
	assert_int(_lc.state()).is_equal(RoundLifecycle.State.RUNNING)
	assert_array(_over).is_empty()


func test_reports_from_unknown_players_and_repeats_do_not_count() -> void:
	_lock()
	var ids := _ids()
	for id in ids.slice(0, 4):
		_lc.report_loaded(id)
		_lc.report_loaded(id)
	_lc.report_loaded(999)
	_step()
	assert_int(_lc.state()).is_equal(RoundLifecycle.State.LOADING)
	assert_dict(_spawns).is_empty()


# --- AC-2: load timeout cancels ---------------------------------------------------

func test_a_client_that_never_loads_cancels_at_the_timeout() -> void:
	_lock()
	var queue_before := _handoff.queue_order()
	for id in _ids().slice(0, 4):
		_lc.report_loaded(id)
	while _server.tick_runner.current_tick() < _timeout_ticks() - 1:
		_step()
	assert_array(_over).is_empty()
	var runner := _server.tick_runner
	runner.step()
	assert_int(runner.current_tick()).is_equal(_timeout_ticks())
	assert_array(_over).is_equal([false])
	assert_dict(_spawns).is_empty()
	assert_array(_phases).is_empty()
	assert_int(_lc.state()).is_equal(RoundLifecycle.State.OVER)
	assert_str(_lobby.state()).is_equal(LobbyState.WAITING)
	assert_array(Array(_handoff.queue_order())).is_equal(Array(queue_before))
	assert_object(_server.tick_runner).is_null()


# --- AC-3: round end, Results, return, clean second round -------------------------

func _run_to_end() -> int:
	for id in _ids():
		_lc.report_loaded(id)
	_step()
	var hz := _knobs.net.sim_tick_hz
	var deadline := roundi(_knobs.match_flow.round_duration_s * hz)
	while _lc.state() == RoundLifecycle.State.RUNNING:
		_step()
		assert_bool(_server.tick_runner.current_tick() <= deadline + 2).is_true()
	return _server.tick_runner.current_tick()


func test_round_end_freezes_input_shows_results_then_returns_to_the_lobby() -> void:
	_lock()
	var first_monster := _monster()
	var queue_before := _handoff.queue_order()
	var ended := _run_to_end()
	assert_int(_lc.state()).is_equal(RoundLifecycle.State.RESULTS)
	var sorted_frozen := _frozen.duplicate()
	sorted_frozen.sort()
	var sorted_ids := _ids()
	sorted_ids.sort()
	assert_array(sorted_frozen).is_equal(sorted_ids) # every player frozen on the RoundEnded tick
	var elapsed := _lc.match_flow().elapsed_s()
	var results := _knobs.ticks(_knobs.match_flow.results_duration_s)
	while _server.tick_runner.current_tick() < ended + results - 1:
		_step()
	assert_array(_over).is_empty()
	assert_float(_lc.match_flow().elapsed_s()).is_equal(elapsed) # the clock stopped at RoundEnded
	assert_int(_frozen.size()).is_equal(5) # frozen once, not every Results tick
	var runner := _server.tick_runner
	runner.step()
	assert_int(runner.current_tick()).is_equal(ended + results)
	assert_array(_over).is_equal([true])
	assert_str(_lobby.state()).is_equal(LobbyState.WAITING)
	assert_object(_handoff.roster).is_null()
	var queue_after := _handoff.queue_order()
	assert_str(queue_after[queue_after.size() - 1]).is_equal("t%d" % first_monster)
	assert_array(Array(queue_after)).is_not_equal(Array(queue_before))

	# A second round holds nothing from the first.
	_lock()
	assert_int(_rounds).is_equal(2)
	assert_int(_lc.state()).is_equal(RoundLifecycle.State.LOADING)
	assert_int(_server.tick_runner.current_tick()).is_equal(0)
	assert_dict(_spawns).is_empty()
	assert_array(_frozen).is_empty()
	var clock := _server.registry.view(StateKeys.ROUND_CLOCK, MatchFlow.ClockView) as MatchFlow.ClockView
	assert_float(clock.elapsed_s()).is_equal(0.0)
	assert_int(clock.phase()).is_equal(MatchFlow.Phase.INFILTRATION)
	assert_bool(_lc.match_flow().is_ended()).is_false()
	_step()
	assert_int(_lc.state()).is_equal(RoundLifecycle.State.LOADING) # nobody's earlier report carried over


# --- AC-4 and the client-to-server report over real ENet --------------------------

func _net(lobby: Object) -> NetAuthority:
	var root := Node.new()
	root.name = "Rl%d" % _roots.size()
	get_tree().root.add_child(root)
	var api := SceneMultiplayer.new()
	get_tree().set_multiplayer(api, root.get_path())
	_roots.append(root)
	var net := NetAuthority.new()
	net.setup(_knobs, VERSION, lobby)
	root.add_child(net)
	return net


func _until(cond: Callable, what: String) -> void:
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while Time.get_ticks_msec() < end and not cond.call():
		await get_tree().process_frame
	assert_bool(cond.call()).override_failure_message("timeout waiting for " + what).is_true()


func test_map_loaded_arrives_over_enet_and_host_quitting_in_loading_records_nothing() -> void:
	_next_port += 1
	var port := _next_port
	var server := _net(_lobby)
	assert_int(server.host(port)).is_equal(OK)
	var client := _net(RefCounted.new())
	assert_int(client.join("127.0.0.1", port, "Ann")).is_equal(OK)
	await _until(func() -> bool: return client.local_player_id >= 0 \
		and server.peer_id_of(client.local_player_id) != -1, "join")
	var pid := client.local_player_id
	# The roster: the real client plus three stand-ins (not connected).
	var info := func(t: String) -> Dictionary:
		return {"player_id": pid, "name": "Ann"} if t == "c" else _info(t)
	var roster := Roster.lock(PackedStringArray(["c", "t101", "t102", "t103"]), info, SESSION, 1, _knobs,
		RotationQueue.new(), RandomNumberGenerator.new())
	var rng := RandomNumberGenerator.new()
	_lc = RoundLifecycle.new(roster, MapData.load_map(), rng)
	_lc.over = func(ended: bool) -> void: _over.append(ended)
	_server.start_round({TickOrder.MATCH_FLOW_BEGIN: _lc, TickOrder.MATCH_FLOW_RESOLVE: _lc.resolve_step()}, _knobs)
	var smp := server.multiplayer as SceneMultiplayer
	var lc := _lc
	smp.peer_packet.connect(func(peer: int, bytes: PackedByteArray) -> void:
		if RoundLifecycle.is_map_loaded_packet(bytes):
			lc.report_loaded(server.player_id_of(peer)))
	var csmp := client.multiplayer as SceneMultiplayer
	csmp.send_bytes(RoundLifecycle.map_loaded_packet(), 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE, NetChannels.EVENT)
	await _until(func() -> bool: return lc.loaded_ids().has(pid), "map loaded report")
	assert_array(lc.loaded_ids()).is_equal([pid])
	_step()
	assert_int(lc.state()).is_equal(RoundLifecycle.State.LOADING) # three stand-ins never load
	# The host quits during Loading: the client hears host_left (NA-3 returns it to the boot scene).
	var left := [false]
	client.host_left.connect(func() -> void: left[0] = true)
	server.close()
	await _until(func() -> bool: return left[0], "host_left")
	assert_array(_over).is_empty() # no result, no Cancelled tag, no rotation advance
	assert_array(Array(_handoff.queue_order())).is_empty()
