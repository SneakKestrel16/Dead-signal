# Story match-flow/014 (TR-match-008; ADR-0011 §1-3): every owner the composer builds registers its round
# StatsView, so a composed round's RoundResults lists nothing in `missing` and carries the owners' counts.
# Real ENet, 5 clients on 127.0.0.1 (the round_composer_test rig): a requested lunge downs a survivor, a fired
# taser stuns the monster, the rescue and the drive pickup call their module's completion entry inside a tick
# (a real hold needs level collision and aimed input frames, which this headless rig has not got), then the
# round ends by its rules: every survivor Eliminated (SurvivorEliminated on the server bus, as
# lobby_to_round_wiring_test does; round_duration_s cannot go under 420 s).
# The roster view is published as RosterHandoff.publish does in the shipped lobby path.
extends GdUnitTestSuite

const SERVER_VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
const SESSION := "s-mf14"
## Far from every map door, so no door leaf crosses the scripted sight lines.
const BASE := Vector3(300.0, 0.0, 300.0)
const PORT := 30840

class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0


## Runs the test's queued actions in a tick after the Holds step, so their events land in that tick.
class ActStep extends RefCounted:
	var queue: Array[Callable] = []

	func setup(_runner: TickRunner, _bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
		pass

	func server_tick(tick: int) -> void:
		for c in queue:
			c.call(tick)
		queue.clear()


var _knobs: Knobs
var _server: RoundServer
var _c: RoundComposer
var _roots: Array[Node] = []
var _clients: Array[NetAuthority] = []
var _net: NetAuthority
var _act: ActStep
var _seen: Dictionary[StringName, int] = {}
var _results: Dictionary = {}


func before_test() -> void:
	_knobs = Knobs.load_all()
	_clients = []
	_seen = {}
	_results = {}


func after_test() -> void:
	if _c != null:
		_c.stop()
		_c = null
	await get_tree().process_frame # HiddenSpawner despawns by queue_free: let it run before the roots go
	_server = null
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


func _root() -> Node:
	var n := Node3D.new()
	n.name = "Rs%d" % _roots.size()
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


func _info(token: String) -> Dictionary:
	var pid := token.trim_prefix("t").to_int()
	return {"player_id": pid, "name": "P%d" % pid}


func _no_look(_id: int) -> int:
	return 0


func _on_event(e: ServerEvent) -> void:
	_seen[StringName(e.type())] = _seen.get(StringName(e.type()), 0) + 1
	if e is EvRoundEnded:
		_results = (e as EvRoundEnded).results


func _all_joined() -> bool:
	return _clients.all(func(c: NetAuthority) -> bool: return c.local_player_id != -1)


func _rig(clients: int) -> void:
	var server_root := _root()
	_net = NetAuthority.new()
	_net.setup(_knobs, SERVER_VERSION, FakeLobby.new())
	server_root.add_child(_net)
	assert_int(_net.host(PORT)).is_equal(OK)
	for i in clients:
		var root := _root()
		var c := NetAuthority.new()
		c.setup(_knobs, SERVER_VERSION, FakeLobby.new())
		root.add_child(c)
		root.add_child(HiddenSpawner.new()) # same root-relative path as the server's: candidate replication
		assert_int(c.join("127.0.0.1", PORT, "P%d" % i)).is_equal(OK)
		_clients.append(c)
	await _until(_all_joined, "%d clients joined" % clients)


func _compose() -> void:
	var tokens := PackedStringArray()
	for c in _clients:
		tokens.append("t%d" % c.local_player_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 14
	var roster := Roster.lock(tokens, _info, SESSION, 1, _knobs, RotationQueue.new(), rng)
	assert_object(roster).is_not_null()
	var server_root := _roots[0]
	_c = RoundComposer.new(_knobs, roster, MapData.load_map(), _net, server_root.multiplayer as SceneMultiplayer,
			server_root as Node3D, TestMoveStep.apply, TestMoveStep.WORLD, TestMoveStep.make_body, _no_look)
	var hidden := HiddenSpawner.new()
	server_root.add_child(hidden)
	_c.hidden = hidden
	_server = auto_free(RoundServer.new())
	add_child(_server)
	assert_array(_c.start(_server, rng)).is_empty()
	_server.registry.register_view(StateKeys.PLAYER_ROSTER, &"Lobby", RosterView.new(roster)) # RosterHandoff.publish
	_server.tick_runner.set_physics_process(false) # the test steps every tick itself
	_act = ActStep.new()
	_server.tick_runner.register_feature(FeatureStep.new(_act, _server.bus), TickOrder.HOLDS + 1)
	for type: StringName in [&"SurvivorDowned", &"MonsterStunned", &"SurvivorRescued", &"ObjectiveProgressChanged",
			&"RoundEnded"]:
		_server.bus.subscribe(type, _on_event)


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()
		_poll()


func _send(client: int, bytes: PackedByteArray) -> void:
	(_roots[client + 1].multiplayer as SceneMultiplayer).send_bytes(bytes, 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE)


func _client_of(id: int) -> int:
	for i in _clients.size():
		if _clients[i].local_player_id == id:
			return i
	return -1


func _place(id: int, at: Vector3) -> void:
	_c.sm.set_frozen(id, true) # no level floor here: frozen bodies hold still (the hit test reads history)
	_c.bodies[id].global_position = at


func _step_until(cond: Callable, max_ticks: int) -> bool:
	for i in max_ticks:
		if cond.call():
			return true
		_step(1)
		await get_tree().process_frame
	return cond.call()


func _running() -> bool:
	return _c.lifecycle.state() == RoundLifecycle.State.RUNNING


func _saw(type: StringName) -> bool:
	return _seen.get(type, 0) > 0


func _rescue(_tick: int, downed: int, rescuer: int) -> void:
	_c.downing.rescue_completed(downed, rescuer)


func _recover_drive(_tick: int, actor: int) -> void:
	for i: Interactable in _c.holds._items:
		if i is SurvivorObjectives.DriveConsole and i.eligible(actor):
			i.on_complete(actor)
			return


func _eliminate_all(_tick: int) -> void:
	for id in _c.survivors:
		var e := EvSurvivorEliminated.new()
		e.survivor = id
		_server.bus.emit(e)


func _survivor(id: int) -> Dictionary:
	for s: Dictionary in _results.get("survivors", []):
		if s.player_id == id:
			return s
	return {}


func _line(name: String) -> Dictionary:
	for o: Dictionary in _results.get("objectives", []):
		if o.line == name:
			return o
	return {}


## AC-1, AC-2: a composed 5-client round with a forced down, rescue, stun and drive recovery ends by its rules
## with nothing in `missing` and those counts read from the owners' views.
func test_composed_round_results_read_every_owner_view() -> void:
	await _rig(5)
	_compose()
	for i in 5:
		_send(i, RoundLifecycle.map_loaded_packet())
	assert_bool(await _step_until(_running, _knobs.ticks(1.0))).override_failure_message("never left Loading").is_true()
	var m := _c.monster
	var victim := _c.survivors[0]
	var shooter := _c.survivors[1]
	_place(m, BASE)
	_place(victim, BASE + Vector3(0.0, 0.0, -1.0)) # in the lunge cone (monster faces -Z at yaw 0)
	_place(shooter, BASE + Vector3(0.0, 0.0, 3.0)) # behind the monster, facing it along -Z
	for k in range(2, _c.survivors.size()):
		_place(_c.survivors[k], BASE + Vector3(30.0 * k, 0.0, 0.0))
	_step(ceili(_knobs.ability.max_rewind_ms * _knobs.net.sim_tick_hz / 1000.0) + 2)
	var lunge := MonsterAbilities.request_packet(MonsterAbilities.Ability.LUNGE)
	var commit := _knobs.ticks(_knobs.ability.lunge_windup_s) + _knobs.ticks(_knobs.ability.lunge_dash_s) \
			+ _knobs.ticks(_knobs.downing.takedown_commit_s) + _knobs.ticks(1.0)
	for i in commit:
		if _saw(&"SurvivorDowned"):
			break
		if _c.ma.lunge_state() == MonsterAbilities.Lunge.READY:
			_send(_client_of(m), lunge)
		_step(1)
		await get_tree().process_frame
	assert_bool(_saw(&"SurvivorDowned")).override_failure_message("no lunge down").is_true()
	var stun := func() -> bool: return _saw(&"MonsterStunned")
	for i in _knobs.ticks(1.0) + _knobs.ticks(_knobs.defense.stun_use_delay_s):
		if stun.call():
			break
		if i % 10 == 0:
			_send(_client_of(shooter), SurvivorDefense.fire_packet())
		_step(1)
		await get_tree().process_frame
	assert_bool(stun.call()).override_failure_message("no taser stun").is_true()
	_act.queue.append_array([_rescue.bind(victim, shooter), _recover_drive.bind(_c.survivors[2])])
	_step(2)
	assert_bool(_saw(&"SurvivorRescued")).override_failure_message("no rescue").is_true()
	_act.queue.append(_eliminate_all)
	assert_bool(await _step_until(func() -> bool: return _saw(&"RoundEnded"), _knobs.ticks(1.0))) \
			.override_failure_message("no RoundEnded").is_true()
	assert_array(_results.missing).is_empty()
	assert_int(_survivor(victim).downs).is_equal(1)
	assert_int(_survivor(shooter).rescues).is_equal(1)
	assert_int(_survivor(shooter).stuns_landed).is_equal(1)
	assert_int(_survivor(victim).rescues).is_equal(0)
	assert_str(_survivor(victim).name).is_equal("P%d" % victim)
	assert_int(_results.monster.takedowns).is_equal(1)
	assert_int(_results.monster.eliminations).is_equal(_c.survivors.size())
	assert_int(_results.monster.times_stunned).is_equal(1)
	assert_int(_results.monster.lunges_landed).is_equal(1)
	assert_int(_line("drives_recovered").count).is_equal(1)
	assert_float(_line("drives_recovered").completed_s).is_equal(-1.0)
	assert_str(_survivor(victim).cause).is_equal("takedown")
