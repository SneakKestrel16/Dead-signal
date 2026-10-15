# Story match-flow/012 (TR-matchflow-007; ADR-0004 §9; AD-194): with 3 real ENet clients on 127.0.0.1 (two
# survivors and the monster), a survivor and the monster drop, miss a barricade break and the survivor's
# charge spend, then rejoin with their tokens. Their first batch carries every batch_extras provider's full
# state for them, so their DefenseDisplay matches the client that never left and the server; the rejoining
# monster still gets no charges or hiding entries.
extends GdUnitTestSuite

const SERVER_VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
const SPACING_M := 1.5
const SETTLE_TICKS := 5

static var _next_port := 28300


class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0


## Runs the test's queued actions in the HOLDS slot, so their effects land in a tick.
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
var _net: NetAuthority
var _sd: SurvivorDefense
var _holds: HoldService
var _doors: Doors
var _bars: Barricades
var _hs: HidingSpots
var _act: ActStep
var _roots: Array[Node] = []
var _sm: ServerMovement
var _bodies: Dictionary = {}
var _clients: Array[NetAuthority] = []
var _routers: Array[ClientEventRouter] = []
var _displays: Array[DefenseDisplay] = []
var _ids: Array[int] = [] ## player id per client; the last is the monster
var _monster := -1
## per client: entry type -> count received
var _got: Array[Dictionary] = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_bodies = {}
	_clients = []
	_routers = []
	_displays = []
	_ids = []
	_got = []


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


func _root() -> Node:
	var n := Node.new()
	n.name = "Cu%d" % _roots.size()
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
	_bodies[pid] = TestMoveStep.make_body(_roots[0], Vector3(SPACING_M * (_bodies.size() + 1), 0.0, 0.0))
	_sm.add_player(pid, _bodies[pid])
	_sm.set_frozen(pid, true)


func _all_joined() -> bool:
	if _bodies.size() < 3:
		return false
	for c in _clients:
		if c.local_player_id == -1:
			return false
	return true


func _on_entry(_tick: int, _p: Dictionary, client: int, type: StringName) -> void:
	_got[client][type] = _got[client].get(type, 0) + 1


func _players() -> Array:
	return _ids


func _frames(_actor: int) -> Array:
	return []


func _centre(actor: int) -> Vector3:
	return (_bodies[actor] as Node3D).global_position


func _sight(_actor: int, _i: Interactable) -> bool:
	return true


func _claimed(_actor: int) -> int:
	return -1


func _no_capsules() -> Array[Vector4]:
	return []


func _healthy(actor: int) -> bool:
	return actor != _monster


func _is_monster(actor: int) -> bool:
	return actor == _monster


func _in_grace(_token: String) -> bool:
	return true


func _rig() -> void:
	var server_root := _root()
	_net = NetAuthority.new()
	_net.setup(_knobs, SERVER_VERSION, FakeLobby.new())
	_net.known_token_in_grace = _in_grace
	server_root.add_child(_net)
	_next_port += 1
	assert_int(_net.host(_next_port)).is_equal(OK)
	_sm = ServerMovement.new(_knobs, _net, server_root.multiplayer as SceneMultiplayer, TestMoveStep.apply, TestMoveStep.WORLD)
	_net.player_joined.connect(_on_joined)
	for i in 3:
		var root := _root()
		var c := NetAuthority.new()
		c.setup(_knobs, SERVER_VERSION, FakeLobby.new())
		root.add_child(c)
		assert_int(c.join("127.0.0.1", _next_port, "P%d" % i)).is_equal(OK)
		_clients.append(c)
		var router := ClientEventRouter.new(root.multiplayer as SceneMultiplayer)
		_routers.append(router)
		_displays.append(DefenseDisplay.new(router))
		_got.append({})
		for type: StringName in [EventBatch.CHARGES, EventBatch.HIDING, EventBatch.BARRICADE]:
			router.subscribe(type, _on_entry.bind(i, type))
	await _until(_all_joined, "3 clients joined")
	for c in _clients:
		_ids.append(c.local_player_id)
	_monster = _ids[2]
	var survivors: Array[int] = _ids.slice(0, 2)
	_sd = SurvivorDefense.new()
	_sd.set_roster(survivors, _monster)
	_holds = HoldService.new(_knobs, _players, _frames, _centre, _sight, _claimed)
	_sd.set_holds(_holds)
	_act = ActStep.new()
	_server = auto_free(RoundServer.new())
	add_child(_server)
	assert_array(_server.start_round({TickOrder.SURVIVOR_DEFENSE: _sd, TickOrder.HOLDS: _act}, _knobs)).is_empty()
	_server.tick_runner.set_physics_process(false) # the test steps every tick itself
	var map := MapData.load_map()
	var runner := _server.tick_runner
	_doors = Doors.new(_holds, map, _no_capsules)
	_doors.setup(runner, _server.bus, StateRegistry.new(), _knobs)
	_bars = Barricades.new(_holds, _doors, map, _healthy, _no_capsules, _is_monster)
	_bars.setup(runner, _server.bus, StateRegistry.new(), _knobs)
	_hs = HidingSpots.new(_holds, map, _healthy, _is_monster, _sd.set_hidden)
	_hs.setup(runner, _server.bus, StateRegistry.new(), _knobs)
	_sm.monster = _monster
	_sm.batch_extras.append_array([_sd.charge_entries, _hs.hiding_entries, _bars.barricade_entries])
	_sm.attach(runner)


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()
		_poll()


## Runs `action(tick)` inside the next tick, then a few more ticks.
func _do(action: Callable) -> void:
	_act.queue.append(action)
	_step(SETTLE_TICKS)


func _fire(_tick: int, p: int) -> void:
	_sd.request_intent(p, SurvivorDefense.fire_packet())


func _build(_tick: int, door: int) -> void:
	assert_bool(_bars.complete(door, false)).is_true()


func _break(_tick: int, door: int) -> void:
	_bars.break_barricade(door)


func _dropped(i: int) -> bool:
	return _net.peer_id_of(_ids[i]) == -1


func _rejoined(i: int) -> bool:
	return _clients[i].local_player_id == _ids[i] and _net.peer_id_of(_ids[i]) != -1


## Every way client `i` disagrees with what its role should see of the server's state.
func _disagreements(i: int, door: int) -> Array[String]:
	var out: Array[String] = []
	var v := _ids[i]
	var disp := _displays[i]
	var want_charges := -1 if v == _monster else _sd.charges(v)
	if disp.charges() != want_charges:
		out.append("client %d charges %d, want %d" % [i, disp.charges(), want_charges])
	if disp.hiding_spot() != -1:
		out.append("client %d spot %d, want -1" % [i, disp.hiding_spot()])
	if disp.is_barricaded(door) != _bars.is_barricaded(door) or disp.lockout_end(door) != _bars.lockout_end(door):
		out.append("client %d door %d: %s/%d, want %s/%d" % [i, door, disp.is_barricaded(door), disp.lockout_end(door),
				_bars.is_barricaded(door), _bars.lockout_end(door)])
	return out


## Steps ticks (bounded) until every client agrees with the server; returns what still disagrees.
func _agree(door: int) -> Array[String]:
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	var out: Array[String] = []
	while true:
		out = []
		for i in _displays.size():
			out.append_array(_disagreements(i, door))
		if out.is_empty() or Time.get_ticks_msec() >= end:
			break
		_step(1)
		await get_tree().process_frame
	return out


func test_rejoining_clients_get_the_missed_barricade_break_and_charge_spend() -> void:
	await _rig()
	var door := -1
	for net_id in MapData.load_map().interactables().size():
		if _bars.build_id(net_id) != -1:
			door = net_id
			break
	assert_int(door).override_failure_message("map needs a barricadable door").is_not_equal(-1)
	if not _doors.is_closed(door):
		assert_bool(_doors.toggle(door)).is_true()
	_step(SETTLE_TICKS)
	_do(_build.bind(door))
	var before := await _agree(door)
	assert_array(before).override_failure_message("\n".join(before)).is_empty()
	var tokens: Array[String] = []
	for i in 3:
		tokens.append(_clients[i].local_token)
	# Survivor 0 and the monster drop; the server sees them gone before anything changes.
	for i in [0, 2]:
		_clients[i].close()
		await _until(_dropped.bind(i), "client %d dropped" % i)
	var charges_before := _sd.charges(_ids[0])
	_do(_fire.bind(_ids[0]))
	_do(_break.bind(door))
	assert_int(_sd.charges(_ids[0])).is_equal(charges_before - 1)
	assert_int(_bars.lockout_end(door)).is_greater(0)
	var monster_got := _got[2].duplicate()
	for i in [0, 2]:
		assert_int(_clients[i].join("127.0.0.1", _next_port, "P%d" % i, tokens[i])).is_equal(OK)
		await _until(_rejoined.bind(i), "client %d rejoined" % i)
	var after := await _agree(door)
	assert_array(after).override_failure_message("\n".join(after)).is_empty()
	# AD-194: the rejoining monster's replay held barricades only.
	assert_int(_got[2].get(EventBatch.CHARGES, 0)).is_equal(0)
	assert_int(_got[2].get(EventBatch.HIDING, 0)).is_equal(0)
	assert_int(_got[2].get(EventBatch.BARRICADE, 0)).is_greater(monster_got.get(EventBatch.BARRICADE, 0))
	for d in _displays:
		assert_int(d.rejected).is_equal(0)
