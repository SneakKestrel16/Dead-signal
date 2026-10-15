# Story survivor-defense/012 AC-1 (design/gdd/survivor-defense.md acceptance 9; AD-194; ADR-0004 §5):
# with 5 real ENet clients on 127.0.0.1 (client 0 behind a UdpLink at 75 ms each way), every client's
# DefenseDisplay agrees with the server after each event, as its role may see it: its own charges only,
# its own hiding spot only, every door's barricade state, and each shock or stun as "own" on the hit body's
# client and as that body's handle elsewhere (a true-form stun, no disguise here). Events are driven by
# the real modules' own entry points (the calls their holds and intents make) inside a tick.
extends GdUnitTestSuite

const SERVER_VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
const LINK_DELAY_S := 0.075
const SPACING_M := 1.5 ## bodies stand close, so every body is relevant to every viewer
const SETTLE_TICKS := 5

static var _next_port := 27800

class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0


## Runs HoldService and the test's queued actions in the HOLDS slot, so their events land in a tick.
class ActStep extends RefCounted:
	var holds: HoldService
	var queue: Array[Callable] = []

	func setup(_runner: TickRunner, _bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
		pass

	func server_tick(tick: int) -> void:
		holds.server_tick(tick)
		for c in queue:
			c.call(tick)
		queue.clear()


var _knobs: Knobs
var _server: RoundServer
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
var _link: UdpLink
var _ids: Array[int] = [] ## player id per client; the last is the monster
var _monster := -1
## player -> [type, tick] of its last shock or stun, server side
var _shocks: Dictionary[int, Array] = {}
## per client: entry type -> count received
var _got: Array[Dictionary] = []
var _disputes: Array[String] = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_bodies = {}
	_clients = []
	_routers = []
	_displays = []
	_ids = []
	_shocks = {}
	_got = []
	_disputes = []


func after_test() -> void:
	if _sm != null:
		_sm.detach()
		_sm = null
	for r in _routers:
		r.close()
	if _server != null:
		_server.end_round()
		_server = null
	if _link != null:
		_link.stop()
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
	n.name = "Sd%d" % _roots.size()
	get_tree().root.add_child(n)
	get_tree().set_multiplayer(SceneMultiplayer.new(), n.get_path())
	_roots.append(n)
	return n


func _poll() -> void:
	if _link != null:
		_link.pump(Time.get_ticks_msec() / 1000.0)
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
	if _bodies.size() < 5:
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
	return actor != _monster and not _sd.locked(actor)


func _is_monster(actor: int) -> bool:
	return actor == _monster


func _rig() -> void:
	var server_root := _root()
	var net := NetAuthority.new()
	net.setup(_knobs, SERVER_VERSION, FakeLobby.new())
	server_root.add_child(net)
	_next_port += 2
	assert_int(net.host(_next_port)).is_equal(OK)
	_sm = ServerMovement.new(_knobs, net, server_root.multiplayer as SceneMultiplayer, TestMoveStep.apply, TestMoveStep.WORLD)
	net.player_joined.connect(_on_joined)
	_link = UdpLink.new(4600)
	_link.delay_s = LINK_DELAY_S
	assert_int(_link.start(_next_port + 1, _next_port)).is_equal(OK)
	for i in 5:
		var root := _root()
		var c := NetAuthority.new()
		c.setup(_knobs, SERVER_VERSION, FakeLobby.new())
		root.add_child(c)
		assert_int(c.join("127.0.0.1", _next_port + 1 if i == 0 else _next_port, "P%d" % i)).is_equal(OK)
		_clients.append(c)
		var router := ClientEventRouter.new(root.multiplayer as SceneMultiplayer)
		_routers.append(router)
		_displays.append(DefenseDisplay.new(router))
		_got.append({})
		for type: StringName in [EventBatch.CHARGES, EventBatch.HIDING, EventBatch.BARRICADE]:
			router.subscribe(type, _on_entry.bind(i, type))
	await _until(_all_joined, "5 clients joined")
	for c in _clients:
		_ids.append(c.local_player_id)
	_monster = _ids[4]
	var survivors: Array[int] = _ids.slice(0, 4)
	_sd = SurvivorDefense.new()
	_sd.set_roster(survivors, _monster)
	_holds = HoldService.new(_knobs, _players, _frames, _centre, _sight, _claimed)
	_sd.set_holds(_holds)
	_act = ActStep.new()
	_act.holds = _holds
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


func _shock(tick: int, p: int) -> void:
	assert_bool(_sd.shock(p, tick)).is_true()
	_shocks[p] = [&"MonsterStunned" if p == _monster else &"PlayerShocked", tick]


func _hide(_tick: int, p: int, spot: int) -> void:
	_hs.hide_completed(p, spot)


func _search(_tick: int, spot: int) -> void:
	_hs.search_completed(spot)


func _build(_tick: int, door: int) -> void:
	assert_bool(_bars.complete(door, false)).is_true()


func _remove(_tick: int, door: int) -> void:
	assert_bool(_bars.complete(door, true)).is_true()


func _break(_tick: int, door: int) -> void:
	_bars.break_barricade(door)


## Every way client `i` disagrees with what its role should see of the server's state.
func _disagreements(i: int, doors: Array[int], spot: int) -> Array[String]:
	var out: Array[String] = []
	var v := _ids[i]
	var disp := _displays[i]
	var want_charges := -1 if v == _monster else _sd.charges(v)
	if disp.charges() != want_charges:
		out.append("client %d charges %d, want %d" % [i, disp.charges(), want_charges])
	var want_spot := spot if _hs.occupant(spot) == v else -1
	if disp.hiding_spot() != want_spot:
		out.append("client %d spot %d, want %d" % [i, disp.hiding_spot(), want_spot])
	for d in doors:
		if disp.is_barricaded(d) != _bars.is_barricaded(d) or disp.lockout_end(d) != _bars.lockout_end(d):
			out.append("client %d door %d: %s/%d, want %s/%d" % [i, d, disp.is_barricaded(d), disp.lockout_end(d),
					_bars.is_barricaded(d), _bars.lockout_end(d)])
	for p: int in _shocks:
		var seen := disp.own_shock() if p == v else disp.body_shock(_sm.scope.handles.handle_for(v, p))
		if seen != _shocks[p]:
			out.append("client %d shock on %d: %s, want %s" % [i, p, seen, _shocks[p]])
	return out


## Waits (bounded) for every client to agree, then records whatever still disagrees after `what`.
func _check(what: String, doors: Array[int], spot: int) -> void:
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	var out: Array[String] = []
	while true:
		out = []
		for i in _displays.size():
			out.append_array(_disagreements(i, doors, spot))
		if out.is_empty() or Time.get_ticks_msec() >= end:
			break
		_poll()
		await get_tree().process_frame
	for o in out:
		_disputes.append(what + ": " + o)


## AC-1: after each fire, shock, stun, hide, eject, build, removal and break, all five clients agree with
## the server as their role sees it; no client ever receives another player's charges or occupancy.
func test_five_clients_agree_after_each_defense_event() -> void:
	await _rig()
	var doors: Array[int] = []
	for net_id in MapData.load_map().interactables().size():
		if _bars.build_id(net_id) != -1:
			doors.append(net_id)
	assert_int(doors.size()).override_failure_message("map needs 2 barricadable doors").is_greater_equal(2)
	for d in doors.slice(0, 2):
		if not _doors.is_closed(d):
			assert_bool(_doors.toggle(d)).is_true()
	var spot := 0
	_step(SETTLE_TICKS)
	await _check("round start", doors, spot)
	_do(_fire.bind(_ids[0]))
	await _check("fire", doors, spot)
	_do(_shock.bind(_ids[1]))
	await _check("survivor shocked", doors, spot)
	_do(_shock.bind(_monster))
	await _check("monster stunned", doors, spot)
	_do(_hide.bind(_ids[2], spot))
	assert_int(_hs.occupant(spot)).is_equal(_ids[2])
	await _check("hide", doors, spot)
	_do(_search.bind(spot))
	assert_int(_hs.occupant(spot)).is_equal(-1)
	await _check("search eject", doors, spot)
	_do(_build.bind(doors[0]))
	_do(_build.bind(doors[1]))
	await _check("barricades built", doors, spot)
	_do(_remove.bind(doors[1]))
	await _check("barricade removed", doors, spot)
	_do(_break.bind(doors[0]))
	assert_int(_bars.lockout_end(doors[0])).is_greater(0)
	await _check("barricade broken", doors, spot)
	assert_array(_disputes).override_failure_message("\n".join(_disputes)).is_empty()
	# Charges and occupancy reach their owner only: one count each, the firer a second, the hider two.
	for i in 5:
		var v := _ids[i]
		var want_charges := 0 if v == _monster else (2 if i == 0 else 1)
		var want_hiding := 2 if i == 2 else 0
		assert_int(_got[i].get(EventBatch.CHARGES, 0)).override_failure_message("client %d charges entries" % i).is_equal(want_charges)
		assert_int(_got[i].get(EventBatch.HIDING, 0)).override_failure_message("client %d hiding entries" % i).is_equal(want_hiding)
		assert_int(_got[i].get(EventBatch.BARRICADE, 0)).override_failure_message("client %d barricade entries" % i).is_equal(4)
		assert_int(_displays[i].rejected).is_equal(0)
