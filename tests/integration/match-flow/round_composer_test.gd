# Story match-flow/010 (AD-201; ADR-0005 composition root): RoundComposer builds every round module and
# wires every cross-module hook (AC-1, AC-2: the audit below fails on any unset Callable or null
# collaborator), and a composed round runs over real ENet with 5 clients on 127.0.0.1 from Loading to
# RoundEnded and Over (AC-3). The lunge and the taser come from real client request packets; the hide,
# the barricade and the objective pickup call their module's completion entry inside a tick (a real hold
# needs level collision and aimed input frames, which this headless rig has not got).
extends GdUnitTestSuite

const SERVER_VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
const SESSION := "s-mf10"
## Far from every map door, so no door leaf crosses the scripted sight lines.
const BASE := Vector3(300.0, 0.0, 300.0)
const POLL_EVERY := 10 ## ticks stepped between network polls on the long run to the deadline

static var _next_port := 28100

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


## Collaborators that are deliberately optional (telemetry, tests, or set by a later story).
## MatchFlow._ended_event is round state (null until RoundEnded), not a hook.
## MonsterAbilities False Signal sources (MA-9): TODO, unwired: `snap` needs a nearest-walkable-floor query
## and `path_end` a path cut, which MapQueries has not got, and the walk cadence `step_s` has no knob yet.
const OPTIONAL: Array[String] = ["MonsterAbilities.on_lunge_state", "Doors.blockers", "MatchFlow._ended_event",
	"MonsterAbilities._emit_sound", "MonsterAbilities._snap", "MonsterAbilities._observed",
	"MonsterAbilities._status_of", "MonsterAbilities._footstep_set_of", "MonsterAbilities._path_end"]

var _knobs: Knobs
var _server: RoundServer
var _c: RoundComposer
var _roots: Array[Node] = []
var _clients: Array[NetAuthority] = []
var _net: NetAuthority
var _act: ActStep
var _seen: Dictionary[StringName, int] = {}
var _over: Array[bool] = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_clients = []
	_seen = {}
	_over = []


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
	n.name = "Rc%d" % _roots.size()
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


func _on_over(ended: bool) -> void:
	_over.append(ended)


func _all_joined() -> bool:
	for c in _clients:
		if c.local_player_id == -1:
			return false
	return true


## Hosts on a fresh port; `clients` real ENet clients join. Returns the roster's player ids.
func _rig(clients: int) -> void:
	var server_root := _root()
	_net = NetAuthority.new()
	_net.setup(_knobs, SERVER_VERSION, FakeLobby.new())
	server_root.add_child(_net)
	_next_port += 1
	assert_int(_net.host(_next_port)).is_equal(OK)
	for i in clients:
		var root := _root()
		var c := NetAuthority.new()
		c.setup(_knobs, SERVER_VERSION, FakeLobby.new())
		root.add_child(c)
		root.add_child(HiddenSpawner.new()) # same root-relative path as the server's: candidate replication
		assert_int(c.join("127.0.0.1", _next_port, "P%d" % i)).is_equal(OK)
		_clients.append(c)
	await _until(_all_joined, "%d clients joined" % clients)


## Composes a round for the joined clients (or for 5 made-up ids when none joined).
func _compose() -> void:
	var tokens := PackedStringArray()
	for c in _clients:
		tokens.append("t%d" % c.local_player_id)
	if tokens.is_empty():
		tokens = PackedStringArray(["t1", "t2", "t3", "t4", "t5"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 10
	var roster := Roster.lock(tokens, _info, SESSION, 1, _knobs, RotationQueue.new(), rng)
	assert_object(roster).is_not_null()
	var server_root := _roots[0]
	_c = RoundComposer.new(_knobs, roster, MapData.load_map(), _net, server_root.multiplayer as SceneMultiplayer,
			server_root as Node3D, TestMoveStep.apply, TestMoveStep.WORLD, TestMoveStep.make_body, _no_look)
	_c.on_over = _on_over
	var hidden := HiddenSpawner.new()
	server_root.add_child(hidden)
	_c.hidden = hidden
	_server = auto_free(RoundServer.new())
	add_child(_server)
	assert_array(_c.start(_server, rng)).is_empty()
	_server.tick_runner.set_physics_process(false) # the test steps every tick itself
	_act = ActStep.new()
	_server.tick_runner.register_feature(FeatureStep.new(_act, _server.bus), TickOrder.HOLDS + 1)
	for type: StringName in [&"SurvivorDowned", &"MonsterStunned", &"ObjectiveProgressChanged", &"RoundEnded",
			&"RoundPhaseChanged"]:
		_server.bus.subscribe(type, _on_event)


## Every script-declared Callable or Object property of `obj` that is unset, as "Class.name".
func _unset(obj: Object) -> Array[String]:
	var out: Array[String] = []
	var cls := (obj.get_script() as Script).get_global_name()
	for prop in obj.get_property_list():
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var v: Variant = obj.get(prop.name)
		var key := "%s.%s" % [cls, prop.name]
		if OPTIONAL.has(key):
			continue
		if prop.type == TYPE_CALLABLE and not (v as Callable).is_valid():
			out.append(key)
		elif prop.type == TYPE_OBJECT and v == null:
			out.append(key)
	return out


## AC-1, AC-2: after start every module exists and no hook of any of them is left unset.
func test_every_module_built_and_every_hook_wired() -> void:
	_root() # server root, never hosting: the audit needs no network
	_net = NetAuthority.new()
	_net.setup(_knobs, SERVER_VERSION, FakeLobby.new())
	_roots[0].add_child(_net)
	_compose()
	var modules: Array[Object] = [_c.holds, _c.doors, _c.downing, _c.bf, _c.sd, _c.hs, _c.bars, _c.objectives,
			_c.ma, _c.lifecycle, _c.lifecycle.match_flow(), _c.sm, _c.lighting, _c.offset, _c.view, _c.candidates, _c.controller, _c.footsteps, _c.lighting_rep, _c.cams]
	var unset: Array[String] = []
	for m in modules:
		assert_object(m).is_not_null()
		unset.append_array(_unset(m))
	assert_array(unset).override_failure_message("unset hooks:\n" + "\n".join(unset)).is_empty()
	assert_int(_c.sm.batch_extras.size()).is_equal(7)
	assert_bool(_c.sm.batch_extras.has(Callable(_c.lighting_rep, &"entries"))).is_true() ## facility-map story 010
	assert_bool(_c.sm.batch_extras.has(Callable(_c.ping_delivery, &"entries"))).is_true() ## pings-and-callouts story 004
	assert_int(_c.sm.catch_up.size()).is_equal(3)
	# Every registered hold is reachable from some map object the aim ray can pick.
	var reachable := 0
	for ids: Array in _c._ids_at.values():
		reachable += ids.size()
	assert_int(reachable).is_equal(_c.holds._items.size())
	assert_array(_c._ids_at.get(0, [])).contains([0]) # door 0 keeps net id 0
	# Doors took the first net ids: a door's net id is its map index.
	var targets := MapData.load_map().interactables()
	for i in targets.size():
		if targets[i] is MapPassage:
			assert_bool(_c.doors.is_closed(i)).is_false()
	# Decided folds: the shock lock bars holds, door use and a monster's break; hidden is not objective-healthy.
	var s := _c.survivors[0]
	assert_bool(_c._objective_healthy(s)).is_true()
	_c.sd.set_hidden(s, true)
	assert_bool(_c._objective_healthy(s)).is_false()
	assert_bool(_c._barred(_c.monster)).is_false()
	assert_bool(_c._monster_free(_c.monster)).is_true()
	assert_bool(_c._monster_free(s)).is_false()
	# FacilityLighting's objective_volume answers the terminal's volume from the active points.
	assert_str(_c._objective_volume(SurvivorObjectives.TERMINAL_ID)).is_not_empty()
	assert_str(_c._objective_volume(-5)).is_empty()
	# Story controller-interaction/013: the flinch toggle view is registered and a change reaches ViewOffset.
	var settings := _c.server.registry.view(StateKeys.CAMERA_FLINCH_TOGGLE, PlayerSettingsView) as PlayerSettingsView
	assert_object(settings).is_not_null()
	_net.set_flinch_enabled(s, true)
	assert_bool(settings.is_flinch_enabled(s)).is_true()
	assert_bool(_c.offset._players[s].enabled).is_true()
	_net.set_flinch_enabled(s, false)
	assert_bool(_c.offset._players[s].enabled).is_false()


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


## Steps (polling) until `cond` or `max_ticks`; true when `cond` held.
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


func _pick_up(_tick: int, actor: int) -> void:
	for i: Interactable in _c.holds._items:
		if i is ObjectivePoint and i.eligible(actor):
			i.on_complete(actor)
			return


func _hide(_tick: int, actor: int) -> void:
	_c.hs.hide_completed(actor, 0)


func _barricade(_tick: int, door: int) -> void:
	if not _c.doors.is_closed(door):
		_c.doors.toggle(door)
	_c.bars.complete(door, false)


## AC-3: 5 real ENet clients: Loading -> Running on their map-loaded reports; a requested lunge downs a
## survivor, a fired taser stuns the monster, a hide, a barricade and objective progress; then the deadline
## ends the round (RoundEnded), Results runs out and the composer tears the round down (Over).
func test_five_client_scripted_round_reaches_round_end() -> void:
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
	var door := -1
	for net_id in MapData.load_map().interactables().size():
		if _c.bars.build_id(net_id) != -1:
			door = net_id
			break
	_act.queue.append_array([_pick_up.bind(_c.survivors[2]), _hide.bind(_c.survivors[3]), _barricade.bind(door)])
	_step(2)
	assert_bool(_saw(&"ObjectiveProgressChanged")).override_failure_message("no objective progress").is_true()
	assert_int(_c.hs.occupant(0)).is_equal(_c.survivors[3])
	assert_bool(_c.bars.is_barricaded(door)).is_true()
	# The deadline: elapsed_s reaches round_duration_s, then Results runs results_duration_s.
	var to_end := _knobs.ticks(_knobs.match_flow.round_duration_s) + _knobs.ticks(_knobs.match_flow.results_duration_s) + 10
	for i in to_end:
		if not _over.is_empty():
			break
		_server.tick_runner.step()
		if i % POLL_EVERY == 0:
			_poll()
	assert_bool(_saw(&"RoundEnded")).override_failure_message("no RoundEnded").is_true()
	assert_array(_over).is_equal([true])
	assert_int(_seen.get(&"RoundEnded", 0)).is_equal(1)
