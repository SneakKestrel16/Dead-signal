# Story survivor-objectives/010: objective state reaches every client from server state only
# (survivor-objectives.md rules 10, 12, 20, 27; TR-objectives-009, -011; ADR-0004 §5, §9). The real-ENet
# cases run a RoundServer (out of the tree, so only step() advances it) with SurvivorObjectives, a real
# HoldService stepped by the test just before each tick (the Holds slot), ServerMovement sending the
# per-peer streams, and five clients each holding an ObjectiveDisplay. Frames, centres and life state are
# fed by the test; Downing's SurvivorDowned is emitted on the server bus directly.
extends GdUnitTestSuite

const VERSION := "test-1.0+so10"
const WAIT_S := 5.0
## Loopback delivery bound (story AC 2: "within 200 ms"); checked on 127.0.0.1 only.
const LOOPBACK_BOUND_MS := 200
const CLIENTS := 5
## HoldService net ids, in SurvivorObjectives.setup registration order (as drops_and_pickups_test.gd).
const FUSES := SurvivorObjectives.ACTIVE_DRIVES
const BOXES := FUSES + SurvivorObjectives.ACTIVE_FUSES
const SLOTS := BOXES + SurvivorObjectives.ACTIVE_FUSE_BOXES
const PANEL := SLOTS + SurvivorObjectives.ACTIVE_DRIVES
const DRIVE := SurvivorObjectives.DriveState
const FUSE := SurvivorObjectives.FuseState
const TERMINAL := SurvivorObjectives.TerminalState

static var _next_port := 26300

class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0

var _knobs: Knobs
var _map: MapData
var _roots: Array[Node] = []
var _server: RoundServer
var _sm: ServerMovement
var _holds: HoldService
var _obj: SurvivorObjectives
var _clients: Array[NetAuthority] = []
var _views: Array[ObjectiveDisplay] = []
var _monster := -1
var _survivors: Array[int] = []
var _feed: Dictionary = {}
var _centres: Dictionary = {}
var _downed: Dictionary = {}
## ObjectiveProgressChanged events the server emitted, and how many of them were install alerts.
var _sent := 0
var _alerts_sent := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_map = MapData.load_map()
	_server = auto_free(RoundServer.new())
	_feed = {}
	_centres = {}
	_downed = {}
	_sent = 0
	_alerts_sent = 0


func after_test() -> void:
	for v in _views:
		v.close()
	_views.clear()
	if _sm != null:
		_sm.detach()
		_sm = null
	_server.end_round()
	_obj = null
	_holds = null
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


# --- rig ---------------------------------------------------------------------

func _root() -> Node:
	var n := Node.new()
	n.name = "So%d" % _roots.size()
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


## Hosts, joins five clients (each with an ObjectiveDisplay) and starts the round; the first joined
## player is the shapeshifter.
func _start() -> void:
	var server_root := _root()
	var net := NetAuthority.new()
	net.setup(_knobs, VERSION, FakeLobby.new())
	server_root.add_child(net)
	_next_port += 1
	assert_int(net.host(_next_port)).is_equal(OK)
	var bodies := {}
	var joined := func(pid: int) -> void: bodies[pid] = TestMoveStep.make_body(server_root, Vector3.ZERO)
	net.player_joined.connect(joined)
	for i in CLIENTS:
		var root := _root()
		var c := NetAuthority.new()
		c.setup(_knobs, VERSION, FakeLobby.new())
		root.add_child(c)
		assert_int(c.join("127.0.0.1", _next_port, "P%d" % i)).is_equal(OK)
		_clients.append(c)
		_views.append(ObjectiveDisplay.new(root.multiplayer as SceneMultiplayer))
	await _until(func() -> bool:
		return bodies.size() == CLIENTS and _clients.all(func(c: NetAuthority) -> bool: return c.local_player_id != -1),
		"all joined")
	_monster = _clients[0].local_player_id
	_survivors.assign([])
	for c in _clients.slice(1):
		_survivors.append(c.local_player_id)
	for pid: int in bodies:
		_centres[pid] = Vector3(-100.0, 0.0, -100.0)
	_holds = HoldService.new(_knobs, func() -> Array: return _survivors,
		func(actor: int) -> Array: return _feed.get(actor, []),
		func(actor: int) -> Vector3: return _centres[actor],
		func(_actor: int, _i: Interactable) -> bool: return true,
		func(actor: int) -> int: return _claimed(actor))
	_obj = SurvivorObjectives.new(_holds, _map, func(actor: int) -> bool: return not _downed.has(actor),
		Callable(), func(actor: int) -> Vector3: return _centres[actor])
	_obj.survivor_ids.assign(_survivors)
	_obj.placement = FirstMarkers.of(_map)
	assert_array(_server.start_round({TickOrder.SURVIVOR_OBJECTIVES: _obj}, _knobs)).is_empty()
	_server.bus.subscribe(&"ObjectiveProgressChanged", _on_progress)
	_sm = ServerMovement.new(_knobs, net, server_root.multiplayer as SceneMultiplayer, TestMoveStep.apply,
		TestMoveStep.WORLD)
	_sm.attach(_server.tick_runner)
	_sm.monster = _monster
	_sm.catch_up.append(_obj.catch_up)
	for pid: int in bodies:
		_sm.add_player(pid, bodies[pid])
		_sm.set_frozen(pid, true)


func _on_progress(e: ServerEvent) -> void:
	_sent += 1
	if (e as EvObjectiveProgressChanged).alert_radius_m > 0.0:
		_alerts_sent += 1


func _claimed(actor: int) -> int:
	var id := -1
	for f: InputFrame in _feed.get(actor, []):
		if f.interact:
			id = f.interact_target
	return id


func _f(interact: bool, target := 0) -> InputFrame:
	var f := InputFrame.new()
	f.interact = interact
	f.interact_target = target
	return f


func _point(type: StringName, n: int) -> Vector3:
	var seen := 0
	for m: MapMarker in _map.markers:
		if m.type == type:
			if seen == n:
				return m.position
			seen += 1
	return Vector3.ZERO


func _t(seconds: float) -> int:
	return _knobs.ticks(seconds)


## One server tick (Holds, then the runner: Objectives, flush, send). Whenever it emitted objective
## events, waits until every client heard them and checks every client against the server (AC 1).
func _step() -> void:
	var before := _sent
	_holds.server_tick(_server.tick_runner.current_tick())
	_server.tick_runner.step()
	_poll()
	if _sent != before:
		await _synced()


## `jobs`: actor -> [net id, where they stand]. All hold together for `ticks`, then release.
func _hold(jobs: Dictionary, ticks: int) -> void:
	for actor: int in jobs:
		_centres[actor] = jobs[actor][1]
	for i in ticks + 1:
		for actor: int in jobs:
			_feed[actor] = [_f(i < ticks, jobs[actor][0])]
		await _step()


## Every view heard every event meant for it, and shows what the server holds.
func _synced() -> void:
	await _until(func() -> bool:
		for v in _views:
			if v.received != (_sent if v == _views[0] else _sent - _alerts_sent):
				return false
		return true, "objective events on every client")
	for v in _views:
		_assert_matches_server(v)


func _assert_matches_server(v: ObjectiveDisplay) -> void:
	for i in _obj.drive_count():
		assert_int(v.drive_state(i)).is_equal(_obj.state_of(i))
		assert_int(v.drive_carrier(i)).is_equal(_obj.carrier_of(i))
		if _obj.state_of(i) == DRIVE.DROPPED:
			assert_vector(v.dropped_at(SurvivorObjectives.DRIVE_ID + i)).is_equal(
				_obj.dropped_at(SurvivorObjectives.DRIVE_ID + i))
	var installed := 0
	for i in SurvivorObjectives.ACTIVE_FUSES:
		assert_int(v.fuse_state(i)).is_equal(_obj.fuse_state_of(i))
		assert_int(v.fuse_carrier(i)).is_equal(_obj.fuse_carrier_of(i))
		if _obj.box_fuse_of(i) != -1:
			installed += 1
	assert_int(v.installed_count()).is_equal(installed)
	var docked := 0
	for i in _obj.drive_count():
		if _obj.state_of(i) == DRIVE.DOCKED:
			docked += 1
	assert_int(v.docked_count()).is_equal(docked)
	assert_int(v.terminal_state()).is_equal(_obj.terminal_state())
	assert_bool(v.power_restored()).is_equal(_obj.power_restored())
	assert_int(v.rejected).is_equal(0)


## The floor centre of volume 1: a valid floor point, so a drop there lands unchanged.
func _floor_spot() -> Vector3:
	var box: AABB = _map.volumes[1].box
	return Vector3(box.get_center().x, box.position.y, box.get_center().z)


# --- AC 1 and 3: identical state at every event; ejection at the terminal ----

func test_all_five_clients_mirror_the_server_through_a_full_run_and_see_both_drives_ejected() -> void:
	await _start()
	var s := _survivors
	var o := _knobs.objectives
	var terminal := _point(&"terminal", 0)
	await _hold({s[0]: [0, _point(&"drive", 0)], s[1]: [1, _point(&"drive", 1)]}, _t(o.drive_extract_s))
	for v in _views: # rule 10: the carrier, by player ID (the client's roster gives the name)
		assert_int(v.drive_carrier(0)).is_equal(s[0])
		assert_int(v.drive_carrier(1)).is_equal(s[1])
	await _hold({s[2]: [FUSES, _point(&"fuse", 0)], s[3]: [FUSES + 1, _point(&"fuse", 1)]}, _t(o.pickup_s))
	await _hold({s[2]: [BOXES, _point(&"fuse_box", 0)], s[3]: [BOXES + 1, _point(&"fuse_box", 1)]},
		_t(o.fuse_install_s))
	# Rule 16: each install start alerted the shapeshifter alone; no survivor client got one.
	assert_int(_alerts_sent).is_equal(2)
	assert_int(_views[0].alerts).is_equal(2)
	for v in _views.slice(1):
		assert_int(v.alerts).is_equal(0)
	await _hold({s[0]: [SLOTS, terminal], s[1]: [SLOTS + 1, terminal]}, _t(o.dock_s))
	assert_int(_views[1].docked_count()).is_equal(2)
	assert_int(_views[1].terminal_state()).is_equal(TERMINAL.ARMED)
	await _hold({s[0]: [PANEL, terminal]}, _t(o.activation_start_s))
	while _obj.terminal_state() != TERMINAL.ACTIVATED: # s[0] stays in the zone (rule 19)
		await _step()
	for v in _views: # rule 20: both drives ejected at the terminal, Dropped, on every client
		assert_int(v.terminal_state()).is_equal(TERMINAL.ACTIVATED)
		for i in _obj.drive_count():
			assert_int(v.drive_state(i)).is_equal(DRIVE.DROPPED)
			assert_vector(v.dropped_at(SurvivorObjectives.DRIVE_ID + i)).is_equal(terminal)
	# ADR-0004 §9: a reconnecting client gets the same state from the catch-up, and no stale alert.
	for viewer in [s[0], _monster]:
		var fresh := ObjectiveDisplay.new()
		for e: ServerEvent in _obj.catch_up():
			var one: Array[ServerEvent] = [e]
			fresh.receive(EventBatch.build(e.tick, viewer, one, [], Vector3.ZERO, HandleTable.new(), _monster))
		_assert_matches_server(fresh)
		assert_int(fresh.alerts).is_equal(0)


# --- AC 2: a downed carrier's drive drops at their position on all clients ----

func test_downing_a_carrier_drops_the_drive_at_their_position_on_all_five_clients_within_200_ms() -> void:
	await _start()
	var carrier := _survivors[0]
	await _hold({carrier: [0, _point(&"drive", 0)]}, _t(_knobs.objectives.drive_extract_s))
	var spot := _floor_spot()
	_centres[carrier] = spot
	_downed[carrier] = true
	var down := EvSurvivorDowned.new()
	down.survivor = carrier
	var t0 := Time.get_ticks_msec()
	var tick := _server.tick_runner.current_tick()
	_server.bus.emit(down)
	_server.tick_runner.step()
	await _until(func() -> bool:
		return _views.all(func(v: ObjectiveDisplay) -> bool:
			return v.drive_state(0) == DRIVE.DROPPED and v.dropped_at(SurvivorObjectives.DRIVE_ID) == spot),
		"the dropped drive on every client")
	assert_int(Time.get_ticks_msec() - t0).is_less_equal(LOOPBACK_BOUND_MS)
	assert_int(_server.tick_runner.current_tick()).is_equal(tick + 1) # within the tick that dropped it
	for v in _views:
		assert_int(v.drive_carrier(0)).is_equal(-1)


# --- untrusted bytes ----------------------------------------------------------

func test_a_view_ignores_batches_not_from_the_server_and_rejects_malformed_entries() -> void:
	var v := ObjectiveDisplay.new()
	var e := EvObjectiveProgressChanged.new()
	e.objective = SurvivorObjectives.DRIVE_ID
	e.state = DRIVE.CARRIED
	e.carrier = 7
	e.discovered = true
	var one: Array[ServerEvent] = [e]
	var bytes := EventBatch.build(1, 7, one, [], Vector3.ZERO, HandleTable.new(), -1)
	for peer in [0, 2, 9]:
		v.on_packet(peer, bytes)
	assert_int(v.drive_state(0)).is_equal(DRIVE.SECURED)
	assert_int(v.received).is_equal(0)
	var bad := PackedByteArray([EventBatch.TAG])
	bad.append_array(var_to_bytes([2, [
		[&"ObjectiveProgressChanged", {"objective": "0", "state": 1, "carrier": 7}],
		[&"ObjectiveProgressChanged", {"objective": 0, "state": 99, "carrier": 7}],
		[&"ObjectiveProgressChanged", {"objective": 99, "state": 1, "carrier": 7}],
		[&"ObjectiveProgressChanged", {"objective": 0, "state": 2, "carrier": -1, "at": "here"}],
		[&"ObjectiveProgressChanged", {"objective": 0, "state": 2, "carrier": -1, "at": Vector3.INF}],
	]]))
	v.on_packet(1, bad)
	v.on_packet(1, PackedByteArray([EventBatch.TAG, 1, 2]))
	assert_int(v.rejected).is_equal(6)
	assert_int(v.drive_state(0)).is_equal(DRIVE.SECURED)
	v.on_packet(1, bytes)
	assert_int(v.drive_state(0)).is_equal(DRIVE.CARRIED)
	assert_int(v.drive_carrier(0)).is_equal(7)
