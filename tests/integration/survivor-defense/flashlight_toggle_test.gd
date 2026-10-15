# Story survivor-defense/009: flashlight toggle and replicated cone (design/gdd/survivor-defense.md rules
# 2-5, 23; ADR-0002, ADR-0004). Server state, local prediction, no battery and no monster effect, Blackout
# (a lighting-flag fixture until Monster Abilities story 010 lands), and one real-ENet run showing every
# client the same cone state.
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const S2 := 3
const SURVIVORS: Array[int] = [2, 3, 4, 5]
const VERSION := "test-1.0+sd9"
const WAIT_S := 5.0
const CLIENTS := 5
## Long-held beam: well past any plausible battery (rule 2 says none).
const HOLD_S := 120.0
const BLACKOUT_S := 2.0

static var _next_port := 27300

var _server: RoundServer
var _def: SurvivorDefense
var _fx: Fixture
var _knobs: Knobs
var _monster_events: Array[ServerEvent] = []
# real-ENet rig
var _roots: Array[Node] = []
var _sm: ServerMovement
var _net: NetAuthority
var _bodies := {}
var _clients: Array[NetAuthority] = []
var _last_tick: Array[int] = []
var _entries: Array[Dictionary] = []


class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0


## Stands in for Monster Abilities: scheduled events, and Blackout as a lighting flag (story 010 pending).
class Fixture extends RefCounted:
	var _bus: EventBus
	var _due: Dictionary[int, Array] = {}
	var blackout_end_tick := -1
	var blackout_active := false

	func setup(_runner: TickRunner, bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
		_bus = bus

	func at(tick: int, e: ServerEvent) -> void:
		if not _due.has(tick):
			_due[tick] = []
		_due[tick].append(e)

	func server_tick(tick: int) -> void:
		blackout_active = tick < blackout_end_tick
		for e: ServerEvent in _due.get(tick, []):
			_bus.emit(e)


func _start() -> void:
	_knobs = Knobs.load_all()
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_def = SurvivorDefense.new()
	_def.set_roster(SURVIVORS, MONSTER)
	_fx = Fixture.new()
	_monster_events.clear()
	assert_array(_server.start_round({TickOrder.SURVIVOR_DEFENSE: _def,
		TickOrder.MONSTER_ABILITIES: _fx}, _knobs)).is_empty()
	for t: StringName in [&"MonsterStunned", &"FormChanged"]:
		_server.bus.subscribe(t, _on_monster_event)


func after_test() -> void:
	if _sm != null:
		_sm.detach()
		_sm = null
	if _server != null:
		_server.end_round()
	_clients.clear()
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


func _on_monster_event(e: ServerEvent) -> void:
	_monster_events.append(e)


func _step(n: int = 1) -> void:
	for i in n:
		_server.tick_runner.step()


func _want_light(player: int, on: bool) -> void:
	_def.request_intent(player, SurvivorDefense.light_packet(on))


# AC-1 ------------------------------------------------------------------------------------------

func test_toggle_flips_server_state_and_twice_in_one_tick_keeps_the_last() -> void:
	_start()
	assert_bool(_def.flashlight_on(S1)).is_false() # starts off
	_want_light(S1, true)
	assert_bool(_def.flashlight_on(S1)).is_false() # validated at the tick, not on receipt
	_step()
	assert_bool(_def.flashlight_on(S1)).is_true()
	assert_bool(_def.flashlight_on(S2)).is_false()
	_want_light(S1, false)
	_step()
	assert_bool(_def.flashlight_on(S1)).is_false()
	# Edge: two toggles in one tick. The client predicted on then off; the server ends where it did.
	_want_light(S1, true)
	_want_light(S1, false)
	_step()
	assert_bool(_def.flashlight_on(S1)).is_false()
	_want_light(S1, false)
	_want_light(S1, true)
	_step()
	assert_bool(_def.flashlight_on(S1)).is_true()
	# A flashlight intent does not use up the tick's fire slot.
	_def.request_intent(S2, SurvivorDefense.light_packet(true))
	_def.request_intent(S2, SurvivorDefense.fire_packet())
	_step()
	assert_bool(_def.flashlight_on(S2)).is_true()
	assert_int(_def.charges(S2)).is_equal(_knobs.defense.stun_item_charges - 1)


func test_forged_and_oversized_light_intents_change_nothing() -> void:
	_start()
	for bad: PackedByteArray in [var_to_bytes({"item": 4}), var_to_bytes({"item": true}),
			var_to_bytes({"item": SurvivorDefense.LIGHT_ON, "x": 1}), var_to_bytes("light"),
			var_to_bytes({"item": SurvivorDefense.LIGHT_ON, "pad": "x".repeat(80)})]:
		assert_int(SurvivorDefense.decode_intent(bad)).is_equal(SurvivorDefense.INVALID_INTENT)
		_def.request_intent(S1, bad)
	_step()
	assert_bool(_def.flashlight_on(S1)).is_false()


func test_local_toggle_shows_at_once_and_takes_the_server_value() -> void:
	var light := FlashlightPredictor.new()
	var bytes := light.toggle()
	# Shown on the call itself: no tick, no snapshot in between (50 ms budget, Game Feel).
	assert_bool(light.is_on()).is_true()
	assert_int(SurvivorDefense.decode_intent(bytes)).is_equal(SurvivorDefense.LIGHT_ON)
	light.take_server(false) # a snapshot from before the server applied it
	assert_bool(light.is_on()).is_true()
	light.take_server(true)
	assert_bool(light.is_on()).is_true()
	light.take_server(false) # confirmed, so a later server value wins (the server is authoritative)
	assert_bool(light.is_on()).is_false()
	assert_int(SurvivorDefense.decode_intent(light.toggle())).is_equal(SurvivorDefense.LIGHT_ON)
	assert_int(SurvivorDefense.decode_intent(light.toggle())).is_equal(SurvivorDefense.LIGHT_OFF)
	assert_bool(light.is_on()).is_false()


func test_every_client_sees_the_same_cone_state() -> void:
	await _start_net()
	var holder := _clients[1].local_player_id
	for on: bool in [true, false]:
		_def.request_intent(holder, SurvivorDefense.light_packet(on))
		await _until(_all_see.bind(holder, on), "every client sees flashlight %s" % on)
		assert_bool(_def.flashlight_on(holder)).is_equal(on)


# AC-2 ------------------------------------------------------------------------------------------

func test_long_held_beam_has_no_limit_and_no_monster_effect() -> void:
	_start()
	_want_light(S1, true)
	_def.request_intent(MONSTER, SurvivorDefense.light_packet(true)) # the monster holds no real light
	_step(_knobs.ticks(HOLD_S))
	assert_bool(_def.flashlight_on(S1)).is_true()
	assert_bool(_def.flashlight_on(MONSTER)).is_false()
	assert_array(_monster_events).is_empty() # no stun, no disguise reveal (form change)
	assert_int(_def.charges(S1)).is_equal(_knobs.defense.stun_item_charges)


func test_eliminated_survivor_shows_no_cone_and_cannot_toggle() -> void:
	_start()
	_want_light(S1, true)
	_step()
	var e := EvSurvivorEliminated.new()
	e.survivor = S1
	_fx.at(_server.tick_runner.current_tick() + 1, e)
	_step()
	assert_bool(_def.flashlight_on(S1)).is_false()
	_want_light(S1, true)
	_step()
	assert_bool(_def.flashlight_on(S1)).is_false()


# AC-3 ------------------------------------------------------------------------------------------

func test_flashlight_works_in_blackout_and_does_not_end_it() -> void:
	_start()
	var now := _server.tick_runner.current_tick()
	_fx.blackout_end_tick = now + 1 + _knobs.ticks(BLACKOUT_S)
	_step()
	assert_bool(_fx.blackout_active).is_true()
	_want_light(S1, true)
	_step()
	assert_bool(_def.flashlight_on(S1)).is_true()
	assert_bool(_fx.blackout_active).is_true()
	while _server.tick_runner.current_tick() + 1 < _fx.blackout_end_tick:
		_want_light(S1, not _def.flashlight_on(S1))
		_step()
		assert_bool(_fx.blackout_active).is_true()
	# Edge: toggle on the Blackout end tick.
	var was := _def.flashlight_on(S1)
	_want_light(S1, not was)
	_step()
	assert_int(_server.tick_runner.current_tick()).is_equal(_fx.blackout_end_tick)
	assert_bool(_fx.blackout_active).is_false()
	assert_bool(_def.flashlight_on(S1)).is_equal(not was)


# --- real-ENet rig ------------------------------------------------------------------------------

func _root() -> Node:
	var n := Node.new()
	n.name = "Fl%d" % _roots.size()
	get_tree().root.add_child(n)
	get_tree().set_multiplayer(SceneMultiplayer.new(), n.get_path())
	_roots.append(n)
	return n


func _poll() -> void:
	for r in _roots:
		(r.multiplayer as SceneMultiplayer).poll()


## Steps the server one tick per frame while waiting once the round runs (snapshots go out per tick).
func _until(cond: Callable, what: String) -> void:
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while Time.get_ticks_msec() < end:
		if _sm != null:
			_server.tick_runner.step()
		_poll()
		if cond.call():
			return
		await get_tree().process_frame
	assert_bool(cond.call()).override_failure_message("timeout waiting for " + what).is_true()


func _all_joined() -> bool:
	return _bodies.size() == CLIENTS and _clients.all(_has_id)


func _has_id(c: NetAuthority) -> bool:
	return c.local_player_id != -1


func _start_net() -> void:
	_knobs = Knobs.load_all()
	_server = auto_free(RoundServer.new())
	var server_root := _root()
	_net = NetAuthority.new()
	_net.setup(_knobs, VERSION, FakeLobby.new())
	server_root.add_child(_net)
	_next_port += 1
	var port := _next_port
	assert_int(_net.host(port)).is_equal(OK)
	_net.player_joined.connect(_on_joined.bind(server_root))
	for i in CLIENTS:
		var root := _root()
		var c := NetAuthority.new()
		c.setup(_knobs, VERSION, FakeLobby.new())
		root.add_child(c)
		assert_int(c.join("127.0.0.1", port, "P%d" % i)).is_equal(OK)
		_clients.append(c)
		_last_tick.append(-1)
		_entries.append({})
		(root.multiplayer as SceneMultiplayer).peer_packet.connect(_on_packet.bind(i))
	await _until(_all_joined, "all joined")
	var monster := _clients[0].local_player_id
	var survivors: Array[int] = []
	for c in _clients.slice(1):
		survivors.append(c.local_player_id)
	_def = SurvivorDefense.new()
	_def.set_roster(survivors, monster)
	assert_array(_server.start_round({TickOrder.SURVIVOR_DEFENSE: _def}, _knobs)).is_empty()
	_sm = ServerMovement.new(_knobs, _net, server_root.multiplayer as SceneMultiplayer, TestMoveStep.apply,
		TestMoveStep.WORLD)
	_sm.attach(_server.tick_runner)
	_sm.monster = monster
	_sm.flashlight_of = _def.flashlight_on
	for pid: int in _bodies:
		_sm.add_player(pid, _bodies[pid])
		_sm.set_frozen(pid, true)


func _on_joined(pid: int, server_root: Node) -> void:
	_bodies[pid] = TestMoveStep.make_body(server_root, Vector3(0.5 * _bodies.size(), 0.0, -1.0))


func _on_packet(peer: int, bytes: PackedByteArray, i: int) -> void:
	if peer != PuppetMap.SERVER_PEER or HandleTable.is_message(bytes) or EventBatch.is_message(bytes):
		return
	var snap := SnapshotCodec.decode(bytes)
	if snap.is_empty() or snap.tick <= _last_tick[i]:
		return
	_last_tick[i] = snap.tick
	var by_id := {}
	for b: Dictionary in snap.bodies:
		by_id[-1 if b.get("own", false) else b.id] = b
	_entries[i] = by_id


## Every client's latest snapshot shows `holder`'s body with flashlight == `on` (its own entry on the
## holder's client), and no other body's flashlight on.
func _all_see(holder: int, on: bool) -> bool:
	for i in CLIENTS:
		var viewer := _clients[i].local_player_id
		var key := -1
		if viewer != holder:
			if not _sm.scope.handles.has(viewer, holder):
				return false
			key = _sm.scope.handles.handle_for(viewer, holder)
		var e: Dictionary = _entries[i].get(key, {})
		if e.is_empty() or e.flashlight != on:
			return false
		for id: Variant in _entries[i]:
			if id != key and _entries[i][id].flashlight:
				return false
	return true
