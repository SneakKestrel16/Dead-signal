# Story survivor-defense/015: the shipped RoundClient fires the taser on use_item (design/gdd/survivor-defense.md
# rules 7, 8, 13, 0-cartridge edge case; ADR-0014 §1, ADR-0002). Real ENet, five clients in a composed round:
# each press of a survivor holding cartridges reaches the server as one fire request, the server spends
# cartridges and stuns by its own rules, and a survivor out of cartridges or the shapeshifter sends nothing.
# The wheel/overlay gate is tests/unit/survivor-defense/taser_fire_gate_test.gd.
extends GdUnitTestSuite

const WAIT_S := 8.0
## Frames to let a request that should not exist arrive (local ENet delivers within a few).
const QUIET_FRAMES := 20

static var _next_port := 30800

var _knobs: Knobs
var _roots: Array[Node] = []
var _clients: Array[RoundClient] = []
var _c: RoundComposer
var _net: NetAuthority
## player id -> fire requests the server received from it
var _fires: Dictionary[int, int] = {}


class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	Engine.physics_ticks_per_second = _knobs.net.sim_tick_hz
	_clients = []
	_fires = {}


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


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _on_server_packet(peer_id: int, bytes: PackedByteArray) -> void:
	if SurvivorDefense.decode_intent(bytes) == SurvivorDefense.FIRE:
		var pid := _net.player_id_of(peer_id)
		_fires[pid] = _fires.get(pid, 0) + 1


## Hosts, joins five clients and composes a round on the greybox; returns once every body has settled.
func _compose() -> void:
	var server_root := Node3D.new()
	server_root.name = "Host"
	get_tree().root.add_child(server_root)
	_roots.append(server_root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), server_root.get_path())
	var map := MapData.load_map()
	MapGreybox.build(server_root, map)
	_net = NetAuthority.new()
	_net.setup(_knobs, _knobs.join_version(RoundClient.VERSION_BUILD), FakeLobby.new())
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
	rng.seed = 15
	var roster := Roster.lock(tokens, _info, "s-sd15", 1, _knobs, RotationQueue.new(), rng)
	_c = RoundComposer.new(_knobs, roster, map, _net, server_root.multiplayer as SceneMultiplayer, server_root,
			TestMoveStep.apply, TestMoveStep.WORLD, TestMoveStep.make_body, _look)
	var hidden := HiddenSpawner.new()
	server_root.add_child(hidden)
	_c.hidden = hidden
	var server := RoundServer.new()
	server_root.add_child(server)
	assert_array(_c.start(server, rng)).is_empty()
	(server_root.multiplayer as SceneMultiplayer).peer_packet.connect(_on_server_packet)
	await _until(func() -> bool: return _clients.all(func(c: RoundClient) -> bool: return c.is_spawned()),
			"every own body spawned")
	await _until(_all_settled, "every predicted body at its server body")


func _all_settled() -> bool:
	for c in _clients:
		var server_at: Vector3 = _c.bodies[c.net.local_player_id].global_position
		if c.body.global_position.distance_to(server_at) > _knobs.net.correction_smooth_max_m:
			return false
	return true


## Points `c`'s scripted view from its predicted eye at `point`.
func _aim(c: RoundClient, point: Vector3) -> void:
	var eye := c.body.global_position + Vector3.UP * _knobs.controller.eye_height_m
	var flat := Vector2(point.x - eye.x, point.z - eye.z)
	c.scripted.yaw = atan2(-flat.x, -flat.y)
	c.scripted.pitch = atan2(point.y - eye.y, flat.length())


func test_each_press_sends_one_request_and_the_server_spends_and_stuns() -> void:
	await _compose()
	var shooter: RoundClient = null
	var target: RoundClient = null
	var monster: RoundClient = null
	for c in _clients:
		if c.net.local_player_id == _c.monster:
			monster = c
		elif shooter == null:
			shooter = c
		elif target == null:
			target = c
	var sid := shooter.net.local_player_id
	var full := _knobs.defense.stun_item_charges
	await _until(func() -> bool: return shooter.defense.charges() == full, "the shooter's cartridges arrive")
	# Target half the taser's range in front of the shooter, aimed at its centre.
	var at: Vector3 = _c.bodies[sid].global_position
	_c.bodies[target.net.local_player_id].global_position = at + Vector3.FORWARD * _knobs.defense.stun_range_m * 0.5
	await _until(_all_settled, "the target in front of the shooter")
	_aim(shooter, target.body.global_position + Vector3.UP * _knobs.controller.capsule_height_m * 0.5)
	await _frames(3) # the aimed frames reach the server before the shot
	# Two presses at once: two requests, one cartridge (the reuse delay refuses the second, rule 13).
	assert_bool(shooter.fire_taser()).is_true()
	assert_bool(shooter.fire_taser()).is_true()
	await _until(func() -> bool: return _fires.get(sid, 0) == 2, "two fire requests at the server")
	await _until(func() -> bool: return shooter.defense.charges() == full - 1, "one cartridge spent, shown")
	assert_int(_c.sd.charges(sid)).is_equal(full - 1)
	await _until(func() -> bool: return target.defense.own_shock().size() == 2, "the target is shocked")
	assert_str(target.defense.own_shock()[0]).is_equal("PlayerShocked")
	# After the reuse delay, the last cartridge.
	await _until(func() -> bool: return _c.sd.can_fire(sid, _c._tick()), "the reuse delay over")
	assert_bool(shooter.fire_taser()).is_true()
	await _until(func() -> bool: return shooter.defense.charges() == 0, "the last cartridge spent, shown")
	assert_int(_fires.get(sid, 0)).is_equal(3)
	# Out of cartridges, and the shapeshifter with no taser: a press sends nothing.
	assert_int(monster.defense.charges()).is_equal(-1)
	assert_bool(shooter.fire_taser()).is_false()
	assert_bool(monster.fire_taser()).is_false()
	await _frames(QUIET_FRAMES)
	assert_int(_fires.get(sid, 0)).is_equal(3)
	assert_int(_fires.get(_c.monster, 0)).is_equal(0)
	assert_int(_c.sd.charges(sid)).is_equal(0)
