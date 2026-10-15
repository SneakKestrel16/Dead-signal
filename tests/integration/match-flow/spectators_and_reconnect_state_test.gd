# Story match-flow/007: spectators and full state on reconnect (design/gdd/match-flow.md rule 10,
# TR-matchflow-006, TR-matchflow-009; ADR-0004 §8-9). The hook cases run a RoundLifecycle on a RoundServer
# kept out of the tree, standing in for Downing (SurvivorEliminated) and the router (PlayerConnectionChanged)
# by emitting between steps, as story 005 does. The catch-up case feeds MatchFlow.catch_up() to a
# MatchDisplay as the real wire bytes. The last test runs ServerMovement over ENet on loopback: an
# eliminated client spectates, then reconnects and gets the round state it missed.
extends GdUnitTestSuite

const SEED := 7007
const SESSION := "s-7"
const VERSION := "test-1.0+mf7"
const WAIT_S := 5.0
const TOKENS: Array[String] = ["t1", "t2", "t3", "t4", "t5"]

static var _next_port := 26000

class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0

var _knobs: Knobs
var _server: RoundServer
var _lc: RoundLifecycle
var _spawns: Dictionary[int, Vector3] = {}
var _removed: Array[int] = []
## [spectator, survivor] per watch hook call, in call order.
var _watches: Array = []
var _roots: Array[Node] = []
var _sm: ServerMovement
var _bodies: Dictionary[int, CharacterBody3D] = {}
var _views: Array[MatchDisplay] = []
## Server tick -> MatchFlow time remaining after that tick (ENet case).
var _remaining_at: Dictionary[int, float] = {}


func before_test() -> void:
	_knobs = Knobs.load_all()
	_server = auto_free(RoundServer.new())
	_spawns = {}
	_removed = []
	_watches = []
	_bodies = {}
	_remaining_at = {}


func after_test() -> void:
	for v in _views:
		v.close()
	_views.clear()
	if _sm != null:
		_sm.detach()
		_sm = null
	_server.end_round()
	_lc = null
	for r in _roots:
		for c in r.get_children():
			if c is NetAuthority:
				c.close()
		var api := r.multiplayer as SceneMultiplayer
		if api.multiplayer_peer != null:
			api.multiplayer_peer.close()
		api.multiplayer_peer = null
		get_tree().set_multiplayer(null, r.get_path())
		r.free()
	_roots.clear()


# --- hook rig -------------------------------------------------------------------------------------

func _info(token: String) -> Dictionary:
	var n := token.trim_prefix("t").to_int()
	return {"player_id": n, "name": "P%d" % n}


func _on_spawn(id: int, pos: Vector3) -> void:
	_spawns[id] = pos


func _on_remove(id: int) -> Vector3:
	_removed.append(id)
	return Vector3.ZERO


func _on_watch(spectator: int, survivor: int) -> void:
	_watches.append([spectator, survivor])


## A five-player round past its loading barrier (Running), hooks recorded.
func _start() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var roster := Roster.lock(PackedStringArray(TOKENS), _info, SESSION, 1, _knobs, RotationQueue.new(), rng)
	_lc = RoundLifecycle.new(roster, MapData.load_map(), rng)
	_lc.spawn = _on_spawn
	_lc.remove = _on_remove
	_lc.watch = _on_watch
	assert_array(_server.start_round({TickOrder.MATCH_FLOW_BEGIN: _lc,
		TickOrder.MATCH_FLOW_RESOLVE: _lc.resolve_step()}, _knobs)).is_empty()
	for id in roster.player_ids():
		_lc.report_loaded(id)
	_step()
	assert_int(_lc.state()).is_equal(RoundLifecycle.State.RUNNING)
	_spawns = {}


## Survivor ids, ascending.
func _survivors() -> Array[int]:
	var out := _lc.match_flow().survivor_ids.duplicate()
	out.sort()
	return out


func _step() -> int:
	_server.tick_runner.step()
	return _server.tick_runner.current_tick()


func _tick(events: Array[ServerEvent] = []) -> int:
	for e in events:
		_server.bus.emit(e)
	return _step()


func _elim(id: int) -> EvSurvivorEliminated:
	var e := EvSurvivorEliminated.new()
	e.survivor = id
	return e


func _escaped(id: int) -> EvSurvivorEscaped:
	var e := EvSurvivorEscaped.new()
	e.survivor = id
	return e


func _conn(id: int, status: int) -> EvPlayerConnectionChanged:
	var e := EvPlayerConnectionChanged.new()
	e.player = id
	e.status = status
	return e


# --- AC-1: Out survivors watch a living survivor ---------------------------------------------------

func test_an_eliminated_or_escaped_survivor_loses_its_body_and_watches_the_lowest_living_survivor() -> void:
	_start()
	var s := _survivors()
	_tick([_elim(s[1])])
	assert_array(_removed).is_equal([s[1]])
	assert_array(_watches).is_equal([[s[1], s[0]]])
	assert_int(_lc.watched_by(s[1])).is_equal(s[0])
	# The watched survivor escapes: its watcher moves on, and it watches the same next survivor.
	_tick([_escaped(s[0])])
	assert_array(_removed).is_equal([s[1], s[0]])
	assert_array(_watches).is_equal([[s[1], s[0]], [s[1], s[2]], [s[0], s[2]]])


# --- AC-2: the watched survivor leaves, or nobody is left ---------------------------------------------

func test_a_watched_survivor_who_disconnects_hands_the_spectator_on_and_a_reconnect_does_not_pull_it_back() -> void:
	_start()
	var s := _survivors()
	_tick([_elim(s[1])])
	_tick([_conn(s[0], EvPlayerConnectionChanged.DISCONNECTED)]) # no body: nothing to watch
	assert_array(_watches).is_equal([[s[1], s[0]], [s[1], s[2]]])
	_tick([_conn(s[0], EvPlayerConnectionChanged.RECONNECTED)])
	assert_array(_watches).is_equal([[s[1], s[0]], [s[1], s[2]]])
	assert_int(_lc.watched_by(s[1])).is_equal(s[2])


func test_when_no_living_survivor_is_left_spectating_ends_with_the_round() -> void:
	_start()
	var s := _survivors()
	for i in s.size() - 1:
		var n := _watches.size()
		_tick([_elim(s[i])])
		for w: Array in _watches.slice(n):
			assert_int(w[1]).is_equal(s[i + 1]) # every move lands on the lowest survivor still living
		assert_int(_watches.size()).is_equal(n + i + 1) # every spectator so far moves
	var before := _watches.size()
	_tick([_elim(s[s.size() - 1])])
	# Nobody left to watch: no switch; only the last one out is watched as -1, for RoundEnded (BUG-0007).
	assert_array(_watches.slice(before)).is_equal([[s[s.size() - 1], -1]])
	assert_int(_lc.state()).is_equal(RoundLifecycle.State.RESULTS)


# --- spectators and the disconnect hooks --------------------------------------------------------------

func test_a_spectator_disconnect_removes_no_body_and_its_reconnect_spawns_none() -> void:
	_start()
	var s := _survivors()
	_tick([_elim(s[1])])
	_tick([_conn(s[1], EvPlayerConnectionChanged.DISCONNECTED)])
	_tick([_conn(s[1], EvPlayerConnectionChanged.RECONNECTED)])
	assert_array(_removed).is_equal([s[1]])
	assert_dict(_spawns).is_empty()
	assert_int(_lc.watched_by(s[1])).is_equal(s[0])


func test_a_survivor_eliminated_while_away_is_not_respawned_by_a_reconnect_in_grace() -> void:
	_start()
	var s := _survivors()
	_tick([_conn(s[2], EvPlayerConnectionChanged.DISCONNECTED)])
	_tick([_elim(s[2])]) # bled out while away, still in grace
	_tick([_conn(s[2], EvPlayerConnectionChanged.RECONNECTED)])
	assert_array(_removed).is_equal([s[2]]) # the disconnect took the body; elimination had none to take
	assert_dict(_spawns).is_empty()
	assert_int(_lc.watched_by(s[2])).is_equal(s[0])


# --- AC-3: catch-up carries clock, phase, roster statuses and outcome ---------------------------------

func test_catch_up_bytes_give_a_fresh_client_the_server_phase_clock_statuses_and_outcome() -> void:
	_start()
	var s := _survivors()
	for i in 30:
		_step()
	var armed := EvObjectiveProgressChanged.new()
	armed.objective = SurvivorObjectives.TERMINAL_ID
	armed.state = SurvivorObjectives.TerminalState.ARMED
	_tick([armed])
	var down := EvSurvivorDowned.new()
	down.survivor = s[0]
	_tick([down, _elim(s[1]), _conn(s[2], EvPlayerConnectionChanged.DISCONNECTED)])
	for i in 7:
		_step()
	var mf := _lc.match_flow()
	var view := MatchDisplay.new(_knobs)
	var seen := _replay(view, mf.catch_up())
	var no_bodies: Array[Dictionary] = []
	view.receive(SnapshotCodec.encode(_server.tick_runner.current_tick(), no_bodies))
	assert_int(view.phase()).is_equal(MatchFlow.Phase.EVACUATION)
	assert_bool(view.has_clock()).is_true()
	assert_float(view.time_remaining_s()).is_equal(mf.time_remaining_s())
	assert_array(seen).is_equal([
		[&"RoundPhaseChanged", {"phase": MatchFlow.Phase.INFILTRATION}],
		[&"RoundPhaseChanged", {"phase": MatchFlow.Phase.EVACUATION}],
		[&"SurvivorDowned", {"survivor": s[0], "bleed_out_s": 0.0}],
		[&"SurvivorEliminated", {"survivor": s[1], "reason": EvSurvivorEliminated.TAKEN_DOWN}],
		[&"PlayerConnectionChanged", {"player": s[2], "status": EvPlayerConnectionChanged.DISCONNECTED}],
	])
	# A reconnect clears the connection entry; the outcome joins once the round ended.
	_tick([_conn(s[2], EvPlayerConnectionChanged.RECONNECTED), _elim(s[0]), _elim(s[2]), _elim(s[3])])
	assert_bool(mf.is_ended()).is_true()
	var ended := MatchDisplay.new(_knobs)
	seen = _replay(ended, mf.catch_up())
	assert_bool(ended.is_ended()).is_true()
	assert_int(ended.reason()).is_equal(MatchFlow.Reason.ALL_ELIMINATED)
	for entry: Array in seen:
		assert_str(entry[0]).is_not_equal(&"PlayerConnectionChanged")


## Each event as the server sends it (EventBatch at the event's own tick, survivor projection); returns
## the decoded entries, in order.
func _replay(view: MatchDisplay, events: Array[ServerEvent]) -> Array:
	var seen := []
	for e in events:
		var one: Array[ServerEvent] = [e]
		var bytes := EventBatch.build(e.tick, _survivors()[3], one, [], Vector3.ZERO, HandleTable.new(),
			_lc.match_flow().shapeshifter_id)
		view.receive(bytes)
		seen.append_array(EventBatch.decode(bytes).entries)
	return seen


# --- real ENet: an eliminated client spectates, reconnects and catches up -------------------------------

func _root() -> Node:
	var n := Node.new()
	n.name = "Sr%d" % _roots.size()
	get_tree().root.add_child(n)
	get_tree().set_multiplayer(SceneMultiplayer.new(), n.get_path())
	_roots.append(n)
	return n


func _poll() -> void:
	for r in _roots:
		(r.multiplayer as SceneMultiplayer).poll()


func _until(cond: Callable, what: String) -> void:
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while Time.get_ticks_msec() < end:
		_poll()
		if cond.call():
			return
		await get_tree().process_frame
	assert_bool(cond.call()).override_failure_message("timeout waiting for " + what).is_true()


func _net_step() -> void:
	_server.tick_runner.step()
	_remaining_at[_server.tick_runner.current_tick()] = _lc.match_flow().time_remaining_s()
	_poll()


func _join(token := "") -> NetAuthority:
	var root := _root()
	var c := NetAuthority.new()
	c.setup(_knobs, VERSION, FakeLobby.new())
	root.add_child(c)
	assert_int(c.join("127.0.0.1", _next_port, "Ann", token)).is_equal(OK)
	_views.append(MatchDisplay.new(_knobs, root.multiplayer as SceneMultiplayer))
	await _until(func() -> bool: return c.local_player_id != -1, "joined")
	return c


## Own-entry ids and positions, and event entries, of every packet the server sends `c`.
func _record(c: NetAuthority, own: Array, events: Array) -> void:
	(c.multiplayer as SceneMultiplayer).peer_packet.connect(func(_p: int, bytes: PackedByteArray) -> void:
		if EventBatch.is_message(bytes):
			events.append_array(EventBatch.decode(bytes).entries)
			return
		var snap := SnapshotCodec.decode(bytes)
		if not snap.is_empty():
			for e: Dictionary in snap.bodies:
				if e.get("own", false):
					own.append([e.id, e.pos]))


func _net_spawn(id: int, pos: Vector3) -> void:
	_bodies[id] = TestMoveStep.make_body(_roots[0], pos)
	_sm.add_player(id, _bodies[id])
	_sm.set_frozen(id, true)


func _net_remove(id: int) -> Vector3:
	_sm.remove_player(id)
	var at := _bodies[id].global_position
	_bodies[id].free()
	_bodies.erase(id)
	return at


func test_over_enet_a_spectator_gets_the_watched_stream_sends_nothing_and_catches_up_on_reconnect() -> void:
	var server_root := _root()
	var net := NetAuthority.new()
	net.setup(_knobs, VERSION, FakeLobby.new())
	server_root.add_child(net)
	_next_port += 1
	assert_int(net.host(_next_port)).is_equal(OK)
	var ann := await _join()
	var a := ann.local_player_id
	# One real client (Ann, dealt a survivor) and four roster players with server-side bodies only.
	var info := func(t: String) -> Dictionary:
		return {"player_id": a if t == "t0" else 900 + t.to_int(), "name": t}
	var rng := RandomNumberGenerator.new()
	var roster: Roster
	for s in range(SEED, SEED + 20): # the first seed (deterministic) that deals Ann a survivor
		rng.seed = s
		roster = Roster.lock(PackedStringArray(["t0", "t1", "t2", "t3", "t4"]), info, SESSION, 1, _knobs,
			RotationQueue.new(), rng)
		if roster.entry(a).role == Roster.SURVIVOR:
			break
	assert_bool(roster.entry(a).role == Roster.SURVIVOR).is_true()
	_lc = RoundLifecycle.new(roster, MapData.load_map(), rng)
	assert_array(_server.start_round({TickOrder.MATCH_FLOW_BEGIN: _lc,
		TickOrder.MATCH_FLOW_RESOLVE: _lc.resolve_step()}, _knobs)).is_empty()
	_sm = ServerMovement.new(_knobs, net, server_root.multiplayer as SceneMultiplayer, TestMoveStep.apply, TestMoveStep.WORLD)
	_sm.attach(_server.tick_runner)
	_lc.spawn = _net_spawn
	_lc.remove = _net_remove
	_lc.watch = _sm.watch
	_sm.catch_up.append(_lc.match_flow().catch_up)
	_sm.monster = _lc.match_flow().shapeshifter_id
	for id in roster.player_ids():
		_lc.report_loaded(id)
	for i in 5:
		_net_step()
	var target: int = _lc.match_flow().survivor_ids.filter(func(id: int) -> bool: return id != a).min()
	# Ann is eliminated: her body goes and she sees through the lowest living survivor.
	var own := []
	_record(ann, own, [])
	_server.bus.emit(_elim(a))
	_net_step()
	assert_int(_sm.watched_by(a)).is_equal(target)
	assert_bool(_bodies.has(a)).is_false()
	_net_step()
	await _until(func() -> bool: return not own.is_empty() and own.back()[0] == target, "the watched stream")
	assert_vector(own.back()[1]).is_equal(_bodies[target].global_position)
	# A spectator has no input path: whatever it sends (a ping, a callout) reaches no living player.
	var drops := _sm.unknown_peer_drops
	(ann.multiplayer as SceneMultiplayer).send_bytes(var_to_bytes({"ping": Vector3.ONE}), 1,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE, NetChannels.EVENT)
	await _until(func() -> bool: return _sm.unknown_peer_drops == drops + 1, "the spectator's packet dropped")
	# Mid-round, past Infiltration: the round moves on while Ann reconnects with her token.
	var armed := EvObjectiveProgressChanged.new()
	armed.objective = SurvivorObjectives.TERMINAL_ID
	armed.state = SurvivorObjectives.TerminalState.ARMED
	_server.bus.emit(armed)
	for i in 20:
		_net_step()
	var ann2 := await _join(ann.local_token)
	var own2 := []
	var events2 := []
	_record(ann2, own2, events2)
	var view := _views.back() as MatchDisplay
	for i in 3:
		_net_step()
	var last := _server.tick_runner.current_tick()
	await _until(func() -> bool: return view.server_tick() >= last and view.phase() == MatchFlow.Phase.EVACUATION,
		"the round state on the rejoined client")
	assert_bool(view.has_clock()).is_true()
	assert_float(view.time_remaining_s()).is_equal(_remaining_at[view.server_tick()])
	assert_bool(events2.has([&"SurvivorEliminated", {"survivor": a, "reason": EvSurvivorEliminated.TAKEN_DOWN}])) \
		.override_failure_message(str(events2)).is_true()
	await _until(func() -> bool: return not own2.is_empty(), "the watched stream after the reconnect")
	assert_int(own2.back()[0]).is_equal(target)
