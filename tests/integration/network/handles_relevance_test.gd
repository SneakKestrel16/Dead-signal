# Story network-authority/008: per-peer handles and relevance (ADR-0004 §2-4).
# Scope cases drive ReplicationScope and a client PuppetMap through the real wire formats
# (HandleTable.encode, SnapshotCodec.encode) on a hand-built test map. The capture case runs a server
# and two clients over real ENet on 127.0.0.1 and decodes every packet the survivor's client receives.
extends GdUnitTestSuite

const SERVER_VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
const SEED := 8008
const VIEWER := 1
const BODY := 2
## Test map: three 10 m rooms along x with 10 m gaps, so a body in another room is beyond
## relevance_near_m (6 m). R1 sees R2 through door D12; nothing sees R3.
const R1 := Vector3(5.0, 0.0, 5.0)
const R2 := Vector3(25.0, 0.0, 5.0)
const R3 := Vector3(45.0, 0.0, 5.0)

static var _next_port := 25800

class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0

var _knobs: Knobs
var _linger: int
var _door_closed := false
var _roots: Array[Node] = []
var _runner: TickRunner
var _sm: ServerMovement


func before_test() -> void:
	_knobs = Knobs.load_all()
	_linger = _knobs.ticks(_knobs.net.relevance_linger_s)
	_door_closed = false


func after_test() -> void:
	if _sm != null:
		_sm.detach()
		_sm = null
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
	if _runner != null:
		_runner.free()
		_runner = null


# --- rig: scope + puppet map --------------------------------------------------

func _volume(id: StringName, x: float, sees: Dictionary[StringName, StringName]) -> MapVolume:
	var v := MapVolume.new()
	v.id = id
	v.room = id
	v.box = AABB(Vector3(x, 0.0, 0.0), Vector3(10.0, 3.0, 10.0))
	v.sees = sees
	return v


func _queries() -> MapQueries:
	var map := MapData.new()
	map.volumes.assign([_volume(&"R1", 0.0, {&"R2": &"D12"}), _volume(&"R2", 20.0, {&"R1": &"D12"}),
		_volume(&"R3", 40.0, {})])
	return MapQueries.new(map)


func _scope() -> ReplicationScope:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var scope := ReplicationScope.new(_knobs, rng)
	var q := _queries()
	scope.relevance.volume_at = q.volume_at
	scope.relevance.visible_volumes = func(v: StringName) -> PackedStringArray:
		return q.visible_set(v, func(_door: StringName) -> bool: return _door_closed)
	return scope


## One send phase for `viewer`: its handle messages, then its snapshot, into its puppet map. Returns
## every handle introduced to it this tick.
func _send(scope: ReplicationScope, puppets: PuppetMap, tick: int, viewer: int, positions: Dictionary) -> Array[int]:
	var seen := scope.bodies_for(tick, viewer, positions)
	var msgs := scope.handles.take(viewer)
	var introduced: Array[int] = []
	for i in range(0, msgs.size(), 2):
		if msgs[i] == HandleTable.INTRODUCE:
			introduced.append(msgs[i + 1])
	if not msgs.is_empty():
		puppets.receive(HandleTable.encode(msgs))
	var bodies: Array[Dictionary] = []
	for body: int in seen:
		bodies.append({"id": seen[body], "pos": positions[body], "yaw": 0.0, "gait": 0})
	puppets.receive(SnapshotCodec.encode(tick, bodies))
	return introduced


## Runs `ticks` send phases from `tick` with BODY at `at`; returns the next tick. `all_seen` gathers
## every handle the client was introduced to.
func _run(scope: ReplicationScope, puppets: PuppetMap, tick: int, ticks: int, at: Vector3, all_seen: Array[int]) -> int:
	for i in ticks:
		all_seen.append_array(_send(scope, puppets, tick + i, VIEWER, {VIEWER: R1, BODY: at}))
	return tick + ticks


## The handle the client currently shows BODY under (the one live handle), or 0.
func _shown(puppets: PuppetMap) -> int:
	return puppets.handles()[0] if puppets.handles().size() == 1 else 0


# --- AC1: re-entry is a stranger ----------------------------------------------

func test_body_out_of_view_for_1_s_returns_under_a_never_seen_handle() -> void:
	var scope := _scope()
	var puppets := PuppetMap.new()
	var seen: Array[int] = []
	var t := _run(scope, puppets, 0, 10, R2, seen) ## R2 is in R1's set (door open)
	var first := _shown(puppets)
	assert_int(first).is_not_equal(0)
	t = _run(scope, puppets, t, _knobs.ticks(1.0), R3, seen) ## out of the set and beyond 6 m for 1 s
	assert_array(puppets.handles()).is_empty() ## retired once the linger ran out
	var before := seen.duplicate()
	_run(scope, puppets, t, 1, R2, seen)
	var again := _shown(puppets)
	assert_int(again).is_not_equal(0)
	assert_bool(again in before).override_failure_message("re-entry reused handle %d" % again).is_false()


func test_a_gap_bridged_by_linger_keeps_the_handle() -> void:
	var scope := _scope()
	var puppets := PuppetMap.new()
	var seen: Array[int] = []
	var t := _run(scope, puppets, 0, 5, R2, seen)
	var first := _shown(puppets)
	t = _run(scope, puppets, t, _linger, R3, seen) ## last qualifying tick + linger: still relevant
	assert_int(_shown(puppets)).is_equal(first)
	_run(scope, puppets, t, 1, R2, seen)
	assert_int(_shown(puppets)).is_equal(first)


func test_one_tick_past_the_linger_retires_and_reenters_fresh() -> void:
	var scope := _scope()
	var puppets := PuppetMap.new()
	var seen: Array[int] = []
	var t := _run(scope, puppets, 0, 5, R2, seen)
	var first := _shown(puppets)
	t = _run(scope, puppets, t, _linger + 1, R3, seen)
	assert_array(puppets.handles()).is_empty()
	_run(scope, puppets, t, 1, R2, seen)
	assert_int(_shown(puppets)).is_not_equal(0).is_not_equal(first)


# --- AC2: form change ---------------------------------------------------------

func test_form_change_during_linger_retires_the_handle() -> void:
	var scope := _scope()
	var puppets := PuppetMap.new()
	var seen: Array[int] = []
	var t := _run(scope, puppets, 0, 5, R2, seen)
	t = _run(scope, puppets, t, 3, R3, seen) ## lingering
	assert_bool(scope.relevance.is_lingering(VIEWER, BODY)).is_true()
	var first := _shown(puppets)
	scope.form_changed(BODY)
	_run(scope, puppets, t, 1, R3, seen)
	assert_bool(puppets.has(first)).is_false()
	assert_array(puppets.handles()).is_empty() ## the linger ended too: not re-issued while out of view


func test_form_change_in_view_keeps_the_handle() -> void:
	var scope := _scope()
	var puppets := PuppetMap.new()
	var seen: Array[int] = []
	var t := _run(scope, puppets, 0, 5, R2, seen)
	var first := _shown(puppets)
	scope.form_changed(BODY)
	_run(scope, puppets, t, 5, R2, seen)
	assert_int(_shown(puppets)).is_equal(first)
	assert_int(seen.size()).is_equal(1)


# --- AC3: unintroduced handles ------------------------------------------------

func test_snapshot_entry_with_an_unintroduced_handle_is_ignored() -> void:
	var puppets := PuppetMap.new()
	var entry := {"id": 12345, "pos": R2, "yaw": 0.0, "gait": 0}
	puppets.receive(SnapshotCodec.encode(1, [entry] as Array[Dictionary]))
	assert_array(puppets.handles()).is_empty()
	assert_int(puppets.ignored_entries).is_equal(1)
	puppets.receive(HandleTable.encode(PackedInt64Array([HandleTable.INTRODUCE, 12345])))
	puppets.receive(SnapshotCodec.encode(2, [entry] as Array[Dictionary]))
	assert_vector(puppets.state_of(12345).pos).is_equal(R2)
	puppets.receive(HandleTable.encode(PackedInt64Array([HandleTable.RETIRE, 12345])))
	puppets.receive(SnapshotCodec.encode(3, [entry] as Array[Dictionary]))
	assert_bool(puppets.has(12345)).is_false()
	assert_int(puppets.ignored_entries).is_equal(2)


func test_bad_handle_messages_change_nothing() -> void:
	var puppets := PuppetMap.new()
	for bad: PackedInt64Array in [PackedInt64Array([HandleTable.INTRODUCE, 0]), PackedInt64Array([9, 77])]:
		puppets.receive(HandleTable.encode(bad))
	var cut := HandleTable.encode(PackedInt64Array([HandleTable.INTRODUCE, 77]))
	cut.resize(cut.size() - 1)
	puppets.receive(cut)
	assert_array(puppets.handles()).is_empty()
	assert_int(puppets.bad_packets).is_equal(3)


# --- relevance rules ----------------------------------------------------------

func test_pvs_near_and_door_rules() -> void:
	var scope := _scope()
	var rel := scope.relevance
	assert_array(rel.update(0, VIEWER, {VIEWER: R1, BODY: R2})).contains_exactly([BODY]) ## in the set, 20 m
	assert_array(rel.update(100, VIEWER, {VIEWER: R1, BODY: R3})).is_empty() ## not in the set, 40 m
	assert_array(rel.update(200, VIEWER, {VIEWER: Vector3(9.9, 0, 5), BODY: Vector3(15.0, 0, 5)})) \
		.contains_exactly([BODY]) ## in no volume, 5.1 m: the near rule
	_door_closed = true
	assert_array(rel.update(300, VIEWER, {VIEWER: R1, BODY: R2})).is_empty() ## the closed door cuts R2


func test_hidden_body_is_never_relevant_and_does_not_linger() -> void:
	var scope := _scope()
	var hidden := [false]
	scope.relevance.hidden_from = func(_viewer: int, _body: int) -> bool: return hidden[0]
	var near := R1 + Vector3(1.0, 0.0, 0.0)
	assert_dict(scope.bodies_for(0, VIEWER, {VIEWER: R1, BODY: near})).is_not_empty()
	hidden[0] = true
	assert_dict(scope.bodies_for(1, VIEWER, {VIEWER: R1, BODY: near})).is_empty()
	var msgs := scope.handles.take(VIEWER)
	assert_int(msgs[msgs.size() - 2]).is_equal(HandleTable.RETIRE)


func test_handles_are_nonzero_and_differ_per_viewer() -> void:
	var scope := _scope()
	var positions := {1: R1, 2: R1 + Vector3.RIGHT, 3: R1 + Vector3.BACK}
	var a := scope.bodies_for(0, 1, positions)
	var b := scope.bodies_for(0, 3, positions)
	assert_int(a[2]).is_not_equal(0).is_not_equal(b[2]).is_not_equal(2)
	assert_int(b[2]).is_not_equal(0).is_not_equal(2)
	assert_bool(a[2] >= 0 and a[2] <= 0xFFFFFFFF).is_true()


# --- AC4: survivor capture over real ENet -------------------------------------

func _root() -> Node:
	var n := Node.new()
	n.name = "Hr%d" % _roots.size()
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


## A scripted sequence: the monster walks into the survivor's view, out for 1 s, back, changes form in
## view and while lingering. Every packet the survivor's client receives is decoded: no field carries
## the monster's player ID; snapshot ids are the survivor's own ID or handles it was introduced to.
func test_survivor_capture_carries_no_monster_player_id() -> void:
	var server_root := _root()
	var server := NetAuthority.new()
	server.setup(_knobs, SERVER_VERSION, FakeLobby.new())
	server_root.add_child(server)
	_next_port += 1
	assert_int(server.host(_next_port)).is_equal(OK)
	_runner = TickRunner.new()
	_runner.fail_hard = false
	_runner.boot(_knobs)
	_runner.bus = EventBus.new(_knobs.core.max_flush_rounds)
	_sm = ServerMovement.new(_knobs, server, server_root.multiplayer as SceneMultiplayer, TestMoveStep.apply, TestMoveStep.WORLD)
	_sm.attach(_runner)
	_sm.scope = _scope()
	var bodies := {}
	server.player_joined.connect(func(pid: int) -> void:
		bodies[pid] = TestMoveStep.make_body(server_root, R1)
		_sm.add_player(pid, bodies[pid])
		_sm.set_frozen(pid, true))
	var clients: Array[NetAuthority] = []
	for name in ["Survivor", "Monster"]:
		var root := _root()
		var net := NetAuthority.new()
		net.setup(_knobs, SERVER_VERSION, FakeLobby.new())
		root.add_child(net)
		assert_int(net.join("127.0.0.1", _next_port, name)).is_equal(OK)
		clients.append(net)
	await _until(func() -> bool: return bodies.size() == 2 and clients[0].local_player_id != -1 and clients[1].local_player_id != -1, "both joined")
	var survivor := clients[0].local_player_id
	var monster := clients[1].local_player_id
	_sm.monster = monster
	var capture: Array[PackedByteArray] = []
	var survivor_api := clients[0].multiplayer as SceneMultiplayer
	survivor_api.peer_packet.connect(func(_peer: int, bytes: PackedByteArray) -> void: capture.append(bytes))
	var puppets := PuppetMap.new(survivor_api)
	var body: CharacterBody3D = bodies[monster]
	for leg: Array in [[R2, 20], [R3, _knobs.ticks(1.0)], [R2, 20], [&"form", 1], [R2, 5], [R3, 3], [&"form", 1], [R1, 10]]:
		for i in leg[1]:
			if leg[0] is StringName:
				_sm.scope.form_changed(monster)
			else:
				body.global_position = leg[0]
			_emit_monster_events(monster, survivor, body.global_position)
			_runner.step()
			_poll()
			await get_tree().process_frame
			_poll()
	await _until(func() -> bool: return capture.size() > 60, "snapshots")
	puppets.close()
	var introduced := {}
	var snapshot_ids := {}
	var snapshots := 0
	var batches := 0
	var seen_types := {}
	var max_bytes := 0
	for bytes in capture:
		if EventBatch.is_message(bytes): # NA-9: every event batch is decoded too
			var batch := EventBatch.decode(bytes)
			assert_dict(batch).is_not_empty()
			batches += 1
			for entry: Array in batch.entries:
				seen_types[entry[0]] = true
				assert_bool(entry[0] in [&"PlayerShocked", &"MonsterStunned", EventBatch.SOUND]) 					.override_failure_message("survivor got %s" % entry[0]).is_true()
				assert_bool(_carries_int(entry[1], monster)).override_failure_message(str(entry)).is_false()
			continue
		if HandleTable.is_message(bytes):
			var msgs := HandleTable.decode(bytes)
			assert_int(msgs.size()).is_greater(0)
			for i in range(0, msgs.size(), 2):
				assert_int(msgs[i + 1]).is_not_equal(monster)
				introduced[msgs[i + 1]] = true
			continue
		var snap := SnapshotCodec.decode(bytes)
		assert_dict(snap).override_failure_message("undecodable packet: %s" % bytes.hex_encode()).is_not_empty()
		snapshots += 1
		max_bytes = maxi(max_bytes, bytes.size())
		for b: Dictionary in snap.bodies:
			if b.get("own", false):
				assert_int(b.id).is_equal(survivor)
			else:
				assert_int(b.id).is_not_equal(monster)
				snapshot_ids[b.id] = true
	# Every id a snapshot used was introduced (checked over the whole capture: EVENT and STATE are not
	# ordered against each other).
	for id: int in snapshot_ids:
		assert_bool(introduced.has(id)).override_failure_message("snapshot id %d never introduced" % id).is_true()
	assert_int(snapshots).is_greater(60)
	assert_int(batches).is_greater(0)
	# Projected events really arrive through ServerMovement, not only the footstep.
	assert_bool(seen_types.has(&"PlayerShocked")).is_true()
	assert_bool(seen_types.has(&"MonsterStunned")).is_true()
	assert_int(introduced.size()).is_greater_equal(2) ## re-entry after 1 s out came back as a stranger
	assert_bool(introduced.has(monster)).is_false()
	prints("NA-8 largest survivor snapshot:", max_bytes, "B (guardrail about 200 B per peer)")


## Each tick of the capture, the monster is shocked, stunned while disguised, changes form, uses an
## ability and hits the survivor, and makes a sound at its position (NA-9).
func _emit_monster_events(monster: int, survivor: int, at: Vector3) -> void:
	var shocked := EvPlayerShocked.new()
	shocked.player = monster
	var stunned := EvMonsterStunned.new()
	stunned.monster = monster
	stunned.true_form = true # by handle while relevant; a disguised stun would reach no survivor
	var form := EvFormChanged.new()
	form.player = monster
	var hit := EvSurvivorHit.new()
	hit.survivor = survivor
	for e: ServerEvent in [shocked, stunned, form, EvAbilityUsed.new(), hit]:
		_runner.bus.emit(e)
	_sm.emit_sound(at, &"steps_c2", _knobs.controller.footstep_radius_sprint_m, monster)


## True when `v` (a payload, nested) holds the int `id` anywhere.
func _carries_int(v: Variant, id: int) -> bool:
	if v is Dictionary:
		for k: Variant in v:
			if _carries_int(k, id) or _carries_int(v[k], id):
				return true
	elif v is Array:
		for x: Variant in v:
			if _carries_int(x, id):
				return true
	return typeof(v) == TYPE_INT and v == id


# --- Code review 2026-10-14: rules the first pass left untested ----------------

func test_handle_0_and_repeats_are_never_issued() -> void:
	var handles := HandleTable.new()
	var next := [0, 5, 0, 5, 5, 7]
	handles.source = func() -> int: return next.pop_front()
	assert_int(handles.handle_for(VIEWER, 2)).is_equal(5)
	assert_int(handles.handle_for(VIEWER, 3)).is_equal(7) ## 0 and the live 5 skipped
	handles.retire(VIEWER, 2)
	next.assign([5, 9])
	assert_int(handles.handle_for(VIEWER, 2)).is_equal(9) ## a retired handle is not issued again


func test_a_far_body_in_the_viewers_own_volume_is_relevant() -> void:
	var rel := _scope().relevance
	assert_array(rel.update(0, VIEWER, {VIEWER: Vector3(0.5, 0, 5), BODY: Vector3(9.5, 0, 5)})).contains_exactly([BODY])


func test_viewer_outside_every_volume_sees_only_near_bodies() -> void:
	var rel := _scope().relevance
	assert_array(rel.update(0, VIEWER, {VIEWER: Vector3(15.0, 0, 5), BODY: R2 + Vector3(4.0, 0, 0)})).is_empty()


func test_a_door_closing_on_a_live_handle_retires_it_after_the_linger() -> void:
	var scope := _scope()
	var puppets := PuppetMap.new()
	var seen: Array[int] = []
	var t := _run(scope, puppets, 0, 5, R2, seen)
	_door_closed = true
	t = _run(scope, puppets, t, _linger, R2, seen)
	assert_int(puppets.handles().size()).is_equal(1) ## lingering
	_run(scope, puppets, t, 1, R2, seen)
	assert_array(puppets.handles()).is_empty()


func test_hidden_rule_is_per_viewer_and_return_is_a_stranger() -> void:
	var scope := _scope()
	const MONSTER := 3
	var hidden := [false]
	scope.relevance.hidden_from = func(viewer: int, body: int) -> bool: return hidden[0] and viewer == MONSTER and body == BODY
	var positions := {VIEWER: R1, BODY: R1 + Vector3.RIGHT, MONSTER: R1 + Vector3.BACK}
	var first: int = scope.bodies_for(0, MONSTER, positions)[BODY]
	hidden[0] = true
	assert_bool(scope.bodies_for(1, MONSTER, positions).has(BODY)).is_false()
	assert_bool(scope.bodies_for(1, VIEWER, positions).has(BODY)).is_true() ## another survivor still sees it
	hidden[0] = false
	assert_int(scope.bodies_for(2, MONSTER, positions)[BODY]).is_not_equal(first)


func test_bodies_are_listed_in_handle_order_not_join_order() -> void:
	var scope := _scope()
	var next := [900, 100, 700, 300, 500]
	scope.handles.source = func() -> int: return next.pop_front()
	var positions := {VIEWER: R1}
	for b in range(2, 7):
		positions[b] = R1 + Vector3(0.1 * b, 0, 0)
	assert_array(scope.bodies_for(0, VIEWER, positions).values()).is_equal([100, 300, 500, 700, 900])
	var msgs := scope.handles.take(VIEWER)
	assert_array(Array(msgs)).is_equal([1, 100, 1, 300, 1, 500, 1, 700, 1, 900])


func test_a_removed_player_does_not_linger_when_its_id_returns() -> void:
	var scope := _scope()
	scope.bodies_for(0, VIEWER, {VIEWER: R1, BODY: R2})
	scope.remove_player(BODY)
	assert_dict(scope.bodies_for(1, VIEWER, {VIEWER: R1, BODY: R3})).is_empty()
