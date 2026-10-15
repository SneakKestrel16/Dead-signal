# Story match-flow/011 (AD-201; ADR-0002, ADR-0004, ADR-0010 minimal): RoundClient joins a composed round
# over real ENet, predicts its own body onto the greybox floor at the server's spawn, and draws every remote
# body it is sent, by handle, in its appearance colour; a handle missing from the newest snapshot (a hidden
# survivor, a body out of scope) is not drawn; a flashlight toggled on one client shows its cone on another.
# A survivor aimed at a hiding spot starts its Hide hold through the map index (AD-217); the bar's look is
# the round_view capture (production/qa/evidence/predicted-hold-bar-evidence.md).
extends GdUnitTestSuite

const WAIT_S := 8.0

static var _next_port := 28650

var _knobs: Knobs
var _roots: Array[Node] = []
var _clients: Array[RoundClient] = []
var _c: RoundComposer
var _net: NetAuthority


class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	Engine.physics_ticks_per_second = _knobs.net.sim_tick_hz
	_clients = []


func after_test() -> void:
	if _c != null:
		_c.stop()
		_c = null
	for c in _clients:
		c.close()
	await get_tree().process_frame
	for r in _roots + _clients:
		if not is_instance_valid(r):
			continue
		var api := r.multiplayer as SceneMultiplayer
		if api != null and api.multiplayer_peer != null:
			api.multiplayer_peer.close()
			api.multiplayer_peer = null
		get_tree().set_multiplayer(null, r.get_path())
		r.free()
	_roots.clear()
	_clients.clear()


func _info(token: String) -> Dictionary:
	var pid := token.trim_prefix("t").to_int()
	return {"player_id": pid, "name": "P%d" % pid}


func _look(id: int) -> int:
	return 1 + id % 5


func _until(cond: Callable, what: String) -> void:
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while Time.get_ticks_msec() < end and not cond.call():
		await get_tree().physics_frame
	assert_bool(cond.call()).override_failure_message("timeout waiting for " + what).is_true()


func _offline() -> RoundClient:
	var c := RoundClient.new(_knobs, TestMoveStep.apply, TestMoveStep.make_body, MapData.load_map(), false)
	add_child(c)
	_clients.append(c)
	c.puppets = PuppetMap.new()
	return c


## Feeds one packet to both the PuppetMap and the client, in that order (as peer_packet does).
func _feed(c: RoundClient, bytes: PackedByteArray) -> void:
	c.puppets.receive(bytes)
	c.receive(bytes)


func _entry(handle: int, pos: Vector3, appearance: int, light: bool) -> Dictionary:
	return {"id": handle, "pos": pos, "yaw": 0.0, "gait": 0, "appearance": appearance, "flashlight": light}


func test_remote_bodies_drawn_by_handle_in_appearance_colour_and_hidden_not_drawn() -> void:
	var c := _offline()
	_feed(c, HandleTable.encode(PackedInt64Array([HandleTable.INTRODUCE, 7, HandleTable.INTRODUCE, 9])))
	_feed(c, SnapshotCodec.encode(1, [_entry(7, Vector3(1, 0, 0), 2, true), _entry(9, Vector3(4, 0, 0), 0, false)]))
	c._process(0.016)
	assert_int(c.remotes.size()).is_equal(2)
	var a := c.remotes[7]
	var b := c.remotes[9]
	assert_bool(a.visible and b.visible).is_true()
	var mat_a := (a.get_node(^"Mesh") as MeshInstance3D).material_override as StandardMaterial3D
	var mat_b := (b.get_node(^"Mesh") as MeshInstance3D).material_override as StandardMaterial3D
	assert_object(mat_a.albedo_color).is_equal(c.colour_of(2))
	assert_object(mat_b.albedo_color).is_equal(RoundClient.TRUE_FORM_COLOUR)
	assert_bool(c.colour_of(2) != c.colour_of(3)).is_true()
	assert_bool((a.get_node(^"Cone") as SpotLight3D).visible).is_true()
	assert_bool((b.get_node(^"Cone") as SpotLight3D).visible).is_false()
	# Handle 7 hides (not sent any more): it is not drawn; 9 still is.
	_feed(c, SnapshotCodec.encode(2, [_entry(9, Vector3(5, 0, 0), 0, false)]))
	c._process(0.016)
	assert_bool(a.visible).is_false()
	assert_bool(b.visible).is_true()
	# A retired handle loses its node.
	_feed(c, HandleTable.encode(PackedInt64Array([HandleTable.RETIRE, 9])))
	c._process(0.016)
	assert_bool(c.remotes.has(9)).is_false()


func test_sample_interpolates_between_snapshots_and_caps_extrapolation() -> void:
	var buf := [[0.0, Vector3.ZERO, 0.0], [100.0, Vector3(10, 0, 0), 1.0]]
	var mid := RoundClient.sample(buf, 50.0, 20.0)
	assert_vector(mid[0]).is_equal_approx(Vector3(5, 0, 0), Vector3.ONE * 1e-4)
	assert_float(mid[1]).is_equal_approx(0.5, 1e-4)
	assert_vector(RoundClient.sample(buf, -5.0, 20.0)[0]).is_equal(Vector3.ZERO)
	# 300 ms past the newest, capped at 20 ms of extrapolation at 0.1 m/ms.
	assert_vector(RoundClient.sample(buf, 400.0, 20.0)[0]).is_equal_approx(Vector3(12, 0, 0), Vector3.ONE * 1e-4)


func test_five_clients_join_composed_round_predict_and_see_each_other() -> void:
	var server_root := Node3D.new()
	server_root.name = "Host"
	get_tree().root.add_child(server_root)
	_roots.append(server_root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), server_root.get_path())
	var map := MapData.load_map()
	MapGreybox.build(server_root, map)
	var version := _knobs.join_version(RoundClient.VERSION_BUILD)
	_net = NetAuthority.new()
	_net.setup(_knobs, version, FakeLobby.new())
	server_root.add_child(_net)
	_next_port += 1
	assert_int(_net.host(_next_port)).is_equal(OK)
	for i in 5:
		var c := RoundClient.new(_knobs, TestMoveStep.apply, TestMoveStep.make_body, map, false)
		c.name = "C%d" % i
		get_tree().root.add_child(c)
		_clients.append(c)
		assert_int(c.join("127.0.0.1", _next_port, "P%d" % i)).is_equal(OK)
		c.scripted = InputFrame.new()
	await _until(func() -> bool: return _clients.all(func(c: RoundClient) -> bool: return c.is_ready()), "5 joined")
	var tokens := PackedStringArray()
	for c in _clients:
		tokens.append("t%d" % c.net.local_player_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var roster := Roster.lock(tokens, _info, "s-mf11", 1, _knobs, RotationQueue.new(), rng)
	_c = RoundComposer.new(_knobs, roster, map, _net, server_root.multiplayer as SceneMultiplayer, server_root,
			TestMoveStep.apply, TestMoveStep.WORLD, TestMoveStep.make_body, _look)
	var hidden := HiddenSpawner.new()
	server_root.add_child(hidden)
	_c.hidden = hidden
	var server := RoundServer.new()
	server_root.add_child(server)
	assert_array(_c.start(server, rng)).is_empty()
	# Every client reports its map on its first snapshot; RoundLifecycle then spawns every body.
	await _until(func() -> bool: return _clients.all(func(c: RoundClient) -> bool: return c.is_spawned()),
			"every own body spawned")
	await _until(_all_settled, "every predicted body at its server body")
	for c in _clients:
		assert_float(c.body.global_position.y).override_failure_message("stands on the greybox floor").is_greater(-0.5)
	# Survivors spawn together: each survivor draws at least one remote, and only the handles it was sent.
	var survivor: RoundClient = null
	for c in _clients:
		if c.net.local_player_id != _c.monster:
			survivor = c
	await _until(func() -> bool: return survivor.remotes.values().any(func(n: Node3D) -> bool: return n.visible),
			"a survivor draws a remote body")
	for c in _clients:
		for h: int in c.remotes:
			assert_bool(c.remotes[h].visible == c._present.has(h)).is_true()
	survivor.toggle_flashlight()
	assert_bool(survivor.light.is_on()).is_true()
	await _until(_cone_seen.bind(survivor), "another client shows the flashlight cone")
	# AD-217: the survivor aims at a hiding spot and presses; its frame names the map index, and the server
	# starts the spot's Hide hold (a net id other than the index) and the client's bar follows it.
	var spot := -1
	var targets := map.interactables()
	for i in targets.size():
		if targets[i] is MapMarker and (targets[i] as MapMarker).type == &"hiding":
			spot = i
			break
	var sid := survivor.net.local_player_id
	var point := (targets[spot] as MapMarker).position + Vector3.UP * _knobs.controller.capsule_height_m * 0.5
	_c.bodies[sid].global_position = (targets[spot] as MapMarker).position + Vector3(0.0, 0.0, 1.0)
	await _until(_all_settled, "the survivor's predicted body at the spot")
	var eye := survivor.body.global_position + Vector3.UP * _knobs.controller.eye_height_m
	var flat := Vector2(point.x - eye.x, point.z - eye.z)
	survivor.scripted.yaw = atan2(-flat.x, -flat.y)
	survivor.scripted.pitch = atan2(point.y - eye.y, flat.length())
	assert_int(survivor.local_target(survivor.scripted.yaw, survivor.scripted.pitch)).is_equal(spot)
	survivor.scripted.interact = true
	await _until(func() -> bool: return not _c.holds.hold_of(sid).is_empty(), "the server starts the hiding hold")
	var held: int = _c.holds.hold_of(sid).net_id
	assert_bool(_c._ids_at[spot].has(held) and held != spot).is_true()
	assert_object(_c.holds._items[held]).is_instanceof(HidingHold)
	await _until(func() -> bool: return survivor.predictor.last_own.get("hold_net_id", -1) == held,
			"the survivor's snapshot shows the hold")
	assert_bool(survivor.bar.visible).is_true()


func _all_settled() -> bool:
	for c in _clients:
		var server_at: Vector3 = _c.bodies[c.net.local_player_id].global_position
		if c.body.global_position.distance_to(server_at) > _knobs.net.correction_smooth_max_m:
			return false
	return true


func _cone_seen(owner: RoundClient) -> bool:
	for c in _clients:
		if c == owner:
			continue
		for n: Node3D in c.remotes.values():
			if n.visible and (n.get_node(^"Cone") as SpotLight3D).visible:
				return true
	return false
