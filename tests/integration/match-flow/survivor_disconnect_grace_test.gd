# Story match-flow/005: survivor disconnect, grace and reconnect (design/gdd/match-flow.md rules 13, 19,
# 21, 22, Edge Cases). A RoundLifecycle runs on a RoundServer kept out of the tree, so only step() advances
# it. Network Authority's ConnectionRouter is stood in for by emitting PlayerConnectionChanged
# (DISCONNECTED / RECONNECTED) between steps, as the router does from NetAuthority signals; Downing is
# stood in for by emitting SurvivorDowned / SurvivorEliminated (story Implementation Notes). The last test
# runs the real router over ENet on loopback: no rejoin is accepted once Match Flow has expired the grace.
extends GdUnitTestSuite

const SEED := 5005
const SESSION := "s-5"
const VERSION := "test-1.0+mf5"
const WAIT_S := 5.0
const TOKENS: Array[String] = ["t1", "t2", "t3", "t4", "t5"]
const FILLER_TOKENS: Array[String] = ["f1", "f2", "f3", "f4", "f5"]

static var _next_port := 25800

var _knobs: Knobs
var _server: RoundServer
var _lc: RoundLifecycle
var _spawns: Dictionary[int, Vector3] = {}
var _removed: Array[int] = []
## player id -> where its body stands when removed (the composition root's answer to `remove`).
var _body_at: Dictionary[int, Vector3] = {}
var _conn_events: Array[EvPlayerConnectionChanged] = []
var _ended: Array[EvRoundEnded] = []
var _roots: Array[Node] = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_server = auto_free(RoundServer.new())
	_spawns = {}
	_removed = []
	_body_at = {}
	_conn_events = []
	_ended = []


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


func _info(token: String) -> Dictionary:
	var n := token.trim_prefix("t").to_int()
	return {"player_id": n, "name": "P%d" % n}


func _on_spawn(id: int, pos: Vector3) -> void:
	_spawns[id] = pos


func _on_remove(id: int) -> Vector3:
	_removed.append(id)
	return _body_at.get(id, Vector3.ZERO)


func _on_conn(e: ServerEvent) -> void:
	_conn_events.append(e as EvPlayerConnectionChanged)


func _on_ended(e: ServerEvent) -> void:
	_ended.append(e as EvRoundEnded)


## A five-player round past its loading barrier (Running).
func _start() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var roster := Roster.lock(PackedStringArray(TOKENS), _info, SESSION, 1, _knobs, RotationQueue.new(), rng)
	_lc = RoundLifecycle.new(roster, MapData.load_map(), rng)
	_lc.spawn = _on_spawn
	_lc.remove = _on_remove
	var errs := _server.start_round({TickOrder.MATCH_FLOW_BEGIN: _lc,
		TickOrder.MATCH_FLOW_RESOLVE: _lc.resolve_step()}, _knobs)
	assert_array(errs).is_empty()
	_server.bus.subscribe(&"PlayerConnectionChanged", _on_conn)
	_server.bus.subscribe(&"RoundEnded", _on_ended)
	for id in roster.player_ids():
		_lc.report_loaded(id)
	_step()
	assert_int(_lc.state()).is_equal(RoundLifecycle.State.RUNNING)
	_spawns = {}


func _survivors() -> Array[int]:
	return _lc.match_flow().survivor_ids


func _step() -> int:
	_server.tick_runner.step()
	return _server.tick_runner.current_tick()


func _now() -> int:
	return _server.tick_runner.current_tick()


## Emits `events` between steps (as the router and Downing would), then runs one tick.
func _tick(events: Array[ServerEvent] = []) -> int:
	for e in events:
		_server.bus.emit(e)
	return _step()


func _conn(id: int, status: int) -> EvPlayerConnectionChanged:
	var e := EvPlayerConnectionChanged.new()
	e.player = id
	e.status = status
	return e


func _elim(id: int) -> EvSurvivorEliminated:
	var e := EvSurvivorEliminated.new()
	e.survivor = id
	return e


func _down(id: int) -> EvSurvivorDowned:
	var e := EvSurvivorDowned.new()
	e.survivor = id
	return e


func _grace_ticks() -> int:
	return _knobs.ticks(_knobs.match_flow.reconnect_grace_s)


func _statuses(id: int) -> Array[int]:
	var out: Array[int] = []
	for e in _conn_events:
		if e.player == id:
			out.append(e.status)
	return out


# --- AC-1 / AC-2: removal on disconnect, same place and state on reconnect ------------------------

func test_disconnect_removes_the_body_and_a_reconnect_in_grace_respawns_it_where_it_stood() -> void:
	_start()
	var s := _survivors()[0]
	_body_at[s] = Vector3(4.0, 0.0, -7.5)
	_tick([_conn(s, EvPlayerConnectionChanged.DISCONNECTED)])
	assert_array(_removed).is_equal([s])
	assert_dict(_spawns).is_empty()
	_body_at[s] = Vector3.INF # the body is gone; the respawn must use the remembered spot
	while _now() < _grace_ticks() - 1:
		_step()
	_tick([_conn(s, EvPlayerConnectionChanged.RECONNECTED)])
	assert_vector(_spawns[s]).is_equal(Vector3(4.0, 0.0, -7.5))
	assert_int(_lc.match_flow().status_of(s)).is_equal(MatchFlow.Status.HEALTHY)
	_step_by(_grace_ticks())
	assert_array(_statuses(s)).is_equal([EvPlayerConnectionChanged.DISCONNECTED,
		EvPlayerConnectionChanged.RECONNECTED]) # a returned player's grace never expires
	assert_array(_ended).is_empty()


func test_a_downed_survivor_reconnects_downed() -> void:
	_start()
	var s := _survivors()[1]
	_tick([_down(s)])
	_tick([_conn(s, EvPlayerConnectionChanged.DISCONNECTED)])
	_tick([_conn(s, EvPlayerConnectionChanged.RECONNECTED)])
	assert_int(_lc.match_flow().status_of(s)).is_equal(MatchFlow.Status.DOWNED)
	assert_bool(_spawns.has(s)).is_true()


# --- AC-2: grace expiry -----------------------------------------------------------------------------

func test_staying_away_reconnect_grace_s_counts_as_eliminated_and_lists_disconnected() -> void:
	_start()
	var ids := _survivors()
	var s := ids[0]
	var others: Array[ServerEvent] = []
	for id in ids.slice(1):
		others.append(_elim(id))
	_tick(others)
	var dropped_at := _now() # the router stamps the drop with the current tick
	_tick([_conn(s, EvPlayerConnectionChanged.DISCONNECTED)])
	while _now() < dropped_at + _grace_ticks() - 1:
		_step()
	assert_array(_ended).is_empty() # in grace: counts as inside (rule 13)
	assert_array(_statuses(s)).is_equal([EvPlayerConnectionChanged.DISCONNECTED])
	var t := _step()
	assert_int(t).is_equal(dropped_at + _grace_ticks())
	assert_array(_statuses(s)).is_equal([EvPlayerConnectionChanged.DISCONNECTED,
		EvPlayerConnectionChanged.GRACE_EXPIRED])
	assert_int(_lc.match_flow().status_of(s)).is_equal(MatchFlow.Status.DISCONNECTED)
	assert_int(_ended.size()).is_equal(1) # rule 12 at the moment grace expires
	assert_int(_ended[0].reason).is_equal(MatchFlow.Reason.ALL_ELIMINATED)
	assert_int(_ended[0].tick).is_equal(t)


func test_no_reconnect_is_accepted_after_grace_expires() -> void:
	_start()
	var s := _survivors()[0]
	_tick([_conn(s, EvPlayerConnectionChanged.DISCONNECTED)])
	_step_by(_grace_ticks())
	assert_int(_lc.match_flow().status_of(s)).is_equal(MatchFlow.Status.DISCONNECTED)
	_tick([_conn(s, EvPlayerConnectionChanged.RECONNECTED)]) # a late notice must change nothing
	assert_int(_lc.match_flow().status_of(s)).is_equal(MatchFlow.Status.DISCONNECTED)
	assert_bool(_spawns.has(s)).is_false()


# --- AC-3: bleed-out keeps running while disconnected -----------------------------------------------

func test_downed_survivor_with_20s_left_bleeds_out_20s_later_while_still_disconnected() -> void:
	_start()
	var s := _survivors()[2]
	_tick([_down(s)])
	_tick([_conn(s, EvPlayerConnectionChanged.DISCONNECTED)])
	_step_by(_knobs.ticks(20.0) - 1)
	var e := _elim(s)
	e.reason = EvSurvivorEliminated.BLED_OUT
	_tick([e]) # Downing's bleed-out fires 20 s after the drop
	assert_int(_lc.match_flow().status_of(s)).is_equal(MatchFlow.Status.ELIMINATED)
	_step_by(_grace_ticks())
	assert_int(_lc.match_flow().status_of(s)).is_equal(MatchFlow.Status.ELIMINATED) # not re-listed
	_tick([_conn(s, EvPlayerConnectionChanged.RECONNECTED)])
	assert_bool(_spawns.has(s)).is_false()


func _step_by(n: int) -> void:
	for i in n:
		_step()


# --- real ENet: Match Flow's expiry and the router's admission agree --------------------------------

func _net(lobby: Object) -> NetAuthority:
	var root := Node.new()
	root.name = "Sg%d" % _roots.size()
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


func _clock() -> int:
	return _server.tick_runner.current_tick() if _server.tick_runner != null else 0


func test_over_enet_a_rejoin_after_match_flow_expired_the_grace_is_refused() -> void:
	_next_port += 1
	var port := _next_port
	var lobby := LobbyState.new(_knobs)
	var server := _net(lobby)
	var router := ConnectionRouter.new(_knobs, server, lobby, _clock)
	server.known_token_in_grace = router.in_grace
	assert_int(server.host(port)).is_equal(OK)
	var client := _net(RefCounted.new())
	assert_int(client.join("127.0.0.1", port, "Ann")).is_equal(OK)
	await _until(func() -> bool: return client.local_player_id >= 0 \
		and server.peer_id_of(client.local_player_id) != -1, "join")
	var pid := client.local_player_id
	for t in FILLER_TOKENS.slice(0, _knobs.lobby.min_players - 1):
		lobby.join(t)
		lobby.set_ready(t, true)
	lobby.set_ready(server.token_of(pid), true)
	lobby.server_tick(1)
	lobby.server_tick(1 + _knobs.ticks(_knobs.lobby.lobby_countdown_s))
	assert_str(lobby.state()).is_equal(LobbyState.IN_MATCH)
	var mf := MatchFlow.new()
	mf.survivor_ids.assign([pid, 901, 902])
	assert_array(_server.start_round({TickOrder.MATCH_FLOW_BEGIN: mf,
		TickOrder.MATCH_FLOW_RESOLVE: mf.resolve_step()}, _knobs)).is_empty()
	_server.bus.subscribe(&"PlayerConnectionChanged", _on_conn)
	router.bus = _server.bus
	_step()
	var token := client.local_token
	client.close()
	await _until(func() -> bool: return router.grace_start_tick(pid) != -1, "drop")
	var start := router.grace_start_tick(pid)
	while _now() < start + _grace_ticks() - 1:
		_step()
	assert_bool(router.in_grace(token)).is_true()
	assert_array(_statuses(pid)).is_equal([EvPlayerConnectionChanged.DISCONNECTED])
	_step()
	assert_array(_statuses(pid)).is_equal([EvPlayerConnectionChanged.DISCONNECTED,
		EvPlayerConnectionChanged.GRACE_EXPIRED])
	assert_bool(router.in_grace(token)).is_false() # both clocks closed the grace on the same tick
	var again := _net(RefCounted.new())
	var rejects: Array[StringName] = []
	again.join_rejected.connect(func(r: StringName) -> void: rejects.append(r))
	assert_int(again.join("127.0.0.1", port, "Ann", token)).is_equal(OK)
	await _until(func() -> bool: return not rejects.is_empty(), "reject")
	assert_int(again.local_player_id).is_equal(-1)
	assert_int(mf.status_of(pid)).is_equal(MatchFlow.Status.DISCONNECTED)
	await get_tree().create_timer(_knobs.net.reject_close_delay_s + 0.15).timeout
