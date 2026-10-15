# Story match-flow/009: clients display the server's phase, clock and outcome only (design/gdd/match-flow.md
# AC; ADR-0005, ADR-0004 §5). The real-ENet cases run a RoundServer (out of the tree, so only step()
# advances it) with a RoundLifecycle, ServerMovement sending the per-peer streams, and five clients each
# holding a MatchDisplay. The clock cases feed one MatchDisplay the real wire bytes (EventBatch.build,
# SnapshotCodec.encode) by hand.
extends GdUnitTestSuite

const VERSION := "test-1.0+mf9"
const SESSION := "s-9"
const WAIT_S := 5.0
## Loopback delivery bound (story Engine Notes): checked on 127.0.0.1 only.
const LOOPBACK_BOUND_MS := 200
const CLIENTS := 5
const SEED := 9009
## Server tick of the hand-fed Infiltration batch (any tick after a loading barrier).
const START_TICK := 100

static var _next_port := 25900

class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0

var _knobs: Knobs
var _roots: Array[Node] = []
var _server: RoundServer
var _sm: ServerMovement
var _lc: RoundLifecycle
var _clients: Array[NetAuthority] = []
var _views: Array[MatchDisplay] = []
## Server tick -> MatchFlow time remaining after that tick.
var _remaining_at: Dictionary[int, float] = {}
var _round_ended := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_server = auto_free(RoundServer.new())
	_remaining_at = {}
	_round_ended = 0


func after_test() -> void:
	for v in _views:
		v.close()
	_views.clear()
	if _sm != null:
		_sm.detach()
		_sm = null
	_server.end_round()
	_lc = null
	_clients.clear()
	for r in _roots:
		for n in r.get_children():
			if n is NetAuthority:
				n.close()
		var api := r.multiplayer as SceneMultiplayer
		if api.multiplayer_peer != null:
			api.multiplayer_peer.close()
		api.multiplayer_peer = null
		get_tree().set_multiplayer(null, r.get_path())
		r.free()
	_roots.clear()


# --- rig ---------------------------------------------------------------------

func _root() -> Node:
	var n := Node.new()
	n.name = "Cd%d" % _roots.size()
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


func _step() -> void:
	_server.tick_runner.step()
	_remaining_at[_server.tick_runner.current_tick()] = _lc.match_flow().time_remaining_s()
	_poll()


func _tick() -> int:
	return _server.tick_runner.current_tick()


## Hosts, joins five clients (each with a MatchDisplay), locks the roster and starts the round with every
## map loaded, so the next step opens the loading barrier.
func _start() -> void:
	var server_root := _root()
	var net := NetAuthority.new()
	net.setup(_knobs, VERSION, FakeLobby.new())
	server_root.add_child(net)
	_next_port += 1
	assert_int(net.host(_next_port)).is_equal(OK)
	var bodies := {}
	var joined := func(pid: int) -> void: bodies[pid] = TestMoveStep.make_body(server_root, Vector3.ZERO)
	net.player_joined.connect(joined)
	for i in CLIENTS:
		var root := _root()
		var c := NetAuthority.new()
		c.setup(_knobs, VERSION, FakeLobby.new())
		root.add_child(c)
		assert_int(c.join("127.0.0.1", _next_port, "P%d" % i)).is_equal(OK)
		_clients.append(c)
		_views.append(MatchDisplay.new(_knobs, root.multiplayer as SceneMultiplayer))
	await _until(func() -> bool:
		return bodies.size() == CLIENTS and _clients.all(func(c: NetAuthority) -> bool: return c.local_player_id != -1),
		"all joined")
	var info := func(t: String) -> Dictionary:
		var c := _clients[t.to_int()]
		return {"player_id": c.local_player_id, "name": "P" + t}
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var roster := Roster.lock(PackedStringArray(["0", "1", "2", "3", "4"]), info, SESSION, 1, _knobs,
		RotationQueue.new(), rng)
	assert_object(roster).is_not_null()
	_lc = RoundLifecycle.new(roster, MapData.load_map(), rng)
	assert_array(_server.start_round({TickOrder.MATCH_FLOW_BEGIN: _lc,
		TickOrder.MATCH_FLOW_RESOLVE: _lc.resolve_step()}, _knobs)).is_empty()
	_server.bus.subscribe(&"RoundEnded", _on_round_ended)
	_sm = ServerMovement.new(_knobs, net, server_root.multiplayer as SceneMultiplayer, TestMoveStep.apply, TestMoveStep.WORLD)
	_sm.attach(_server.tick_runner)
	for pid: int in bodies:
		_sm.add_player(pid, bodies[pid])
		_sm.set_frozen(pid, true)
		_lc.report_loaded(pid)
		if roster.entry(pid).role == Roster.SHAPESHIFTER:
			_sm.monster = pid


func _on_round_ended(_e: ServerEvent) -> void:
	_round_ended += 1


func _survivors() -> Array[int]:
	return _lc.match_flow().survivor_ids


## Runs one step that emits a phase change or the outcome, then waits (stepping no further) until every
## client shows `shown`. Returns the wall time that took.
func _step_until_all_show(shown: Callable, what: String) -> int:
	var t0 := Time.get_ticks_msec()
	var tick := _tick()
	_step()
	await _until(func() -> bool: return _views.all(shown), what)
	assert_int(_tick()).is_equal(tick + 1) # shown within the tick that changed it: no later tick needed
	return Time.get_ticks_msec() - t0


# --- AC-1: same phase, clock and outcome on every client ---------------------

func test_every_client_shows_each_phase_change_the_clock_and_the_outcome() -> void:
	await _start()
	var mf := _lc.match_flow()
	# Barrier opens: RoundPhaseChanged(Infiltration) reaches all five within the bound.
	var ms := await _step_until_all_show(func(v: MatchDisplay) -> bool:
		return v.phase() == MatchFlow.Phase.INFILTRATION, "Infiltration on every client")
	assert_int(ms).is_less_equal(LOOPBACK_BOUND_MS)
	# A server-side owner arms the terminal (Objectives stand-in): Evacuation.
	var armed := EvObjectiveProgressChanged.new()
	armed.objective = SurvivorObjectives.TERMINAL_ID
	armed.state = SurvivorObjectives.TerminalState.ARMED
	_server.bus.emit(armed)
	ms = await _step_until_all_show(func(v: MatchDisplay) -> bool:
		return v.phase() == MatchFlow.Phase.EVACUATION, "Evacuation on every client")
	assert_int(ms).is_less_equal(LOOPBACK_BOUND_MS)
	assert_int(mf.phase()).is_equal(MatchFlow.Phase.EVACUATION)
	# The clock: every view equals the server's clock at the newest tick it heard of.
	for i in 30:
		_step()
	var last := _tick()
	await _until(func() -> bool: return _views.all(func(v: MatchDisplay) -> bool: return v.server_tick() >= last - 1),
		"recent snapshots")
	for v in _views:
		assert_float(v.time_remaining_s()).is_equal(_remaining_at[v.server_tick()])
	# All survivors eliminated: one RoundEnded with the same outcome, reason and payload everywhere.
	for id in _survivors():
		var gone := EvSurvivorEliminated.new()
		gone.survivor = id
		_server.bus.emit(gone)
	ms = await _step_until_all_show(func(v: MatchDisplay) -> bool: return v.is_ended(), "RoundEnded on every client")
	assert_int(ms).is_less_equal(LOOPBACK_BOUND_MS)
	assert_int(_round_ended).is_equal(1)
	for v in _views:
		assert_int(v.outcome()).is_equal(MatchFlow.Outcome.SHAPESHIFTER_WINS)
		assert_int(v.reason()).is_equal(MatchFlow.Reason.ALL_ELIMINATED)
		assert_dict(v.results()).is_equal(_views[0].results())
	# Results: the server clock stopped, and so does every client's (extrapolation included).
	var stopped := mf.time_remaining_s()
	for i in 10:
		_step()
	await _until(func() -> bool: return _views.all(func(v: MatchDisplay) -> bool: return v.server_tick() >= _tick() - 1),
		"Results snapshots")
	for v in _views:
		v.advance(5.0)
		assert_float(v.time_remaining_s()).is_equal(stopped)
	assert_float(mf.time_remaining_s()).is_equal(stopped)


# --- AC-2: a modified client's fake messages change nothing ------------------

func test_fake_round_won_and_phase_change_bytes_from_a_client_change_no_state() -> void:
	await _start()
	await _step_until_all_show(func(v: MatchDisplay) -> bool:
		return v.phase() == MatchFlow.Phase.INFILTRATION, "Infiltration on every client")
	var server_api := _roots[0].multiplayer as SceneMultiplayer
	var got := [0]
	server_api.peer_packet.connect(func(_peer: int, _b: PackedByteArray) -> void: got[0] += 1)
	var won := EvRoundEnded.new()
	won.outcome = MatchFlow.Outcome.SURVIVORS_WIN
	won.reason = MatchFlow.Reason.EVIDENCE_ESCAPED
	var evac := EvRoundPhaseChanged.new()
	evac.phase = MatchFlow.Phase.EVACUATION
	var fakes: Array[PackedByteArray] = [
		_fake_batch(won), _fake_batch(evac), # what the server itself would send, sent back
		var_to_bytes({"round_won": true}), var_to_bytes({"phase": MatchFlow.Phase.EVACUATION}),
		var_to_bytes(["RoundEnded", {"outcome": 0}]),
		PackedByteArray([EventBatch.TAG, 0xFF, 0x00]), PackedByteArray([0x00]), # malformed
	]
	var modified := _clients[0].multiplayer as SceneMultiplayer
	for bytes in fakes:
		modified.send_bytes(bytes, 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE, NetChannels.EVENT)
	await _until(func() -> bool: return got[0] >= fakes.size(), "fakes at the server")
	for i in 5:
		_step()
	await _until(func() -> bool: return _views.all(func(v: MatchDisplay) -> bool: return v.server_tick() >= _tick() - 1),
		"snapshots after the fakes")
	var mf := _lc.match_flow()
	assert_int(mf.phase()).is_equal(MatchFlow.Phase.INFILTRATION)
	assert_bool(mf.is_ended()).is_false()
	assert_int(_lc.state()).is_equal(RoundLifecycle.State.RUNNING)
	assert_int(_round_ended).is_equal(0)
	for v in _views:
		assert_int(v.phase()).is_equal(MatchFlow.Phase.INFILTRATION)
		assert_bool(v.is_ended()).is_false()
		assert_int(v.outcome()).is_equal(-1)
		assert_int(v.rejected).is_equal(0) # nothing was relayed to any client
		assert_float(v.time_remaining_s()).is_equal(_remaining_at[v.server_tick()])


## A batch only counts from the server peer: the same bytes from any other peer change nothing.
func test_a_view_ignores_batches_not_from_the_server_and_malformed_ones() -> void:
	var v := MatchDisplay.new(_knobs)
	var start := EvRoundPhaseChanged.new()
	start.phase = MatchFlow.Phase.INFILTRATION
	v.receive(_fake_batch(start, START_TICK))
	var won := EvRoundEnded.new()
	won.outcome = MatchFlow.Outcome.SURVIVORS_WIN
	var evac := EvRoundPhaseChanged.new()
	evac.phase = MatchFlow.Phase.EVACUATION
	for peer in [0, 2, 7]:
		v.on_packet(peer, _fake_batch(won, START_TICK + 1))
		v.on_packet(peer, _fake_batch(evac, START_TICK + 1))
	assert_int(v.phase()).is_equal(MatchFlow.Phase.INFILTRATION)
	assert_bool(v.is_ended()).is_false()
	# Malformed from the server: counted, nothing applied.
	var bad_phase := PackedByteArray([EventBatch.TAG])
	bad_phase.append_array(var_to_bytes([START_TICK + 2, [[&"RoundPhaseChanged", {"phase": 99}],
		[&"RoundPhaseChanged", {"phase": "2"}], [&"RoundEnded", {"outcome": 7, "reason": 0, "results": {}}]]]))
	v.receive(bad_phase)
	v.receive(PackedByteArray([EventBatch.TAG, 1, 2]))
	v.receive(PackedByteArray([SnapshotCodec.VERSION, 1]))
	assert_int(v.phase()).is_equal(MatchFlow.Phase.INFILTRATION)
	assert_bool(v.is_ended()).is_false()
	assert_int(v.rejected).is_equal(5)


# --- AC-3: clock drift corrected, phase only on the event ---------------------

func test_a_client_clock_10_s_ahead_snaps_back_to_the_server_value() -> void:
	var hz := _knobs.net.sim_tick_hz
	var dur := _knobs.match_flow.round_duration_s
	var v := MatchDisplay.new(_knobs)
	assert_bool(v.has_clock()).is_false()
	var start := EvRoundPhaseChanged.new()
	start.phase = MatchFlow.Phase.INFILTRATION
	v.receive(_fake_batch(start, START_TICK))
	# One tick before the Infiltration -> Investigation boundary on the server's clock.
	var k := _knobs.ticks(_knobs.match_flow.infiltration_end_s) - 1
	v.receive(_snapshot(START_TICK + k))
	assert_float(v.time_remaining_s()).is_equal(MatchFlow.time_remaining_at(float(k) / float(hz), dur))
	# Between server values the local clock extrapolates; skewed 10 s ahead it shows 10 s less.
	var drift_s := 10.0
	v.advance(drift_s)
	assert_float(v.time_remaining_s()).is_equal_approx(
		MatchFlow.time_remaining_at(float(k) / float(hz), dur) - drift_s, 1e-6)
	# Past the boundary on the local clock, the phase still waits for RoundPhaseChanged.
	assert_int(v.phase()).is_equal(MatchFlow.Phase.INFILTRATION)
	# The next server value replaces the local one exactly.
	v.receive(_snapshot(START_TICK + k + 1))
	assert_float(v.time_remaining_s()).is_equal(MatchFlow.time_remaining_at(float(k + 1) / float(hz), dur))
	# An older (reordered) snapshot does not move it back.
	v.receive(_snapshot(START_TICK + k))
	assert_int(v.server_tick()).is_equal(START_TICK + k + 1)
	assert_int(v.phase()).is_equal(MatchFlow.Phase.INFILTRATION)
	var inv := EvRoundPhaseChanged.new()
	inv.phase = MatchFlow.Phase.INVESTIGATION
	v.receive(_fake_batch(inv, START_TICK + k + 1))
	assert_int(v.phase()).is_equal(MatchFlow.Phase.INVESTIGATION)


func test_no_phase_or_clock_before_the_round_begins() -> void:
	var v := MatchDisplay.new(_knobs)
	v.receive(_snapshot(START_TICK))
	v.advance(1.0)
	assert_int(v.phase()).is_equal(-1)
	assert_bool(v.has_clock()).is_false()
	assert_float(v.time_remaining_s()).is_equal(_knobs.match_flow.round_duration_s)


# --- helpers -----------------------------------------------------------------

## The bytes the server would send any viewer for `e` at `tick` (public projection).
func _fake_batch(e: ServerEvent, tick := START_TICK) -> PackedByteArray:
	var events: Array[ServerEvent] = [e]
	return EventBatch.build(tick, 1, events, [], Vector3.ZERO, HandleTable.new(), -1)


func _snapshot(tick: int) -> PackedByteArray:
	var bodies: Array[Dictionary] = []
	return SnapshotCodec.encode(tick, bodies)
