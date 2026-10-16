# BUG-0018: in a composed round over real ENet, a door the server closes stops a walking body on the server
# and in its owner's prediction (the client's own level, a separate World3D, follows the replicated door
# state), with no snap correction; reopened, the same walk passes through.
extends GdUnitTestSuite

const WAIT_S := 8.0
const WALK_TICKS := 90 ## 1.5 s at 60 Hz: several metres at walk speed, far past the leaf
const SETTLED_M := 0.3

static var _next_port := 27200

var _knobs: Knobs
var _roots: Array[Node] = []
var _clients: Array[RoundClient] = []
var _c: RoundComposer
var _net: NetAuthority
var _map: MapData
var _client_level: Node3D


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


func _settled() -> bool:
	return _clients.all(func(c: RoundClient) -> bool:
		return c.body.global_position.distance_to(_c.bodies[c.net.local_player_id].global_position) < SETTLED_M)


## Hosts the server in its own World3D (as RoundHost does) and five clients in another, with their own level.
func _compose() -> void:
	var server_root := Node.new()
	server_root.name = "Host"
	get_tree().root.add_child(server_root)
	_roots.append(server_root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), server_root.get_path())
	_map = MapData.load_map()
	var view := SubViewport.new()
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	server_root.add_child(view)
	var world := Node3D.new()
	view.add_child(world)
	MapGreybox.build(world, _map)
	_client_level = Node3D.new()
	_client_level.name = "ClientLevel"
	get_tree().root.add_child(_client_level)
	_roots.append(_client_level)
	MapGreybox.build(_client_level, _map)
	_net = NetAuthority.new()
	_net.setup(_knobs, _knobs.join_version(RoundClient.VERSION_BUILD), FakeLobby.new())
	server_root.add_child(_net)
	_next_port += 1
	assert_int(_net.host(_next_port)).is_equal(OK)
	for i in 5:
		var c := RoundClient.new(_knobs, RoundMoveStep.step_for(_knobs), RoundMoveStep.body_maker(_knobs), _map, false)
		c.name = "D%d" % i
		c.level = _client_level
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
	var roster := Roster.lock(tokens, _info, "s-bug18", 1, _knobs, RotationQueue.new(), rng)
	_c = RoundComposer.new(_knobs, roster, _map, _net, server_root.multiplayer as SceneMultiplayer, world,
			RoundMoveStep.step_for(_knobs), PhysicsLayers.WORLD, RoundMoveStep.body_maker(_knobs), _look)
	var hidden := HiddenSpawner.new()
	server_root.add_child(hidden)
	_c.hidden = hidden
	var server := RoundServer.new()
	server_root.add_child(server)
	assert_array(_c.start(server, rng)).is_empty()
	await _until(func() -> bool: return _clients.all(func(c: RoundClient) -> bool: return c.is_spawned()), "spawned")
	await _until(_settled, "every predicted body at its server body")


func _survivor() -> RoundClient:
	for c in _clients:
		if c.net.local_player_id != _c.monster:
			return c
	return null


func _client_shape(c: RoundClient, passage: StringName) -> CollisionShape3D:
	for b: Node in c.level.find_children("Door_*", "StaticBody3D", true, false):
		if b.get_meta(&"passage", &"") == passage:
			return b.get_node(^"Shape") as CollisionShape3D
	return null


func test_a_closed_door_stops_the_server_body_and_the_prediction_and_an_open_one_does_not() -> void:
	await _compose()
	var door := -1
	var targets := _map.interactables()
	for i in targets.size():
		if targets[i] is MapPassage and (targets[i] as MapPassage).kind == MapPassage.DOOR:
			door = i
			break
	var p := targets[door] as MapPassage
	# Across the wall: the swing box's long horizontal axis (MapQueries._leaf).
	var along_z := p.swing_box.size.z < p.swing_box.size.x
	var axis := Vector3.RIGHT if along_z else Vector3.BACK
	var off := (p.swing_box.size.x if along_z else p.swing_box.size.z) * 0.5 + _knobs.controller.player_radius_m + 0.3
	var survivor := _survivor()
	var sid := survivor.net.local_player_id
	var shape := _client_shape(survivor, p.id)
	assert_bool(shape.disabled).is_true()
	assert_bool(_c.doors.toggle(door)).is_true()
	await _until(func() -> bool: return not shape.disabled, "the client's blocker follows the closed door")
	assert_bool((shape.get_parent().get_node(^"Mesh") as Node3D).visible).is_true()
	_c.bodies[sid].global_position = Vector3(p.position.x, 0.0, p.position.z) + axis * off
	await _until(_settled, "the survivor beside the closed door")
	# Walk straight through the doorway.
	var snaps := survivor.predictor.snaps
	var through := p.position - axis * 3.0
	survivor.scripted.yaw = atan2(-(through.x - p.position.x), -(through.z - p.position.z))
	survivor.scripted.move = Vector2(0.0, 1.0)
	for i in WALK_TICKS:
		await get_tree().physics_frame
	var server_side := (_c.bodies[sid].global_position - p.position).dot(axis)
	var predicted_side := (survivor.body.global_position - p.position).dot(axis)
	assert_float(server_side).override_failure_message("server body crossed the closed door").is_greater(0.0)
	assert_float(predicted_side).override_failure_message("prediction crossed the closed door").is_greater(0.0)
	assert_int(survivor.predictor.snaps).override_failure_message("prediction snapped at the door").is_equal(snaps)
	# Reopened: the same walk carries on through.
	assert_bool(_c.doors.toggle(door)).is_true()
	await _until(func() -> bool: return shape.disabled, "the client's blocker follows the open door")
	await _until(func() -> bool: return (_c.bodies[sid].global_position - p.position).dot(axis) < -0.5,
			"the server body walks through the open door")
	survivor.scripted.move = Vector2.ZERO
