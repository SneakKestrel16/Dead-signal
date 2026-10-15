# Story downing-and-rescue/007: life state replication and information hiding (design/gdd/downing-and-rescue.md
# ACs on 5-client agreement, forged messages and the monster's missing bleed-out state; ADR-0004 §5).
# The real-ENet cases run a server (RoundServer with Downing, ServerMovement) and 5 clients on 127.0.0.1,
# each client with a ClientEventRouter feeding a LifeDisplay, extending NA-8/NA-9's capture test. Bodies
# stand 30 m apart, so no life state depends on relevance. The ring case drives Downing directly and
# builds the bytes a survivor viewer receives through EventBatch, as ServerMovement does.
extends GdUnitTestSuite

const SERVER_VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
## design/gdd/downing-and-rescue.md AC: every client shows the change within 250 ms of the server event.
const MAX_LATENCY_MS := 250
const SPACING_M := 30.0

static var _next_port := 26700

class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0


## Runs each scheduled event or Callable in the Monster Abilities slot (stands in for the real emitters).
class Emitter extends RefCounted:
	var _bus: EventBus
	var _due: Dictionary[int, Array] = {}

	func setup(_runner: TickRunner, bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
		_bus = bus

	func at(tick: int, what: Variant) -> void:
		if not _due.has(tick):
			_due[tick] = []
		_due[tick].append(what)

	func server_tick(tick: int) -> void:
		for w: Variant in _due.get(tick, []):
			if w is Callable:
				(w as Callable).call()
			else:
				_bus.emit(w as ServerEvent)


var _knobs: Knobs
var _roots: Array[Node] = []
var _server: RoundServer
var _sm: ServerMovement
var _net: NetAuthority
var _server_root: Node
var _d: Downing
var _emitter: Emitter
var _bodies: Dictionary = {}
var _clients: Array[NetAuthority] = []
var _routers: Array[ClientEventRouter] = []
var _displays: Array[LifeDisplay] = []
var _survivors: Array[int] = []
var _monster: int = -1
var _monster_capture: Array[PackedByteArray] = []
var _survivor_capture: Array[PackedByteArray] = []
var _life_events: Array[ServerEvent] = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_bodies = {}
	_clients = []
	_routers = []
	_displays = []
	_survivors = []
	_monster = -1
	_monster_capture = []
	_survivor_capture = []
	_life_events = []


func after_test() -> void:
	if _sm != null:
		_sm.detach()
		_sm = null
	for r in _routers:
		r.close()
	if _server != null:
		_server.end_round()
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


# --- rig ------------------------------------------------------------------------

func _root() -> Node:
	var n := Node.new()
	n.name = "Lr%d" % _roots.size()
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


func _on_joined(pid: int) -> void:
	_bodies[pid] = TestMoveStep.make_body(_server_root, Vector3(SPACING_M * _bodies.size(), 0.0, 0.0))
	_sm.add_player(pid, _bodies[pid])
	_sm.set_frozen(pid, true)


func _all_joined() -> bool:
	if _bodies.size() < 5:
		return false
	for c in _clients:
		if c.local_player_id == -1:
			return false
	return true


func _pos(p: int) -> Vector3:
	return (_bodies[p] as Node3D).global_position


func _on_monster_packet(_peer: int, bytes: PackedByteArray) -> void:
	_monster_capture.append(bytes)


func _on_survivor_packet(_peer: int, bytes: PackedByteArray) -> void:
	_survivor_capture.append(bytes)


func _on_life_event(e: ServerEvent) -> void:
	_life_events.append(e)


## A server, 5 joined clients (the 5th is the shapeshifter) and a running round with Downing.
func _rig() -> void:
	_server_root = _root()
	_net = NetAuthority.new()
	_net.setup(_knobs, SERVER_VERSION, FakeLobby.new())
	_server_root.add_child(_net)
	_next_port += 1
	assert_int(_net.host(_next_port)).is_equal(OK)
	_sm = ServerMovement.new(_knobs, _net, _server_root.multiplayer as SceneMultiplayer, TestMoveStep.apply, TestMoveStep.WORLD)
	_net.player_joined.connect(_on_joined)
	for i in 5:
		var root := _root()
		var net := NetAuthority.new()
		net.setup(_knobs, SERVER_VERSION, FakeLobby.new())
		root.add_child(net)
		assert_int(net.join("127.0.0.1", _next_port, "P%d" % i)).is_equal(OK)
		_clients.append(net)
		var router := ClientEventRouter.new(root.multiplayer as SceneMultiplayer)
		_routers.append(router)
		_displays.append(LifeDisplay.new(router))
	await _until(_all_joined, "5 clients joined")
	for i in 4:
		_survivors.append(_clients[i].local_player_id)
	_monster = _clients[4].local_player_id
	(_clients[4].multiplayer as SceneMultiplayer).peer_packet.connect(_on_monster_packet)
	(_clients[1].multiplayer as SceneMultiplayer).peer_packet.connect(_on_survivor_packet)
	_d = Downing.new()
	_d.set_roster(_survivors, _monster)
	_d.set_positions(_pos)
	_emitter = Emitter.new()
	_server = auto_free(RoundServer.new())
	add_child(_server)
	assert_array(_server.start_round({TickOrder.MONSTER_ABILITIES: _emitter, TickOrder.DOWNING: _d}, _knobs)).is_empty()
	_server.tick_runner.set_physics_process(false) # the test steps every tick itself
	_sm.monster = _monster
	_sm.batch_extras.append(_d.ring_entries)
	_sm.attach(_server.tick_runner)
	for type: StringName in [&"SurvivorDowned", &"SurvivorRescued", &"SurvivorEliminated"]:
		_server.bus.subscribe(type, _on_life_event)


func _now() -> int:
	return _server.tick_runner.current_tick()


func _hit(survivor: int) -> void:
	var hit := EvSurvivorHit.new()
	hit.survivor = survivor
	_emitter.at(_now() + 1, hit)


## What a client roster shows for the server's state: Seized is body presentation (ADR-0004 §2), not a
## roster state, so a Seized survivor still reads Healthy there.
func _shown(s: int) -> int:
	var st := _d.life_state(s)
	return Downing.LifeState.HEALTHY if st == Downing.LifeState.SEIZED else st


func _converged() -> bool:
	for disp in _displays:
		for s in _survivors:
			if disp.life_state(s) != _shown(s) or disp.downs_taken(s) != _d.downs_taken(s):
				return false
	return true


## Steps `n` ticks, then waits until all 5 displays match the server; the wait is the replication latency.
func _step_and_measure(n: int, what: String) -> void:
	for i in n:
		_server.tick_runner.step()
	var t0 := Time.get_ticks_msec()
	await _until(_converged, what)
	var ms := Time.get_ticks_msec() - t0
	assert_int(ms).override_failure_message("%s took %d ms on the slowest client" % [what, ms]).is_less_equal(MAX_LATENCY_MS)


func _ring_known() -> bool:
	for i in 4:
		if _displays[i].bleed_rate(_survivors[0]) < 0.0:
			return false
	return true


# --- AC1 + AC2: all 5 clients agree; the shapeshifter never gets bleed-out state ------

func test_five_clients_show_the_same_life_state_and_downs_and_only_survivors_get_bleed_out() -> void:
	await _rig()
	var a := _survivors[0]
	var b := _survivors[1]
	var commit := _knobs.ticks(_knobs.downing.takedown_commit_s)
	_hit(a)
	await _step_and_measure(1, "hit")
	assert_int(_d.life_state(a)).is_equal(Downing.LifeState.SEIZED)
	await _step_and_measure(commit, "commit")
	assert_int(_d.life_state(a)).is_equal(Downing.LifeState.DOWNED)
	_server.tick_runner.step() # the first bleed-out step publishes the ring
	await _until(_ring_known, "ring on survivor clients")
	for i in 4:
		assert_float(_displays[i].bleed_remaining_s(a)).is_greater(0.0)
	assert_float(_displays[4].bleed_remaining_s(a)).is_equal(-1.0)
	assert_float(_displays[4].bleed_rate(a)).is_equal(-1.0)
	_emitter.at(_now() + 1, _d.rescue_completed.bind(a, b))
	await _step_and_measure(1, "rescue")
	assert_int(_d.life_state(a)).is_equal(Downing.LifeState.HEALTHY)
	for i in _knobs.ticks(_knobs.downing.post_rescue_grace_s):
		_server.tick_runner.step()
	_hit(a)
	await _step_and_measure(1 + commit, "elimination")
	assert_int(_d.life_state(a)).is_equal(Downing.LifeState.ELIMINATED)
	assert_int(_d.downs_taken(a)).is_equal(_knobs.downing.downs_to_eliminate)
	for disp in _displays:
		assert_int(disp.rejected).is_equal(0)
	# Packet capture: the monster's client holds no bleed-out field and no ring entry; a survivor's has both.
	var monster_types := _types_and_keys(_monster_capture)
	assert_bool(monster_types.has(&"SurvivorDowned")).is_true()
	assert_bool(monster_types.has(EventBatch.BLEED_RING)).is_false()
	assert_bool(monster_types.has("bleed_out_s")).is_false()
	var survivor_types := _types_and_keys(_survivor_capture)
	assert_bool(survivor_types.has(EventBatch.BLEED_RING)).is_true()
	assert_bool(survivor_types.has("bleed_out_s")).is_true()


## Every entry type and payload key in the event batches of `capture`.
func _types_and_keys(capture: Array[PackedByteArray]) -> Dictionary:
	var seen := {}
	for bytes in capture:
		if not EventBatch.is_message(bytes):
			continue
		for entry: Array in EventBatch.decode(bytes).entries:
			seen[entry[0]] = true
			for k: Variant in entry[1]:
				seen[k] = true
	return seen


# --- AC3: forged messages from a client change nothing -------------------------

func test_forged_rescue_complete_and_survivor_downed_from_clients_change_nothing() -> void:
	await _rig()
	var a := _survivors[0]
	var b := _survivors[1]
	var c := _survivors[2]
	_hit(a)
	await _step_and_measure(1 + _knobs.ticks(_knobs.downing.takedown_commit_s), "down")
	_life_events.clear()
	var rescue := {"survivor": a, "rescuer": b}
	var downed := {"survivor": c, "bleed_out_s": 1.0}
	_forge(_clients[0], &"SurvivorRescued", rescue) # the Downed survivor claims its own rescue
	_forge(_clients[4], &"SurvivorDowned", downed) # the shapeshifter claims a down
	await _until(func() -> bool: return _sm.malformed_drops + _dropped() >= 4, "forged packets reached the server")
	for i in 5:
		_server.tick_runner.step()
	await _until(_converged, "clients settle")
	assert_array(_life_events).is_empty()
	assert_int(_d.life_state(a)).is_equal(Downing.LifeState.DOWNED)
	assert_int(_d.downs_taken(a)).is_equal(1)
	assert_int(_d.life_state(c)).is_equal(Downing.LifeState.HEALTHY)
	assert_int(_d.downs_taken(c)).is_equal(0)
	for disp in _displays:
		assert_int(disp.life_state(a)).is_equal(Downing.LifeState.DOWNED)
		assert_int(disp.life_state(c)).is_equal(Downing.LifeState.HEALTHY)


## Sends the server the event both as an event batch and as a Dictionary, on both channels a client uses.
func _forge(client: NetAuthority, type: StringName, payload: Dictionary) -> void:
	var api := client.multiplayer as SceneMultiplayer
	var batch := PackedByteArray([EventBatch.TAG])
	batch.append_array(var_to_bytes([_now(), [[type, payload]]]))
	api.send_bytes(batch, 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE, NetChannels.EVENT)
	var dict := payload.duplicate()
	dict["type"] = type
	api.send_bytes(var_to_bytes(dict), 1, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, NetChannels.STATE)


func _dropped() -> int:
	var n := 0
	for p: int in _bodies:
		n += _sm.queue_of(p).dropped_packets
	return n


# --- AC2: the ring carries no identity -----------------------------------------

## The bytes survivor viewer S3 receives each tick while a Downed S1 is first camped at 1 m inside the
## slow radius, then left at 1 m outside it, by `camper` (the shapeshifter or survivor S2).
func _ring_bytes(camper: int) -> Array[PackedByteArray]:
	const M := 1
	const S1 := 2
	const S3 := 4
	var survivors: Array[int] = [2, 3, 4, 5]
	var r := _knobs.downing.camp_slow_radius_m
	var at := {S1: Vector3.ZERO}
	for p in [1, 3, 4, 5]:
		at[p] = Vector3(SPACING_M * p, 0.0, 0.0)
	var server: RoundServer = auto_free(RoundServer.new())
	var d := Downing.new()
	d.set_roster(survivors, M)
	d.set_positions(func(p: int) -> Vector3: return at[p])
	var em := Emitter.new()
	assert_array(server.start_round({TickOrder.MONSTER_ABILITIES: em, TickOrder.DOWNING: d}, _knobs)).is_empty()
	var hit := EvSurvivorHit.new()
	hit.survivor = S1
	em.at(1, hit)
	var handles := HandleTable.new()
	var none: Array[ServerEvent] = []
	var out: Array[PackedByteArray] = []
	var commit := _knobs.ticks(_knobs.downing.takedown_commit_s)
	for leg: Array in [[r - 1.0, 1 + commit + 5], [r + 1.0, 5]]: # [camper's distance, ticks]
		at[camper] = Vector3(leg[0], 0.0, 0.0)
		for i in leg[1]:
			server.tick_runner.step()
			var tick := server.tick_runner.current_tick()
			assert_array(d.ring_entries(M)).is_empty()
			out.append(EventBatch.build(tick, S3, none, [], Vector3.ZERO, handles, M, d.ring_entries(S3)))
	server.end_round()
	return out


func test_ring_is_identical_whether_a_survivor_or_the_shapeshifter_slows_it() -> void:
	var by_monster := _ring_bytes(1)
	var by_survivor := _ring_bytes(3)
	assert_array(by_monster).is_equal(by_survivor)
	var rates := []
	for bytes in by_monster:
		if bytes.is_empty():
			continue
		for entry: Array in EventBatch.decode(bytes).entries:
			rates.append(entry[1].rate)
	# Two changes: slowed while camped, full rate once the camper steps out (sent on change only).
	assert_array(rates).is_equal([_knobs.downing.camp_slow_mult, 1.0])


# --- client display validation ---------------------------------------------------

func _batch(entries: Array) -> PackedByteArray:
	var out := PackedByteArray([EventBatch.TAG])
	out.append_array(var_to_bytes([7, entries]))
	return out


func test_display_rejects_bad_payloads_and_ignores_other_peers() -> void:
	var router := ClientEventRouter.new()
	var disp := LifeDisplay.new(router)
	router.on_packet(5, _batch([[&"SurvivorDowned", {"survivor": 2, "bleed_out_s": 10.0}]])) # not the server
	assert_int(disp.life_state(2)).is_equal(Downing.LifeState.HEALTHY)
	router.on_packet(1, _batch([[&"SurvivorDowned", {"survivor": "2"}], [&"SurvivorEliminated", {"survivor": 2, "reason": 9}],
		[EventBatch.BLEED_RING, {"survivor": 2, "remaining_s": 5.0, "rate": 1.0}], # not Downed: ignored
		[&"SurvivorDowned", {"survivor": 2, "bleed_out_s": NAN}]]))
	assert_int(disp.rejected).is_equal(4)
	assert_int(disp.life_state(2)).is_equal(Downing.LifeState.HEALTHY)
	assert_int(disp.downs_taken(2)).is_equal(0)
	router.on_packet(1, _batch([[&"SurvivorDowned", {"survivor": 2, "bleed_out_s": 10.0}],
		[EventBatch.BLEED_RING, {"survivor": 2, "remaining_s": 8.0, "rate": 0.5}]]))
	disp.advance(2.0)
	assert_float(disp.bleed_remaining_s(2)).is_equal_approx(7.0, 1e-6)
	router.on_packet(1, _batch([[&"SurvivorEliminated", {"survivor": 2, "reason": EvSurvivorEliminated.BLED_OUT}]]))
	assert_int(disp.life_state(2)).is_equal(Downing.LifeState.ELIMINATED)
	assert_int(disp.downs_taken(2)).is_equal(1) # bled out: no extra down
	assert_float(disp.bleed_remaining_s(2)).is_equal(-1.0)
