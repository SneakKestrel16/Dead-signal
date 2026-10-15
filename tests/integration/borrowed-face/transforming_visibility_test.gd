# Story borrowed-face/005 AC 3: every client receives the transforming state within 250 ms of the
# server accepting a form change, at a simulated 150 ms RTT (borrowed-face.md rule 8 and Acceptance
# Criteria "Transforming"; ADR-0002 Validation Criteria; ADR-0004 §4). A RoundServer (out of the tree,
# stepped by the test, paced to the wall clock at sim_tick_hz) runs BorrowedFace and ServerMovement
# for five real ENet clients, each behind a UdpLink at 75 ms each way with 30 ms jitter. Each client's
# packets are decoded raw: a client "sees" the transforming flag its latest snapshot gives the
# shapeshifter's body (client audio and warp visuals are later stories).
extends GdUnitTestSuite

const VERSION := "test-1.0+bf5"
const WAIT_S := 5.0
## Story AC 3: transforming state on every client within 250 ms of acceptance.
const BOUND_MS := 250
const CLIENTS := 5
const LINK_DELAY_S := 0.075 ## 75 ms each way = 150 ms RTT (ADR-0002 Validation Criteria)
const LINK_JITTER_S := 0.030

static var _next_port := 26900

class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0

var _knobs: Knobs
var _roots: Array[Node] = []
var _links: Array[UdpLink] = []
var _server: RoundServer
var _sm: ServerMovement
var _bf: BorrowedFace
var _net: NetAuthority
var _bodies := {}
var _clients: Array[NetAuthority] = []
var _monster := -1
var _survivors: Array[int] = []
## Per client: latest snapshot tick and entries by id (-1 = own entry).
var _last_tick: Array[int] = []
var _entries: Array[Dictionary] = []
## Wall ms the paced server clock started, and ticks stepped since.
var _t0 := 0
var _stepped := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_knobs.borrowed_face = _knobs.borrowed_face.duplicate()
	_knobs.borrowed_face.observe_time_s = 1.0
	_server = auto_free(RoundServer.new())


func after_test() -> void:
	if _sm != null:
		_sm.detach()
		_sm = null
	_server.end_round()
	_bf = null
	_clients.clear()
	for l in _links:
		l.stop()
	_links.clear()
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
	n.name = "Tv%d" % _roots.size()
	get_tree().root.add_child(n)
	get_tree().set_multiplayer(SceneMultiplayer.new(), n.get_path())
	_roots.append(n)
	return n


## Links carry what is due on the wall clock, then every subtree polls.
func _poll() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for l in _links:
		l.pump(now)
	for r in _roots:
		(r.multiplayer as SceneMultiplayer).poll()
	for l in _links:
		l.pump(now)


func _until(cond: Callable, what: String) -> void:
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while Time.get_ticks_msec() < end:
		_poll()
		if cond.call():
			return
		await get_tree().process_frame
	assert_bool(cond.call()).override_failure_message("timeout waiting for " + what).is_true()


## Steps the server as many ticks as the wall clock owes at sim_tick_hz (snapshots go out per tick, so
## their spacing is the real one), then polls.
func _paced_step() -> void:
	var owed := int((Time.get_ticks_msec() - _t0) * _knobs.net.sim_tick_hz / 1000)
	while _stepped < owed:
		_server.tick_runner.step()
		_stepped += 1
	_poll()


func _start() -> void:
	var server_root := _root()
	_net = NetAuthority.new()
	_net.setup(_knobs, VERSION, FakeLobby.new())
	server_root.add_child(_net)
	_next_port += 1
	var port := _next_port
	assert_int(_net.host(port)).is_equal(OK)
	var joined := func(pid: int) -> void:
		_bodies[pid] = TestMoveStep.make_body(server_root, Vector3(0.5 * _bodies.size(), 0.0, -1.0))
	_net.player_joined.connect(joined)
	for i in CLIENTS:
		var root := _root()
		var c := NetAuthority.new()
		c.setup(_knobs, VERSION, FakeLobby.new())
		root.add_child(c)
		var link := UdpLink.new(500 + i)
		_next_port += 1
		assert_int(link.start(_next_port, port)).is_equal(OK)
		_links.append(link)
		assert_int(c.join("127.0.0.1", _next_port, "P%d" % i)).is_equal(OK)
		_clients.append(c)
		_last_tick.append(-1)
		_entries.append({})
		(root.multiplayer as SceneMultiplayer).peer_packet.connect(_on_packet.bind(i))
	await _until(func() -> bool:
		return _bodies.size() == CLIENTS and _clients.all(func(c: NetAuthority) -> bool: return c.local_player_id != -1),
		"all joined")
	for l in _links:
		l.delay_s = LINK_DELAY_S
		l.jitter_s = LINK_JITTER_S
	_monster = _clients[0].local_player_id
	_survivors.assign([])
	for c in _clients.slice(1):
		_survivors.append(c.local_player_id)
	var bf := BorrowedFace.new()
	bf.set_roster(_survivors, _monster)
	bf.set_sight_sources(func(_p: int) -> Vector3: return Vector3(0.0, 1.6, 0.0),
		func(_p: int) -> float: return 0.0,
		func(_p: int) -> PackedVector3Array: return PackedVector3Array(
			[Vector3(0.0, 1.7, -2.0), Vector3(0.0, 1.5, -2.0), Vector3(0.0, 1.0, -2.0)]),
		func(_e: Vector3, _q: Vector3) -> bool: return true,
		func(_p: int) -> bool: return false)
	bf.set_status_source(func(_p: int) -> int: return MatchFlow.Status.HEALTHY)
	_bf = bf
	assert_array(_server.start_round({TickOrder.BORROWED_FACE: _bf}, _knobs)).is_empty()
	_sm = ServerMovement.new(_knobs, _net, server_root.multiplayer as SceneMultiplayer, TestMoveStep.apply,
		TestMoveStep.WORLD)
	_sm.attach(_server.tick_runner)
	_sm.monster = _monster
	_sm.appearance_of = _bf.appearance_of
	_sm.transforming_of = _bf.transforming_of
	_bf.on_form_event = _sm.scope.form_changed
	for pid: int in _bodies:
		_sm.add_player(pid, _bodies[pid])
		_sm.set_frozen(pid, true)
	_t0 = Time.get_ticks_msec()
	_stepped = 0


func _on_packet(peer: int, bytes: PackedByteArray, i: int) -> void:
	if peer != PuppetMap.SERVER_PEER or HandleTable.is_message(bytes) or EventBatch.is_message(bytes):
		return
	var snap := SnapshotCodec.decode(bytes)
	assert_bool(snap.is_empty()).override_failure_message("client %d got a bad snapshot" % i).is_false()
	if snap.is_empty() or snap.tick <= _last_tick[i]:
		return
	_last_tick[i] = snap.tick
	var by_id := {}
	for b: Dictionary in snap.bodies:
		by_id[-1 if b.get("own", false) else b.id] = b
	_entries[i] = by_id


## The shapeshifter's body entry on client `i` (its own entry on the shapeshifter's client); {} if none.
func _monster_entry(i: int) -> Dictionary:
	if i == 0:
		return _entries[0].get(-1, {})
	var viewer := _clients[i].local_player_id
	if not _sm.scope.handles.has(viewer, _monster):
		return {}
	return _entries[i].get(_sm.scope.handles.handle_for(viewer, _monster), {})


## True when every client's latest snapshot shows the shapeshifter's body with transforming == `on`,
## and no survivor body anywhere carries the flag.
func _all_see(on: bool) -> bool:
	for i in CLIENTS:
		var e := _monster_entry(i)
		if e.is_empty() or e.get("transforming", not on) != on:
			return false
		for id: Variant in _entries[i]:
			var b: Dictionary = _entries[i][id]
			if b != e and b.get("transforming", false):
				return false
	return true


## Paces the server until every client shows `on`, at most BOUND_MS after `since`.
func _all_see_within_bound(on: bool, since: int, what: String) -> void:
	while not _all_see(on) and Time.get_ticks_msec() - since <= BOUND_MS:
		await get_tree().process_frame
		_paced_step()
	var shown: Array = []
	for i in CLIENTS:
		shown.append(_monster_entry(i).get("transforming"))
	assert_bool(_all_see(on)).override_failure_message(
		"%s not on every client within %d ms at 150 ms RTT: %s" % [what, BOUND_MS, shown]).is_true()


# --- AC 3 ----------------------------------------------------------------------

func test_every_client_sees_transforming_within_250_ms_of_acceptance_at_150_ms_rtt() -> void:
	await _start()
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while _stepped < _knobs.ticks(1.5) and Time.get_ticks_msec() < end: # observe every survivor; every client sees no transformation
		await get_tree().process_frame
		_paced_step()
	assert_bool(_bf.observed(_survivors[0])).is_true()
	await _until(func() -> bool: return _all_see(false), "not transforming everywhere")
	_bf.request_form_change(_monster, BorrowedFace.request_packet(_survivors[0]))
	while not _bf.transforming() and Time.get_ticks_msec() < end:
		await get_tree().process_frame
		_paced_step()
	assert_bool(_bf.transforming()).is_true()
	await _all_see_within_bound(true, Time.get_ticks_msec(), "transforming start")
	# Completion clears the flag on every client within the same bound.
	end = Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while _bf.transforming() and Time.get_ticks_msec() < end:
		await get_tree().process_frame
		_paced_step()
	assert_int(_bf.form()).is_equal(_survivors[0])
	await _all_see_within_bound(false, Time.get_ticks_msec(), "transforming end")
