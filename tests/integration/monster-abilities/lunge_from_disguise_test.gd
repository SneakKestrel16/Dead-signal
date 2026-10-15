# Story monster-abilities/012 (design/gdd/monster-abilities.md rule 4, design/gdd/borrowed-face.md rule 11;
# designer decision 2026-10-15, playtest): over real ENet, five RoundClients join a composed round; the
# shapeshifter disguises as the survivor in front of it, then lunges. A survivor client sees the true-form
# body while the server is still in wind-up (no SurvivorHit yet), and the lunge then downs the survivor.
# The server is stepped by hand so "before the hit" is a tick count, not a wall-clock race.
extends GdUnitTestSuite

const WAIT_S := 8.0
## Ports 30970-30989 belong to this story's runs.
const PORT := 30971
## Far from every map door, so no door leaf crosses the sight line (round_composer_test's spot).
const BASE := Vector3(300.0, 0.0, 300.0)

var _knobs: Knobs
var _roots: Array[Node] = []
var _clients: Array[RoundClient] = []
var _c: RoundComposer
var _server: RoundServer
var _hits: Array[int] = []
var _downed: Array[int] = []


class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	Engine.physics_ticks_per_second = _knobs.net.sim_tick_hz
	_clients = []
	_hits = []
	_downed = []


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
		await get_tree().process_frame
	assert_bool(cond.call()).override_failure_message("timeout waiting for " + what).is_true()


func _joined() -> bool:
	return _clients.all(func(c: RoundClient) -> bool: return c.is_ready())


func _on_hit(e: ServerEvent) -> void:
	_hits.append((e as EvSurvivorHit).survivor)


func _on_downed(e: ServerEvent) -> void:
	_downed.append((e as EvSurvivorDowned).survivor)


## Steps the server `n` ticks, yielding a frame after each so clients receive the snapshots.
func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()
		await get_tree().process_frame


func _client_of(player: int) -> RoundClient:
	for c in _clients:
		if c.net.local_player_id == player:
			return c
	return null


## Remote bodies `client` currently renders with `appearance`.
func _puppets_as(client: RoundClient, appearance: int) -> int:
	var n := 0
	for h: int in client.puppets.handles():
		if client.puppets.state_of(h).get("appearance", -1) == appearance:
			n += 1
	return n


## Remote bodies `client` currently renders in the true-form appearance.
func _true_form_puppets(client: RoundClient) -> int:
	return _puppets_as(client, CharacterDef.TRUE_FORM_APPEARANCE_ID)


func _place(id: int, at: Vector3) -> void:
	_c.sm.set_frozen(id, true)
	_c.bodies[id].global_position = at


func test_disguised_lunge_reveals_to_a_survivor_client_in_wind_up_then_downs() -> void:
	var server_root := Node3D.new()
	server_root.name = "Host"
	get_tree().root.add_child(server_root)
	_roots.append(server_root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), server_root.get_path())
	var map := MapData.load_map()
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
	rng.seed = 12
	var roster := Roster.lock(tokens, _info, "s-ma12", 1, _knobs, RotationQueue.new(), rng)
	_c = RoundComposer.new(_knobs, roster, map, net, server_root.multiplayer as SceneMultiplayer, server_root,
			TestMoveStep.apply, TestMoveStep.WORLD, TestMoveStep.make_body, _look)
	_server = RoundServer.new()
	server_root.add_child(_server)
	assert_array(_c.start(_server, rng)).is_empty()
	_server.tick_runner.set_physics_process(false)
	_server.bus.subscribe(&"SurvivorHit", _on_hit)
	_server.bus.subscribe(&"SurvivorDowned", _on_downed)
	for id in roster.player_ids():
		_c.lifecycle.report_loaded(id)
	for i in _knobs.ticks(1.0):
		if _c.lifecycle.state() == RoundLifecycle.State.RUNNING:
			break
		await _step(1)
	assert_int(_c.lifecycle.state()).is_equal(RoundLifecycle.State.RUNNING)
	var target: int = _c.survivors[0]
	var watcher := _client_of(_c.survivors[1])
	for i in _c.survivors.size():
		_place(_c.survivors[i], BASE + (Vector3(0.0, 0.0, -1.0) if i == 0 else Vector3(2.0 * i, 0.0, 3.0)))
	_place(_c.monster, BASE) # yaw 0 faces -Z: the target stands 1 m ahead, inside the hit radius and cone
	await _step(_knobs.ticks(_knobs.borrowed_face.observe_time_s) + 1)
	assert_bool(_c.bf.observed(target)).is_true()
	_c.bf.request_form_change(_c.monster, BorrowedFace.request_packet(target))
	await _step(_knobs.ticks(_knobs.borrowed_face.transform_duration_s) + 1)
	assert_int(_c.bf.form()).is_equal(target)
	var copied := _c.bf.appearance_of(target)
	await _until(func() -> bool: return _true_form_puppets(watcher) == 0 and _puppets_as(watcher, copied) == 2,
			"the survivor client to see the disguise (the target and its copy)")

	_c.ma.request_ability(_c.monster, MonsterAbilities.request_packet(MonsterAbilities.Ability.LUNGE))
	await _step(1)
	assert_int(_c.ma.lunge_state()).override_failure_message("a disguised lunge was rejected") \
			.is_equal(MonsterAbilities.Lunge.WIND_UP)
	var windup := _knobs.ticks(_knobs.ability.lunge_windup_s)
	var seen_after := -1
	for i in windup - 1:
		if _true_form_puppets(watcher) == 1:
			seen_after = i
			break
		await _step(1)
	assert_int(seen_after).override_failure_message("the survivor client never saw true form during wind-up") \
			.is_not_equal(-1)
	assert_int(_c.ma.lunge_state()).is_equal(MonsterAbilities.Lunge.WIND_UP)
	assert_array(_hits).is_empty()
	for i in windup + _knobs.ticks(_knobs.ability.lunge_dash_s) + _knobs.ticks(_knobs.downing.takedown_commit_s) + 2:
		if not _downed.is_empty():
			break
		await _step(1)
	assert_array(_hits).is_equal([target])
	assert_array(_downed).is_equal([target])
