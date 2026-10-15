# Story scare-events/004 (TR-scare-001, TR-scare-010; design/gdd/scare-events.md rules 2, 4, 4a, 5; ADR-0005).
# A composed round: BarricadeBroken fires door_burst, FormChanged into true form fires transformation_reveal,
# a Blackout AbilityUsed fires blackout, each to the live players ScareRelevance picks (in range or in sight; the
# acting monster excluded); over real ENet the in-range clients receive ScareTriggered and the others do not.
# 20 False Signals of every type emit no ScareTriggered; no scare changes health, down state, objective
# progress, cooldowns or position. Pending: the fake-vs-real callout packet capture (Pings & Callouts PC-6/007).
extends GdUnitTestSuite

const SERVER_VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
const SESSION := "s-se4"
## Far from every map door (round_composer_test's spot).
const BASE := Vector3(300.0, 0.0, 300.0)
## Beyond every Monster-source audible range from anything near BASE.
const FAR := Vector3(0.0, 0.0, 100.0)
## Half-size of the sight-blocking booth _hide puts around an out-of-range player's eye, m.
const BOOTH_M := 1.0
const FALSE_SIGNALS := 20

static var _next_port := 28170


class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0


## Emits the test's queued events inside a tick, after the Holds step.
class EmitStep extends RefCounted:
	var queue: Array[ServerEvent] = []
	var bus: EventBus

	func setup(_runner: TickRunner, bus_: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
		bus = bus_

	func server_tick(_tick: int) -> void:
		var q := queue
		queue = []
		for e in q:
			bus.emit(e)


var _knobs: Knobs
var _server: RoundServer
var _c: RoundComposer
var _roots: Array[Node] = []
var _clients: Array[NetAuthority] = []
var _routers: Array[ClientEventRouter] = []
## client index -> ScareTriggered payload scare ids received.
var _got: Array = []
var _net: NetAuthority
var _emit: EmitStep
## [scare_id, recipient] of every server ScareTriggered.
var _scares: Array = []
var _used := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_clients = []
	_routers = []
	_got = []
	_scares = []
	_used = 0


func after_test() -> void:
	if _c != null:
		_c.stop()
		_c = null
	await get_tree().process_frame
	_server = null
	_routers.clear()
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
	n.name = "Se4_%d" % _roots.size()
	get_tree().root.add_child(n)
	get_tree().set_multiplayer(SceneMultiplayer.new(), n.get_path())
	_roots.append(n)
	return n


func _poll() -> void:
	for r in _roots:
		(r.multiplayer as SceneMultiplayer).poll()


func _info(token: String) -> Dictionary:
	var pid := token.trim_prefix("t").to_int()
	return {"player_id": pid, "name": "P%d" % pid}


func _no_look(_id: int) -> int:
	return 0


func _all_joined() -> bool:
	for c in _clients:
		if c.local_player_id == -1:
			return false
	return true


func _on_client_scare(_tick: int, p: Dictionary, client: int) -> void:
	_got[client].append(p["scare"])


## Hosts on a fresh port and joins `clients` real ENet clients, each with a ClientEventRouter.
func _rig(clients: int) -> void:
	_net = NetAuthority.new()
	_net.setup(_knobs, SERVER_VERSION, FakeLobby.new())
	_root().add_child(_net)
	_next_port += 1
	assert_int(_net.host(_next_port)).is_equal(OK)
	for i in clients:
		var root := _root()
		var c := NetAuthority.new()
		c.setup(_knobs, SERVER_VERSION, FakeLobby.new())
		root.add_child(c)
		root.add_child(HiddenSpawner.new())
		assert_int(c.join("127.0.0.1", _next_port, "P%d" % i)).is_equal(OK)
		_clients.append(c)
		var router := ClientEventRouter.new(root.multiplayer as SceneMultiplayer)
		router.subscribe(&"ScareTriggered", _on_client_scare.bind(i))
		_routers.append(router)
		_got.append([])
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while Time.get_ticks_msec() < end and not _all_joined():
		_poll()
		await get_tree().process_frame
	assert_bool(_all_joined()).override_failure_message("clients never joined").is_true()


## A composed, Running round (joined clients, or 5 made-up ids and no network), every player frozen far apart.
func _compose() -> void:
	if _roots.is_empty():
		_net = NetAuthority.new()
		_net.setup(_knobs, SERVER_VERSION, FakeLobby.new())
		_root().add_child(_net)
	var tokens := PackedStringArray()
	for c in _clients:
		tokens.append("t%d" % c.local_player_id)
	if tokens.is_empty():
		tokens = PackedStringArray(["t1", "t2", "t3", "t4", "t5"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 10
	var roster := Roster.lock(tokens, _info, SESSION, 1, _knobs, RotationQueue.new(), rng)
	var server_root := _roots[0]
	_c = RoundComposer.new(_knobs, roster, MapData.load_map(), _net, server_root.multiplayer as SceneMultiplayer,
			server_root as Node3D, TestMoveStep.apply, TestMoveStep.WORLD, TestMoveStep.make_body, _no_look)
	_server = auto_free(RoundServer.new())
	add_child(_server)
	assert_array(_c.start(_server, rng)).is_empty()
	_server.tick_runner.set_physics_process(false)
	_emit = EmitStep.new()
	_emit.bus = _server.bus
	_server.tick_runner.register_feature(FeatureStep.new(_emit, _server.bus), TickOrder.HOLDS + 1)
	_server.bus.subscribe(&"ScareTriggered", _on_scare)
	_server.bus.subscribe(&"AbilityUsed", _on_used)
	for id in roster.player_ids():
		_c.lifecycle.report_loaded(id)
	for i in _knobs.ticks(1.0):
		if _c.lifecycle.state() == RoundLifecycle.State.RUNNING:
			break
		_step(1)
	assert_int(_c.lifecycle.state()).is_equal(RoundLifecycle.State.RUNNING)
	for id in roster.player_ids():
		_hide(id, BASE + FAR * float(id + 1))


func _on_scare(e: ServerEvent) -> void:
	var s := e as EvScareTriggered
	_scares.append([s.scare_id, s.recipient])


func _on_used(_e: ServerEvent) -> void:
	_used += 1


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()
		_poll()


func _place(id: int, at: Vector3) -> void:
	_c.sm.set_frozen(id, true)
	_c.bodies[id].global_position = at


func _got_scare(id: StringName) -> Array[int]:
	var out: Array[int] = []
	for s: Array in _scares:
		if s[0] == id:
			out.append(s[1])
	out.sort()
	return out


func _barricadable() -> int:
	var items := _c.map.interactables()
	for i in items.size():
		var p := items[i] as MapPassage
		if p != null and p.kind == MapPassage.BARRICADABLE:
			return i
	return -1


func _broken(net_id: int) -> EvBarricadeBroken:
	var e := EvBarricadeBroken.new()
	e.barricade = net_id
	return e


func _form(previous: int, form: int) -> EvFormChanged:
	var e := EvFormChanged.new()
	e.player = _c.monster
	e.previous = previous
	e.form = form
	return e


func _blackout(at: Vector3) -> EvAbilityUsed:
	var e := EvAbilityUsed.new()
	e.ability = MonsterAbilities.Ability.BLACKOUT
	e.position = _c.bodies[_c.monster].global_position
	e.target = at
	return e


func _false_signal(type: int) -> EvAbilityUsed:
	var e := EvAbilityUsed.new()
	e.ability = MonsterAbilities.Ability.FALSE_SIGNAL
	e.position = _c.bodies[_c.monster].global_position
	e.target = e.position + Vector3(2.0, 0.0, 0.0)
	e.detail = MonsterAbilities.SIGNAL_DETAILS[type]
	if type != MonsterAbilities.SignalType.INTERACTION:
		e.survivor = _c.survivors[0]
	if type == MonsterAbilities.SignalType.CALLOUT:
		e.line = PingsCallouts.CALLOUT_LINES[0]
	return e


## Places `id` frozen at `at` inside a closed sight-blocking booth (PhysicsLayers.SIGHT), so the composed
## ScareRelevance (story 003, behind MonsterScares) cannot add it by line of sight: the composed round has no
## map collision, so without it every player sees every origin.
func _hide(id: int, at: Vector3) -> void:
	_place(id, at)
	var booth := StaticBody3D.new()
	booth.collision_layer = PhysicsLayers.SIGHT
	booth.collision_mask = 0
	for side: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
		var wall := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = (Vector3.ONE - side.abs()) * 2.0 * BOOTH_M + side.abs() * 0.2
		wall.shape = box
		wall.position = side * BOOTH_M
		booth.add_child(wall)
	_roots[0].add_child(booth)
	booth.global_position = at + Vector3.UP * _knobs.controller.eye_height_m


## Range of entry `id` from the shipped catalogue.
func _range(id: StringName) -> float:
	return ScareCatalogue.load_shipped().entry(id).audible_range_m


## The server state no scare may change (rule 4): positions, health / down state, round status, objective
## progress and ability cooldowns.
func _snapshot() -> Dictionary:
	var out := {}
	for id in _c.roster.player_ids():
		out["pos%d" % id] = _c.bodies[id].global_position
		out["life%d" % id] = _c.downing.life_state(id)
		out["downs%d" % id] = _c.downing.downs_taken(id)
		out["status%d" % id] = _c.lifecycle.match_flow().status_of(id)
	var o := _c.objectives
	out["terminal"] = o.terminal_state()
	out["power"] = o.power_restored()
	out["exit"] = o.exit_open()
	for i in o.drive_count():
		out["drive%d" % i] = [o.state_of(i), o.carrier_of(i)]
	# No public fuse count: the arrays fuse_state_of / fuse_carrier_of / box_fuse_of read.
	out["fuses"] = [o._fuse_states.duplicate(), o._fuse_carriers.duplicate(), o._box_fuses.duplicate()]
	for a in MonsterAbilities.Ability.values():
		out["ready%d" % a] = _c.ma.ready_tick(a)
	return out


## AC-1: each trigger fires its Monster-source scare to the live players within the entry's audible range,
## never to the acting monster or a player out of range; a FormChanged that is not a reveal fires nothing.
func test_barricade_break_reveal_and_blackout_fire_to_players_in_range() -> void:
	_compose()
	var s := _c.survivors
	var door := _barricadable()
	assert_int(door).is_not_equal(-1)
	var at := (_c.map.interactables()[door] as MapPassage).position
	_place(_c.monster, at + Vector3(1.0, 0.0, 0.0))
	_place(s[0], at + Vector3(_range(MonsterScares.BURST) - 1.0, 0.0, 0.0))
	_hide(s[1], at + Vector3(_range(MonsterScares.BURST) + 1.0, 0.0, 0.0))
	await get_tree().physics_frame # the booths enter the physics space
	_emit.queue.append(_broken(door))
	_step(1)
	assert_array(_got_scare(MonsterScares.BURST)).is_equal([s[0]])
	_place(_c.monster, BASE)
	_place(s[2], BASE + Vector3(0.0, 0.0, _range(MonsterScares.REVEAL) - 1.0))
	_hide(s[3], BASE + Vector3(0.0, 0.0, -_range(MonsterScares.REVEAL) - 1.0))
	_hide(s[0], _c.bodies[s[0]].global_position) # in the door's range, but sight would reach BASE
	_emit.queue.append(_form(BorrowedFace.TRUE_FORM, s[0])) # disguising: no scare
	_emit.queue.append(_form(s[0], s[1])) # face to face: no scare
	_step(1)
	await get_tree().physics_frame # the booths enter the physics space
	_emit.queue.append(_form(s[1], BorrowedFace.TRUE_FORM))
	_step(1)
	assert_array(_got_scare(MonsterScares.REVEAL)).is_equal([s[2]])
	var dark := BASE + Vector3(0.0, 0.0, 40.0)
	_place(s[0], dark + Vector3(_range(MonsterScares.BLACKOUT) - 1.0, 0.0, 0.0))
	_hide(s[1], dark + Vector3(-_range(MonsterScares.BLACKOUT) - 1.0, 0.0, 0.0))
	_hide(s[2], _c.bodies[s[2]].global_position) # in the reveal's range, but sight would reach dark
	await get_tree().physics_frame # the booths enter the physics space
	_emit.queue.append(_blackout(dark))
	_step(1)
	assert_array(_got_scare(MonsterScares.BLACKOUT)).is_equal([s[0]])
	for r: Array in _scares:
		assert_int(r[1]).is_not_equal(_c.monster)


## AC-1 over real ENet: the in-range clients receive the door burst, the others receive nothing.
## AC-2: 20 False Signals of every type emit no ScareTriggered on the server and none reaches any client.
func test_clients_get_burst_in_range_and_never_a_scare_from_false_signal() -> void:
	await _rig(5)
	_compose()
	var s := _c.survivors
	_place(_c.monster, BASE)
	for id in s:
		_place(id, BASE + Vector3(2.0 * (id + 1), 0.0, 0.0)) # every survivor in every range
	for type in MonsterAbilities.SignalType.values():
		for i in FALSE_SIGNALS:
			_emit.queue.append(_false_signal(type))
			_step(1)
	assert_int(_used).is_equal(FALSE_SIGNALS * MonsterAbilities.SignalType.size())
	assert_array(_scares).is_empty()
	var door := _barricadable()
	var at := (_c.map.interactables()[door] as MapPassage).position
	_place(s[0], at + Vector3(2.0, 0.0, 0.0))
	_hide(s[1], at + Vector3(_range(MonsterScares.BURST) + 5.0, 0.0, 0.0))
	for id in s.slice(2):
		_hide(id, BASE + FAR * float(id + 1))
	await get_tree().physics_frame # the booths enter the physics space
	_emit.queue.append(_broken(door))
	_step(1)
	var client_of := {}
	for i in _clients.size():
		client_of[_clients[i].local_player_id] = i
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while Time.get_ticks_msec() < end and _got[client_of[s[0]]].is_empty():
		_step(1)
		await get_tree().process_frame
	for i in 10: # let any stray packet arrive
		_step(1)
		await get_tree().process_frame
	assert_array(_got[client_of[s[0]]]).is_equal([MonsterScares.BURST])
	for id in client_of:
		if id != s[0]:
			assert_array(_got[client_of[id]]).override_failure_message("client %d got %s" % [id, _got[client_of[id]]]).is_empty()


## AC-3: every catalogue scare, fired to every live player, changes no health, down state, round status,
## objective progress, ability cooldown or position.
func test_no_scare_changes_gameplay_state() -> void:
	_compose()
	_place(_c.monster, BASE)
	for id in _c.survivors:
		_place(id, BASE + Vector3(3.0 * (id + 1), 0.0, 0.0))
	for id in _c.roster.player_ids():
		_c.offset.set_flinch_enabled(id, true)
	_step(2)
	var before := _snapshot()
	var catalogue := ScareCatalogue.load_shipped()
	var all := _c.roster.player_ids()
	var fired := 0
	for e: ScareEntry in catalogue.entries:
		var to: Array = [_c.survivors[0]] if e.scope == ScareEntry.Scope.SINGLE_CLIENT else all
		var by := -1 if e.source == ScareEntry.Source.ROUND_SCRIPT else _c.monster
		if e.source == ScareEntry.Source.SURVIVOR:
			by = _c.survivors[0]
		assert_bool(_c.scares.fire(e.scare_id, BASE + Vector3(0.0, 1.5, -4.0), to, e.source, by)).is_true()
		fired += 1
		_step(_knobs.ticks(_knobs.scare.major_scare_cooldown_s) + 1) # each delivered, flinches fully ramped
	assert_int(fired).is_equal(catalogue.entries.size())
	assert_bool(_scares.size() >= catalogue.entries.size()).is_true()
	assert_dict(_snapshot()).is_equal(before)
