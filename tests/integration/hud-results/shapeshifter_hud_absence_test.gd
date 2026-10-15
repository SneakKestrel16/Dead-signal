# Story hud-results/006 (ADR-0004 §5, design/ux/hud.md S1-S7, AC 2): over real ENet, five rendering RoundClients
# join a composed round. The shapeshifter's client mounts ShapeshifterHud from the MonsterHudFeed entry; every
# survivor client's tree holds no S1-S7 node and its HudModel never received shapeshifter state.
extends GdUnitTestSuite

const WAIT_S := 8.0
## Ports 30680-30699 belong to this story's runs.
const PORT := 30681
const S_NODE := "^S[1-7]"

var _knobs: Knobs
var _roots: Array[Node] = []
var _clients: Array[RoundClient] = []
var _c: RoundComposer


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


func _joined() -> bool:
	return _clients.all(func(c: RoundClient) -> bool: return c.is_ready())


func _spawned() -> bool:
	return _clients.all(func(c: RoundClient) -> bool: return c.is_spawned())


func _monster_client() -> RoundClient:
	for c in _clients:
		if c.net.local_player_id == _c.monster:
			return c
	return null


func _monster_mounted() -> bool:
	return _monster_client().hud.find_child("ShapeshifterHud", false, false) != null


## Every node under `root` named S1..S7 or that is a ShapeshifterHud.
func _s_nodes(root: Node) -> Array[String]:
	var re := RegEx.create_from_string(S_NODE)
	var out: Array[String] = []
	for n in root.find_children("*", "", true, false):
		if re.search(n.name) != null or n is ShapeshifterHud:
			out.append(String(n.get_path()))
	return out


func test_survivor_clients_hold_no_s_node_while_the_shapeshifter_client_does() -> void:
	var server_root := Node3D.new()
	server_root.name = "Host"
	get_tree().root.add_child(server_root)
	_roots.append(server_root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), server_root.get_path())
	var map := MapData.load_map()
	MapGreybox.build(server_root, map)
	var net := NetAuthority.new()
	net.setup(_knobs, _knobs.join_version(RoundClient.VERSION_BUILD), FakeLobby.new())
	server_root.add_child(net)
	assert_int(net.host(PORT)).is_equal(OK)
	for i in 5:
		var c := RoundClient.new(_knobs, TestMoveStep.apply, TestMoveStep.make_body, map, true)
		c.name = "C%d" % i
		get_tree().root.add_child(c)
		_clients.append(c)
		assert_int(c.join("127.0.0.1", PORT, "P%d" % i)).is_equal(OK)
		c.scripted = InputFrame.new()
	await _until(_joined, "5 joined")
	var tokens := PackedStringArray()
	for c in _clients:
		tokens.append("t%d" % c.net.local_player_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var roster := Roster.lock(tokens, _info, "s-hud6", 1, _knobs, RotationQueue.new(), rng)
	_c = RoundComposer.new(_knobs, roster, map, net, server_root.multiplayer as SceneMultiplayer, server_root,
			TestMoveStep.apply, TestMoveStep.WORLD, TestMoveStep.make_body, _look)
	var server := RoundServer.new()
	server_root.add_child(server)
	assert_array(_c.start(server, rng)).is_empty()
	await _until(_spawned, "every own body spawned")
	await _until(_monster_mounted, "the shapeshifter client's HUD mounted")
	var monster := _monster_client()
	assert_bool(monster.hud_model.is_shapeshifter()).is_true()
	assert_int(monster.hud_model.faces().size()).override_failure_message("one face row per survivor") \
			.is_equal(_c.survivors.size())
	assert_array(_s_nodes(monster.hud)).is_not_empty()
	# Ten more server ticks for any misrouted entry to land on a survivor client before it is inspected.
	for i in 10:
		await get_tree().physics_frame
	for c in _clients:
		if c == monster:
			continue
		assert_bool(c.hud_model.is_shapeshifter()).override_failure_message("%s got shapeshifter state" % c.name) \
				.is_false()
		assert_array(_s_nodes(c)).override_failure_message("%s holds an S node" % c.name).is_empty()
