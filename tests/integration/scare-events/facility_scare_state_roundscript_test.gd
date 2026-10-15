# Story scare-events/006 (TR-scare-007, TR-scare-004, TR-scare-011; design/gdd/scare-events.md rules 6, 22,
# States and Transitions; ADR-0009 §7). With 5 real ENet clients on 127.0.0.1: every client's
# FacilityScareDisplay shows Emergency in the batch of the very tick RoundPhaseChanged moved to Evacuation;
# a client that drops and rejoins gets the current state (and the Power Restored overlay) in its first
# batch and no ScareTriggered it missed. Headless: RoundScript fires only when a player enters an anchor's
# volume, in a phase and zone its catalogue entry lists, and never in Results.
extends GdUnitTestSuite

const SERVER_VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
const CLIENTS := 5
const SETTLE_TICKS := 5

static var _next_port := 28860


class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0


## Emits the test's queued events inside a tick.
class EmitStep extends RefCounted:
	var queue: Array[ServerEvent] = []
	var bus: EventBus

	func setup(_runner: TickRunner, bus_: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
		bus = bus_

	func server_tick(_tick: int) -> void:
		for e in queue:
			bus.emit(e)
		queue.clear()


var _knobs: Knobs
var _server: RoundServer
var _net: NetAuthority
var _emit: EmitStep
var _fss: FacilityScareState
var _scares: ScareEvents
var _roots: Array[Node] = []
var _sm: ServerMovement
var _bodies: Dictionary = {}
var _clients: Array[NetAuthority] = []
var _routers: Array[ClientEventRouter] = []
var _displays: Array[FacilityScareDisplay] = []
var _ids: Array[int] = []
## per client: ScareTriggered entries received
var _scare_got: Array[int] = []
## headless RoundScript rig
var _pos: Dictionary = {}
var _fired: Array[EvScareTriggered] = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_bodies = {}
	_clients = []
	_routers = []
	_displays = []
	_ids = []
	_scare_got = []
	_pos = {}
	_fired = []


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
	n.name = "Fs%d" % _roots.size()
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
	_bodies[pid] = TestMoveStep.make_body(_roots[0], Vector3(1.5 * (_bodies.size() + 1), 0.0, 0.0))
	_sm.add_player(pid, _bodies[pid])
	_sm.set_frozen(pid, true)


func _all_joined() -> bool:
	if _bodies.size() < CLIENTS:
		return false
	for c in _clients:
		if c.local_player_id == -1:
			return false
	return true


func _on_scare(_tick: int, _p: Dictionary, client: int) -> void:
	_scare_got[client] += 1


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
	for i in CLIENTS:
		var root := _root()
		var c := NetAuthority.new()
		c.setup(_knobs, SERVER_VERSION, FakeLobby.new())
		root.add_child(c)
		assert_int(c.join("127.0.0.1", _next_port, "P%d" % i)).is_equal(OK)
		_clients.append(c)
		var router := ClientEventRouter.new(root.multiplayer as SceneMultiplayer)
		_routers.append(router)
		_displays.append(FacilityScareDisplay.new(router))
		_scare_got.append(0)
		router.subscribe(&"ScareTriggered", _on_scare.bind(i))
	await _until(_all_joined, "%d clients joined" % CLIENTS)
	for c in _clients:
		_ids.append(c.local_player_id)
	_emit = EmitStep.new()
	_fss = FacilityScareState.new()
	_scares = ScareEvents.new(ScareCatalogue.load_shipped())
	_server = auto_free(RoundServer.new())
	add_child(_server)
	assert_array(_server.start_round({TickOrder.HOLDS: _emit, TickOrder.SCARE_EVENTS: _scares,
			TickOrder.SCARE_EVENTS + 1: _fss}, _knobs)).is_empty()
	_server.tick_runner.set_physics_process(false) # the test steps every tick itself
	_sm.monster = _ids[CLIENTS - 1]
	_sm.batch_extras.append(_fss.entries)
	_sm.attach(_server.tick_runner)


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()
		_poll()


func _phase(p: MatchFlow.Phase) -> EvRoundPhaseChanged:
	var e := EvRoundPhaseChanged.new()
	e.phase = p
	return e


func _powered() -> EvObjectiveProgressChanged:
	var e := EvObjectiveProgressChanged.new()
	e.objective = SurvivorObjectives.TERMINAL_ID
	e.state = SurvivorObjectives.TerminalState.POWERED
	e.discovered = true
	return e


## Steps one tick carrying `events`; returns that tick.
func _emit_tick(events: Array[ServerEvent]) -> int:
	_emit.queue.append_array(events)
	_step(1)
	return _server.tick_runner.current_tick()


func _all_show(state: int, power: bool) -> bool:
	for d in _displays:
		if d.state() != state or d.power_restored() != power:
			return false
	return true


func test_all_five_clients_enter_emergency_in_the_tick_evacuation_starts() -> void:
	await _rig()
	_emit_tick([_phase(MatchFlow.Phase.INFILTRATION)])
	await _until(_all_show.bind(FacilityScareState.State.LOW, false), "all clients Low")
	_emit_tick([_phase(MatchFlow.Phase.INVESTIGATION)])
	await _until(_all_show.bind(FacilityScareState.State.RISING, false), "all clients Rising")
	var t := _emit_tick([_phase(MatchFlow.Phase.EVACUATION)])
	await _until(_all_show.bind(FacilityScareState.State.EMERGENCY, false), "all clients Emergency")
	for d in _displays:
		## Same tick's reliable batch: one server-to-client trip after the phase change.
		assert_int(d.tick()).is_equal(t)
		assert_int(d.rejected).is_equal(0)
	assert_int(_fss.state()).is_equal(FacilityScareState.State.EMERGENCY)


func test_rejoining_client_gets_the_current_state_and_no_missed_scare() -> void:
	await _rig()
	_emit_tick([_phase(MatchFlow.Phase.INFILTRATION)])
	await _until(_all_show.bind(FacilityScareState.State.LOW, false), "all clients Low")
	var token := _clients[0].local_token
	_clients[0].close()
	await _until(func() -> bool: return _net.peer_id_of(_ids[0]) == -1, "client 0 dropped")
	_emit_tick([_phase(MatchFlow.Phase.EVACUATION), _powered()])
	## A RoundScript scare to everyone while client 0 is away.
	assert_bool(_scares.fire(&"slammed_door", Vector3(9.5, 0.0, 19.0), _ids, ScareEntry.Source.ROUND_SCRIPT)).is_true()
	_step(SETTLE_TICKS)
	await _until(func() -> bool: return _scare_got[1] > 0, "client 1 got the scare")
	assert_int(_displays[0].state()).is_equal(FacilityScareState.State.LOW)
	var stale := _displays[0].tick()
	assert_int(_clients[0].join("127.0.0.1", _next_port, "P0", token)).is_equal(OK)
	await _until(func() -> bool: return _clients[0].local_player_id == _ids[0] and _net.peer_id_of(_ids[0]) != -1,
			"client 0 rejoined")
	for i in SETTLE_TICKS:
		_step(1)
		await get_tree().process_frame
	await _until(_all_show.bind(FacilityScareState.State.EMERGENCY, true), "all clients Emergency + power")
	assert_int(_displays[0].tick()).is_greater(stale)
	assert_int(_scare_got[0]).is_equal(0)
	assert_int(_scare_got[1]).is_equal(1)


# --- RoundScript, headless ----------------------------------------------------------

func _players() -> Array:
	return _pos.keys()


func _position(id: int) -> Vector3:
	return _pos[id]


## Line of sight always clear: relevance then keeps every live player (story 003 is checked on its own).
func _clear(_from: Vector3, _to: Vector3) -> bool:
	return true


func _on_fired(e: ServerEvent) -> void:
	_fired.append(e as EvScareTriggered)


## The shipped map plus the level doc's 9 scare anchors (research-facility.md Scare anchors), placed just
## inside a room beside their door or glass wall. Inference: the map file does not carry them yet.
static func _map_with_anchors() -> MapData:
	var map := MapData.load_map()
	var anchors := {&"sd1": [&"A3", Vector3(9.5, 0, 19)], &"sd2": [&"A4", Vector3(17.5, 0, 25.5)],
		&"sd3": [&"A6", Vector3(5.5, 0, 4.5)], &"sd4": [&"B1", Vector3(31.5, 0, 27.5)],
		&"sd5": [&"C2", Vector3(45.5, 0, 27.5)], &"sd6": [&"C5", Vector3(44.5, 0, 13.5)],
		&"sg1": [&"A3", Vector3(9.5, 0, 24)], &"sg2": [&"A4", Vector3(13.5, 0, 17)], &"sg3": [&"A7", Vector3(17.5, 0, 13.5)]}
	for id: StringName in anchors:
		var m := MapMarker.new()
		m.id = id
		m.type = RoundScript.ANCHOR_TYPE
		m.volume = anchors[id][0]
		m.position = anchors[id][1]
		map.markers.append(m)
	return map


## Records RoundScript's fire() requests before gating (story 002), so entry, phase and anchor logic is
## checked on its own; the gated path is checked end to end below.
class SpyScares extends ScareEvents:
	var calls: Array = []

	func fire(scare_id: StringName, origin: Vector3, recipients: Array, source: int, player: int = -1) -> bool:
		calls.append([scare_id, origin, recipients.duplicate(), source, player])
		return true


func _round_script_rig(scares: ScareEvents, fss: FacilityScareState) -> void:
	var rs := RoundScript.new(scares, ScareCatalogue.load_shipped(), fss, _map_with_anchors(), _players, _position,
			ScareRelevance.new(_position, _clear))
	_emit = EmitStep.new()
	_server = auto_free(RoundServer.new())
	add_child(_server)
	assert_array(_server.start_round({TickOrder.HOLDS: _emit, TickOrder.SCARE_EVENTS: scares,
			TickOrder.SCARE_EVENTS + 1: fss, TickOrder.SCARE_EVENTS + 2: rs}, _knobs)).is_empty()
	_server.tick_runner.set_physics_process(false)
	_server.bus.subscribe(&"ScareTriggered", _on_fired)


func test_roundscript_fires_only_on_entering_an_anchor_volume_in_a_listed_phase() -> void:
	var scares := SpyScares.new(ScareCatalogue.load_shipped())
	var fss := FacilityScareState.new()
	_round_script_rig(scares, fss)
	var a1 := Vector3(5, 0, 34) ## A1, no anchor
	var a3 := Vector3(5, 0, 20) ## A3: sd1 (slammed door) and sg1 (glass)
	_pos = {1: a1, 2: Vector3(5, -1000, 20)} ## 2 is parked below A3: never counts as inside
	_emit_tick([_phase(MatchFlow.Phase.INFILTRATION)])
	_step(3)
	assert_array(scares.calls).is_empty()
	_pos[1] = a3
	_step(3) ## entering fires once, staying does not repeat
	assert_int(scares.calls.size()).is_equal(2)
	var want := {&"slammed_door": Vector3(9.5, 0, 19), &"glass_break": Vector3(9.5, 0, 24)}
	for c: Array in scares.calls:
		assert_bool(want.has(c[0])).is_true()
		assert_vector(c[1]).is_equal(want.get(c[0], Vector3.INF))
		want.erase(c[0])
		assert_array(c[2]).contains_exactly_in_any_order([1, 2]) ## both relevant: line of sight is stubbed clear
		assert_int(c[3]).is_equal(ScareEntry.Source.ROUND_SCRIPT)
		assert_int(c[4]).is_equal(-1)
	scares.calls.clear()
	_pos[1] = a1
	_step(2)
	assert_array(scares.calls).is_empty()
	## Results: no scares.
	_emit_tick([EvRoundEnded.new()])
	_pos[1] = a3
	_step(2)
	assert_array(scares.calls).is_empty()
	assert_int(fss.state()).is_equal(FacilityScareState.State.RESULTS)


## Through the real ScareEvents, gated per recipient (story 002): entering A3 delivers the Minor slammed door
## to both live players and the glass break is held by the 10 s any-scare cooldown it just started; a player
## who never got a scare and walks into A7 (sg3 only) gets the glass break, the cooled-down two do not.
func test_roundscript_scares_pass_through_gating_per_recipient() -> void:
	_round_script_rig(ScareEvents.new(ScareCatalogue.load_shipped()), FacilityScareState.new())
	_pos = {1: Vector3(5, 0, 34), 2: Vector3(5, -1000, 20)}
	_emit_tick([_phase(MatchFlow.Phase.INFILTRATION)])
	_pos[1] = Vector3(5, 0, 20) ## A3
	_step(2)
	assert_int(_fired.size()).is_equal(2)
	for e in _fired:
		assert_str(e.scare_id).is_equal(&"slammed_door")
		assert_vector(e.origin).is_equal(Vector3(9.5, 0, 19))
	_fired.clear()
	_pos[3] = Vector3(17, 0, 8) ## A7
	_step(2)
	assert_int(_fired.size()).is_equal(1)
	assert_str(_fired[0].scare_id).is_equal(&"glass_break")
	assert_int(_fired[0].recipient).is_equal(3)
	assert_vector(_fired[0].origin).is_equal(Vector3(17.5, 0, 13.5))


func test_state_machine_follows_the_states_table() -> void:
	var fss := FacilityScareState.new()
	var bus := EventBus.new(_knobs.core.max_flush_rounds)
	fss.setup(null, bus, null, null)
	assert_int(fss.state()).is_equal(FacilityScareState.State.LOW)
	## Terminal armed early: Low goes straight to Emergency (Match Flow rule 6).
	bus.emit(_phase(MatchFlow.Phase.EVACUATION))
	bus.flush()
	assert_int(fss.state()).is_equal(FacilityScareState.State.EMERGENCY)
	assert_bool(fss.power_restored()).is_false()
	var other := _powered()
	other.state = SurvivorObjectives.TerminalState.ARMED
	bus.emit(other)
	bus.flush()
	assert_bool(fss.power_restored()).is_false()
	bus.emit(_powered())
	bus.flush()
	assert_bool(fss.power_restored()).is_true()
	assert_array(fss.entries(7)).is_equal([[EventBatch.FACILITY_SCARE, {"state": FacilityScareState.State.EMERGENCY, "power": true}]])
	assert_array(fss.entries(7)).is_empty() ## unchanged: nothing re-sent
	assert_int(fss.entries(7, true).size()).is_equal(1) ## a rejoin gets the full record
	bus.emit(EvRoundEnded.new())
	bus.flush()
	bus.emit(_phase(MatchFlow.Phase.INVESTIGATION))
	bus.flush()
	assert_int(fss.state()).is_equal(FacilityScareState.State.RESULTS)
