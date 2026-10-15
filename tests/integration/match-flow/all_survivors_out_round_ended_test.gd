# BUG-0007: when every survivor is out, every eliminated client still gets the RoundEnded batch (ADR-0004 §8).
# ServerMovement over ENet on loopback with a real RoundLifecycle: two real clients dealt survivors (Ann
# out first, so she ends up watching a survivor who then loses its body; Bob last, with nobody left to
# watch) and two survivors with server-side bodies only. Ports 30920-30939 (this suite's range).
extends GdUnitTestSuite

const SEED := 7700
const SESSION := "s-bug7"
const VERSION := "test-1.0+bug7"
const PORT := 30920
const WAIT_S := 5.0

class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0

var _knobs: Knobs
var _server: RoundServer
var _lc: RoundLifecycle
var _sm: ServerMovement
var _roots: Array[Node] = []
var _bodies: Dictionary[int, CharacterBody3D] = {}


func before_test() -> void:
	_knobs = Knobs.load_all()
	_server = auto_free(RoundServer.new())
	_bodies = {}


func after_test() -> void:
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


func _root() -> Node:
	var n := Node.new()
	n.name = "Bug7r%d" % _roots.size()
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
	_poll()


func _join() -> NetAuthority:
	var c := NetAuthority.new()
	c.setup(_knobs, VERSION, FakeLobby.new())
	_root().add_child(c)
	assert_int(c.join("127.0.0.1", PORT, "P", "")).is_equal(OK)
	await _until(func() -> bool: return c.local_player_id != -1, "joined")
	return c


## Event types of every batch the server sends `c`.
func _record(c: NetAuthority, types: Array) -> void:
	(c.multiplayer as SceneMultiplayer).peer_packet.connect(func(_p: int, bytes: PackedByteArray) -> void:
		if EventBatch.is_message(bytes):
			for e: Array in EventBatch.decode(bytes).entries:
				types.append(e[0]))


func _spawn(id: int, pos: Vector3) -> void:
	_bodies[id] = TestMoveStep.make_body(_roots[0], pos)
	_sm.add_player(id, _bodies[id])
	_sm.set_frozen(id, true)


func _remove(id: int) -> Vector3:
	_sm.remove_player(id)
	var at := _bodies[id].global_position
	_bodies[id].free()
	_bodies.erase(id)
	return at


func _elim(id: int) -> void:
	var e := EvSurvivorEliminated.new()
	e.survivor = id
	_server.bus.emit(e)
	_step()


func test_every_eliminated_client_gets_round_ended_when_the_last_survivor_goes() -> void:
	var server_root := _root()
	var net := NetAuthority.new()
	net.setup(_knobs, VERSION, FakeLobby.new())
	server_root.add_child(net)
	assert_int(net.host(PORT)).is_equal(OK)
	var ann := await _join()
	var bob := await _join()
	var a := ann.local_player_id
	var b := bob.local_player_id
	var info := func(t: String) -> Dictionary:
		var id: int = {"t0": a, "t1": b}.get(t, 900 + t.trim_prefix("t").to_int())
		return {"player_id": id, "name": t}
	var rng := RandomNumberGenerator.new()
	var roster: Roster
	for s in range(SEED, SEED + 50): # the first seed (deterministic) that deals Ann and Bob survivors
		rng.seed = s
		roster = Roster.lock(PackedStringArray(["t0", "t1", "t2", "t3", "t4"]), info, SESSION, 1, _knobs,
			RotationQueue.new(), rng)
		if roster.entry(a).role == Roster.SURVIVOR and roster.entry(b).role == Roster.SURVIVOR:
			break
	assert_bool(roster.entry(a).role == Roster.SURVIVOR and roster.entry(b).role == Roster.SURVIVOR).is_true()
	_lc = RoundLifecycle.new(roster, MapData.load_map(), rng)
	assert_array(_server.start_round({TickOrder.MATCH_FLOW_BEGIN: _lc,
		TickOrder.MATCH_FLOW_RESOLVE: _lc.resolve_step()}, _knobs)).is_empty()
	_sm = ServerMovement.new(_knobs, net, server_root.multiplayer as SceneMultiplayer, TestMoveStep.apply, TestMoveStep.WORLD)
	_sm.attach(_server.tick_runner)
	_lc.spawn = _spawn
	_lc.remove = _remove
	_lc.watch = _sm.watch
	_sm.monster = _lc.match_flow().shapeshifter_id
	for id in roster.player_ids():
		_lc.report_loaded(id)
	for i in 3:
		_step()
	var ann_types := []
	var bob_types := []
	_record(ann, ann_types)
	_record(bob, bob_types)
	# Ann first, then the two server-only survivors, Bob last: Ann ends up watching Bob.
	_elim(a)
	for id in _lc.match_flow().survivor_ids:
		if id != a and id != b:
			_elim(id)
	assert_int(_sm.watched_by(a)).is_equal(b)
	_elim(b)
	assert_int(_lc.state()).is_equal(RoundLifecycle.State.RESULTS)
	await _until(func() -> bool: return ann_types.has(&"RoundEnded") and bob_types.has(&"RoundEnded"),
		"RoundEnded on both eliminated clients")
	assert_bool(ann_types.has(&"RoundEnded")).override_failure_message("Ann: %s" % [ann_types]).is_true()
	assert_bool(bob_types.has(&"RoundEnded")).override_failure_message("Bob: %s" % [bob_types]).is_true()
