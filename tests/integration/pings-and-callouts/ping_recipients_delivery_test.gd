# Story pings-and-callouts/004 (design/gdd/pings-and-callouts.md rules 2, 7, 7a, 8; TR-pings-002, TR-pings-005;
# ADR-0004 per-peer delivery): five RoundClients over real ENet in a composed greybox round. An accepted ping
# reaches every living survivor's client, and the monster's only when its eye sees the target; a spectator
# gets exactly its watched survivor's pings; a rejection reaches the sender alone and clears its pending
# request; an item ping on an occupied hiding spot carries no occupant.
extends GdUnitTestSuite

const WAIT_S := 8.0
## AC 1: within 250 ms of acceptance; measured from the request, which is stricter.
const DELIVERY_MS := 250
## How long a client that must receive nothing is watched after the others got it: 30 ticks at 60 Hz.
const QUIET_TICKS := 30
## The payload keys every client gets (the sender's copy adds `own`): nothing names an occupant.
const PAYLOAD_KEYS := ["kind", "point", "item", "type", "identity", "from"]

static var _next_port := 28880

var _knobs: Knobs
var _roots: Array[Node] = []
var _clients: Array[RoundClient] = []
var _c: RoundComposer
var _net: NetAuthority
var _map: MapData


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


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Hosts, joins five clients and composes a round on the greybox; returns once every body has settled.
func _compose() -> void:
	var server_root := Node3D.new()
	server_root.name = "Host"
	get_tree().root.add_child(server_root)
	_roots.append(server_root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), server_root.get_path())
	_map = MapData.load_map()
	MapGreybox.build(server_root, _map)
	_net = NetAuthority.new()
	_net.setup(_knobs, _knobs.join_version(RoundClient.VERSION_BUILD), FakeLobby.new())
	server_root.add_child(_net)
	_next_port += 1
	assert_int(_net.host(_next_port)).is_equal(OK)
	for i in 5:
		var c := RoundClient.new(_knobs, TestMoveStep.apply, TestMoveStep.make_body, _map, false)
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
	var roster := Roster.lock(tokens, _info, "s-pc4", 1, _knobs, RotationQueue.new(), rng)
	_c = RoundComposer.new(_knobs, roster, _map, _net, server_root.multiplayer as SceneMultiplayer, server_root,
			TestMoveStep.apply, TestMoveStep.WORLD, TestMoveStep.make_body, _look)
	var server := RoundServer.new()
	server_root.add_child(server)
	assert_array(_c.start(server, rng)).is_empty()
	await _until(func() -> bool: return _clients.all(func(c: RoundClient) -> bool: return c.is_spawned()),
			"every own body spawned")
	await _until(_all_settled, "every predicted body at its server body")


func _all_settled() -> bool:
	for c in _clients:
		if c.body.global_position.distance_to(_c.bodies[c.net.local_player_id].global_position) \
				> _knobs.net.correction_smooth_max_m:
			return false
	return true


func _client(player: int) -> RoundClient:
	for c in _clients:
		if c.net.local_player_id == player:
			return c
	return null


func _monster_client() -> RoundClient:
	return _client(_c.monster)


## Puts the monster `behind` m from `at` along -Z and a wall (WORLD layer, as greybox floors) halfway between:
## the greybox has no walls, so the test builds the obstruction the server ray must meet.
func _monster_behind_wall(at: Vector3, behind: float) -> void:
	_c.bodies[_c.monster].global_position = at + Vector3(0.0, 0.0, -behind)
	var wall := StaticBody3D.new()
	wall.collision_layer = PhysicsLayers.WORLD
	wall.collision_mask = PhysicsLayers.NONE
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 4.0, 0.2)
	cs.shape = box
	wall.add_child(cs)
	_roots[0].add_child(wall)
	wall.global_position = at + Vector3(0.0, 2.0, -behind / 2.0)


func _all_got(players: Array, n: int) -> bool:
	return players.all(func(id: int) -> bool: return _client(id).pings.received.size() == n)


func _counts() -> Array[int]:
	var out: Array[int] = []
	for c in _clients:
		out.append(c.pings.received.size())
	return out


func test_item_ping_on_occupied_spot_reaches_survivors_and_monster_only_in_sight() -> void:
	await _compose()
	var spot := -1
	var targets := _map.interactables()
	for i in targets.size():
		if targets[i] is MapMarker and (targets[i] as MapMarker).type == &"hiding":
			spot = i
			break
	var at := (targets[spot] as MapMarker).position
	var point := at + Vector3.UP * _c.rules.point_height_m
	var others: Array[int] = []
	for id in _c.survivors:
		others.append(id)
	var sender := others[0]
	var occupant := others[1]
	_c.bodies[sender].global_position = at + Vector3(0.0, 0.0, 1.0)
	_c.bodies[_c.monster].global_position = at + Vector3(0.0, 0.0, -1.5)
	await _until(_all_settled, "sender and monster beside the hiding spot")
	_c.hs.hide_completed(occupant, 0) # the first hiding marker is HidingSpots' spot 0
	assert_int(_c.hs.occupant(0)).is_equal(occupant)
	assert_bool(_c._ping_clear(_c.monster, _c._eye(_c.monster), point, spot)).is_true()
	var t0 := Time.get_ticks_msec()
	_client(sender).pings.request(PingsCallouts.ITEM, Vector3.ZERO, spot)
	await _until(func() -> bool: return _counts().all(func(n: int) -> bool: return n == 1), "every client gets the ping")
	assert_int(Time.get_ticks_msec() - t0).is_less_equal(DELIVERY_MS)
	assert_array(_client(sender).pings.pending).is_empty()
	var from: int = _client(sender).pings.received[0]["from"]
	assert_int(from).is_equal(_c.bf.appearance_of(sender))
	for c in _clients:
		var p := c.pings.received[0]
		var keys := PAYLOAD_KEYS.duplicate()
		if c.net.local_player_id == sender:
			keys.append("own")
		assert_array(p.keys()).contains_exactly_in_any_order(keys)
		assert_int(p["item"]).is_equal(spot)
		assert_str(p["type"]).is_equal("hiding")
		assert_int(p["identity"]).is_equal(-1)
		assert_int(p["from"]).is_equal(from)
	# Out of the monster's sight: the 4 survivors only.
	_monster_behind_wall(at, 3.0)
	await _until(_all_settled, "the monster out of sight")
	assert_bool(_c._ping_clear(_c.monster, _c._eye(_c.monster), point, -1)).is_false()
	_client(sender).pings.request(PingsCallouts.ITEM, Vector3.ZERO, spot)
	await _until(_all_got.bind(others, 2), "every survivor gets the second ping")
	await _ticks(QUIET_TICKS)
	assert_int(_monster_client().pings.received.size()).is_equal(1)


func test_downed_ping_out_of_sight_spectator_mirror_and_rejection_to_sender_only() -> void:
	await _compose()
	var sender: int = _c.survivors[0]
	var dead: int = _c.survivors[3]
	var point := _c.bodies[sender].global_position + Vector3.UP * 0.2
	_monster_behind_wall(_c.bodies[sender].global_position, 3.0)
	await _until(_all_settled, "the monster out of sight")
	assert_bool(_c._ping_clear(_c.monster, _c._eye(_c.monster), point, -1)).is_false()
	var e := EvSurvivorEliminated.new()
	e.survivor = dead
	_c.server.bus.emit(e)
	await _until(func() -> bool: return _c.lifecycle.watched_by(dead) != -1, "the eliminated survivor spectates")
	var watched := _c.lifecycle.watched_by(dead)
	_c.downing._life[sender] = Downing.LifeState.DOWNED
	_client(sender).pings.request(PingsCallouts.LOCATION, point)
	var living := _c.survivors.filter(func(id: int) -> bool: return id != dead)
	living.append(dead)
	await _until(_all_got.bind(living, 1), "living survivors and the spectator get the ping")
	await _ticks(QUIET_TICKS)
	assert_int(_monster_client().pings.received.size()).is_equal(0)
	assert_array(_client(dead).pings.received).is_equal(_client(watched).pings.received)
	assert_vector(_client(watched).pings.received[0]["point"]).is_equal(point)
	# Rejected (out of range): the sender's pending request goes; nobody else hears of it.
	var before := _counts()
	_client(sender).pings.request(PingsCallouts.LOCATION, point + Vector3(1000.0, 0.0, 0.0))
	await _until(func() -> bool: return _client(sender).pings.rejections == 1, "the sender gets the rejection")
	assert_array(_client(sender).pings.pending).is_empty()
	await _ticks(QUIET_TICKS)
	assert_array(_counts()).is_equal(before)
	for c in _clients:
		if c.net.local_player_id != sender:
			assert_int(c.pings.rejections).is_equal(0)
