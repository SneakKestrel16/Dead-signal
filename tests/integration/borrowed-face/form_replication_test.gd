# Story borrowed-face/007: form replication and reconnect (borrowed-face.md Interactions "Network
# Authority & Replication", Edge Cases "Shapeshifter disconnects while disguised", "Reconnecting
# survivor client"; TR-borrowedface-001, -002, -011; ADR-0004 §3-5, §9). The real-ENet case runs a
# RoundServer (out of the tree, so only step() advances it) with BorrowedFace and ServerMovement sending
# per-peer streams to five clients; each client's packets are decoded raw. Rendering is a stub: a
# client "renders" the appearance its latest snapshot gives the shapeshifter's body (Story 009 swaps
# the visual). Sight, status and characters are fed by the test.
extends GdUnitTestSuite

const VERSION := "test-1.0+bf7"
const WAIT_S := 5.0
## Story AC 1: every client renders the new form within 250 ms of FormChanged (127.0.0.1 only).
const FORM_BOUND_MS := 250
const CLIENTS := 5
const CHANGES := 10
## Index (into the survivors) of the client that reconnects mid-disguise.
const REJOINER := 2
## Keys a non-own snapshot entry may carry: appearance and presentation, never identity (AC 2).
const PUPPET_KEYS := ["appearance", "gait", "id", "pos", "transforming", "yaw"]

static var _next_port := 26700

class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0

var _knobs: Knobs
var _roots: Array[Node] = []
var _server: RoundServer
var _sm: ServerMovement
var _bf: BorrowedFace
var _net: NetAuthority
var _bodies := {}
var _clients: Array[NetAuthority] = []
var _monster := -1
var _survivors: Array[int] = []
## player -> character appearance id (ADR-0010 §2: 1-5 are C1-C5).
var _looks: Dictionary[int, int] = {}
## Per client: latest snapshot tick, entries by id, and event batches heard.
var _last_tick: Array[int] = []
var _entries: Array[Dictionary] = []
var _batches: Array[int] = []
## Every non-own entry a survivor client decoded for the shapeshifter's body (AC 2).
var _monster_entries: Array[Dictionary] = []
var _form_events: Array[EvFormChanged] = []
var _form_ms := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	# Shortest observation and cooldown in range so ten changes stay quick; transform duration stays the shipped 2 s.
	_knobs.borrowed_face = _knobs.borrowed_face.duplicate()
	_knobs.borrowed_face.observe_time_s = 1.0
	_knobs.borrowed_face.form_change_cooldown_s = 6.0
	_server = auto_free(RoundServer.new())
	_form_events.clear()
	_monster_entries.clear()


func after_test() -> void:
	if _sm != null:
		_sm.detach()
		_sm = null
	_server.end_round()
	_bf = null
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
	n.name = "Bf%d" % _roots.size()
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


func _new_bf() -> BorrowedFace:
	var bf := BorrowedFace.new()
	bf.set_roster(_survivors, _monster)
	# The shapeshifter at the origin faces -Z; every survivor stands 2 m in front, in plain sight.
	bf.set_sight_sources(func(_p: int) -> Vector3: return Vector3(0.0, 1.6, 0.0),
		func(_p: int) -> float: return 0.0,
		func(_p: int) -> PackedVector3Array: return PackedVector3Array(
			[Vector3(0.0, 1.7, -2.0), Vector3(0.0, 1.5, -2.0), Vector3(0.0, 1.0, -2.0)]),
		func(_e: Vector3, _q: Vector3) -> bool: return true,
		func(_p: int) -> bool: return false)
	bf.set_status_source(func(_p: int) -> int: return MatchFlow.Status.HEALTHY)
	bf.set_appearance_source(func(p: int) -> int: return _looks[p])
	return bf


## Hosts, joins five clients (raw packet recorders) and starts the round; the first joined player is
## the shapeshifter. Every body stands within relevance_near_m of every other, frozen.
func _start() -> void:
	var server_root := _root()
	_net = NetAuthority.new()
	_net.setup(_knobs, VERSION, FakeLobby.new())
	server_root.add_child(_net)
	_next_port += 1
	assert_int(_net.host(_next_port)).is_equal(OK)
	var joined := func(pid: int) -> void:
		_bodies[pid] = TestMoveStep.make_body(server_root, Vector3(0.5 * _bodies.size(), 0.0, -1.0))
	_net.player_joined.connect(joined)
	for i in CLIENTS:
		var root := _root()
		var c := NetAuthority.new()
		c.setup(_knobs, VERSION, FakeLobby.new())
		root.add_child(c)
		assert_int(c.join("127.0.0.1", _next_port, "P%d" % i)).is_equal(OK)
		_clients.append(c)
		_last_tick.append(-1)
		_entries.append({})
		_batches.append(0)
		(root.multiplayer as SceneMultiplayer).peer_packet.connect(_on_packet.bind(i))
	await _until(func() -> bool:
		return _bodies.size() == CLIENTS and _clients.all(func(c: NetAuthority) -> bool: return c.local_player_id != -1),
		"all joined")
	_monster = _clients[0].local_player_id
	_survivors.assign([])
	for c in _clients.slice(1):
		_survivors.append(c.local_player_id)
	for k in _survivors.size():
		_looks[_survivors[k]] = k + 1
	_looks[_monster] = 5
	_bf = _new_bf()
	assert_array(_server.start_round({TickOrder.BORROWED_FACE: _bf}, _knobs)).is_empty()
	_server.bus.subscribe(&"FormChanged", _on_form_changed)
	_sm = ServerMovement.new(_knobs, _net, server_root.multiplayer as SceneMultiplayer, TestMoveStep.apply,
		TestMoveStep.WORLD)
	_sm.attach(_server.tick_runner)
	_sm.monster = _monster
	_sm.appearance_of = _bf.appearance_of
	_sm.catch_up.append(_bf.catch_up)
	_bf.on_form_event = _sm.scope.form_changed
	for pid: int in _bodies:
		_sm.add_player(pid, _bodies[pid])
		_sm.set_frozen(pid, true)


func _on_form_changed(e: ServerEvent) -> void:
	_form_events.append(e as EvFormChanged)
	_form_ms = Time.get_ticks_msec()


func _on_packet(peer: int, bytes: PackedByteArray, i: int) -> void:
	if peer != PuppetMap.SERVER_PEER or HandleTable.is_message(bytes):
		return
	if EventBatch.is_message(bytes):
		_batches[i] += 1
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
	if i > 0 and _sm != null and _sm.scope.handles.has(_clients[i].local_player_id, _monster):
		var h := _sm.scope.handles.handle_for(_clients[i].local_player_id, _monster)
		if by_id.has(h):
			_monster_entries.append(by_id[h])


## The appearance client `i` renders for the shapeshifter's body: its own entry on the shapeshifter's
## client, the entry under its handle elsewhere; -1 when it shows no such body.
func _rendered(i: int) -> int:
	if i == 0:
		return _entries[0].get(-1, {}).get("appearance", -1)
	var viewer := _clients[i].local_player_id
	if viewer == -1 or not _sm.scope.handles.has(viewer, _monster):
		return -1
	var h := _sm.scope.handles.handle_for(viewer, _monster)
	return _entries[i].get(h, {}).get("appearance", -1)


func _expected() -> int:
	return CharacterDef.TRUE_FORM_APPEARANCE_ID if _bf.form() == BorrowedFace.TRUE_FORM else _looks[_bf.form()]


func _all_render(look: int) -> bool:
	for i in CLIENTS:
		if _rendered(i) != look:
			return false
	return true


## Requests `form` until a transformation into it completes; returns the wall ms of its FormChanged.
func _change_to(form: int) -> int:
	var before := _form_events.size()
	for t in _knobs.ticks(15.0):
		if not _bf.transforming():
			_bf.request_form_change(_monster, BorrowedFace.request_packet(form))
		_server.tick_runner.step()
		_poll()
		if _form_events.size() > before:
			break
	assert_int(_form_events.size()).is_equal(before + 1)
	assert_int(_bf.form()).is_equal(form)
	return _form_ms


## Steps and polls the server until every client renders the current form, at most FORM_BOUND_MS
## after `since`.
func _all_see_within_bound(since: int) -> void:
	var look := _expected()
	while not _all_render(look) and Time.get_ticks_msec() - since <= FORM_BOUND_MS:
		_server.tick_runner.step()
		_poll()
		await get_tree().process_frame
		_poll()
	var shown: Array[int] = []
	for i in CLIENTS:
		shown.append(_rendered(i))
	assert_bool(_all_render(look)).override_failure_message(
		"form %d (appearance %d) not on every client within %d ms: %s" % [_bf.form(), look, FORM_BOUND_MS, shown]).is_true()


func _reconnect(i: int) -> void:
	var c := _clients[i]
	var pid := c.local_player_id
	var token := c.local_token
	c.close()
	await _until(func() -> bool: return _net.peer_id_of(pid) == -1, "server saw the drop")
	_last_tick[i] = -1
	_entries[i] = {}
	assert_int(c.join("127.0.0.1", _next_port, "P%d" % i, token)).is_equal(OK)
	await _until(func() -> bool: return c.local_player_id == pid, "rejoin as the same player")


# --- AC 1 and 2: ten changes on five clients, one reconnecting mid-disguise ---

func test_ten_form_changes_reach_all_five_clients_within_250_ms_with_appearance_only() -> void:
	await _start()
	for t in _knobs.ticks(1.5): # observation (1 s) of every survivor; every client sees true form
		_server.tick_runner.step()
		_poll()
	for s in _survivors:
		assert_bool(_bf.observed(s)).is_true()
	await _until(func() -> bool: return _all_render(CharacterDef.TRUE_FORM_APPEARANCE_ID), "true form everywhere")
	var s := _survivors
	var forms: Array[int] = [s[0], s[1], BorrowedFace.TRUE_FORM, s[2], s[3], BorrowedFace.TRUE_FORM, s[0], s[2],
		BorrowedFace.TRUE_FORM, s[1]]
	var monster_batches := _batches[0]
	for n in CHANGES:
		if n == 4: # disguised as s[2] here: a survivor client reconnects mid-disguise
			await _reconnect(REJOINER)
			var since := Time.get_ticks_msec()
			await _all_see_within_bound(since)
		await _all_see_within_bound(_change_to(forms[n]))
	assert_int(_form_events.size()).is_equal(CHANGES)
	# AC 2: survivor clients heard no FormChanged and decoded only appearance and presentation for the
	# shapeshifter's body; the shapeshifter's own client heard its own form each time.
	for i in range(1, CLIENTS):
		assert_int(_batches[i]).is_equal(0)
	assert_int(_batches[0] - monster_batches).is_equal(CHANGES)
	assert_bool(_monster_entries.is_empty()).is_false()
	for e: Dictionary in _monster_entries:
		var keys: Array = e.keys()
		keys.sort()
		assert_array(keys).is_equal(PUPPET_KEYS)
		assert_bool(e.id == _monster).is_false()
	# The capsule is the same in every form: Borrowed Face never touches the body's shape.
	var cap := (_bodies[_monster] as CharacterBody3D).get_child(0) as CollisionShape3D
	assert_object(cap).is_not_null()
	var sample := _sm.history.sample(_monster, _server.tick_runner.current_tick() - 1)
	assert_float(sample.height).is_equal((cap.shape as CapsuleShape3D).height)


# --- AC 3: the shapeshifter disconnects while disguised -----------------------

func test_shapeshifter_disconnecting_while_disguised_returns_in_true_form_with_observed_kept() -> void:
	_monster = 1
	_survivors.assign([2, 3, 4, 5])
	_looks = {1: 5, 2: 1, 3: 2, 4: 3, 5: 4}
	_bf = _new_bf()
	var events: Array[Dictionary] = []
	assert_array(_server.start_round({TickOrder.BORROWED_FACE: _bf}, _knobs)).is_empty()
	_server.bus.subscribe(&"FormChanged", _on_form_changed)
	for t in _knobs.ticks(1.5):
		_server.tick_runner.step()
	_change_to(3)
	var obs := {}
	for p in _survivors:
		obs[p] = _bf.observation_s(p)
	# A transformation in progress at the drop is discarded too (requested once the cooldown is over).
	for t in _knobs.ticks(_knobs.borrowed_face.form_change_cooldown_s):
		_server.tick_runner.step()
	_bf.request_form_change(_monster, BorrowedFace.request_packet(4))
	_server.tick_runner.step()
	assert_bool(_bf.transforming()).is_true()
	var changes := _form_events.size()
	for status in [EvPlayerConnectionChanged.DISCONNECTED, EvPlayerConnectionChanged.RECONNECTED]:
		var e := EvPlayerConnectionChanged.new()
		e.player = _monster
		e.status = status
		_server.bus.emit(e)
		_server.tick_runner.step()
		assert_int(_bf.form()).is_equal(BorrowedFace.TRUE_FORM)
		assert_bool(_bf.transforming()).is_false()
		assert_int(_bf.appearance_of(_monster)).is_equal(CharacterDef.TRUE_FORM_APPEARANCE_ID)
	for t in _knobs.ticks(3.0): # nothing completes later from the discarded transformation
		_server.tick_runner.step()
	assert_int(_bf.form()).is_equal(BorrowedFace.TRUE_FORM)
	assert_int(_form_events.size()).is_equal(changes) # no completed change, so no FormChanged
	for p in _survivors:
		assert_float(_bf.observation_s(p)).is_equal(obs[p])
		assert_bool(_bf.observed(p)).is_true()
	# Catch-up (ADR-0004 §9): the rejoining shapeshifter's client hears its own true form; survivors nothing.
	for e: ServerEvent in _bf.catch_up():
		events.append(e.project(_monster, HandleTable.new(), _monster))
		assert_dict(e.project(2, HandleTable.new(), _monster)).is_empty()
	assert_array(events).is_equal([{"form": BorrowedFace.TRUE_FORM}])
	# Survivors keep their own looks; a disguise shows the copied survivor's.
	assert_int(_bf.appearance_of(2)).is_equal(1)
	_change_to(2)
	assert_int(_bf.appearance_of(_monster)).is_equal(_looks[2])
