# Story scare-events/010 (TR-scare-012, TR-scare-002; design/gdd/scare-events.md rules 2a, 12, 20, 21; ADR-0004
# §5). A player who starts viewing the C1 monitor (facility-map story 011) in an eligible facility state gets
# `surveillance_image` through ScareEvents.fire and its gating, at the monitor and to that player only. With 5
# real ENet clients: only the viewer receives it and the other 4 peers (monster included) get no event batch and
# no byte of it (story 003's per-peer capture). Headless: eligibility by the catalogue entry's phases, one fire
# per view start (not per tick or camera change), the shapeshifter treated like anyone (rule 2a), and the
# hallucination cap applied by the real gating.
extends GdUnitTestSuite

const SERVER_VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
const CLIENTS := 5
const SETTLE_TICKS := 5

static var _next_port := 28500


class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0


## Records fire() requests, then lets the real gating decide.
class SpyScares extends ScareEvents:
	var calls: Array = []

	func fire(scare_id: StringName, origin: Vector3, recipients: Array, source: int, player: int = -1) -> bool:
		calls.append([scare_id, origin, recipients.duplicate(), source, player])
		return super(scare_id, origin, recipients, source, player)


var _knobs: Knobs
var _map: MapData
var _server: RoundServer
var _net: NetAuthority
var _roots: Array[Node] = []
var _sm: ServerMovement
var _bodies: Dictionary = {}
var _clients: Array[NetAuthority] = []
var _routers: Array[ClientEventRouter] = []
var _ids: Array[int] = []
## per client: ScareTriggered payloads received
var _got: Array[Array] = []
## per client: every raw packet received from the server
var _packets: Array[Array] = []
var _live: Array = []
var _state: FacilityScareState.State = FacilityScareState.State.LOW
var _delivered: Array = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_map = MapData.load_map()
	_bodies = {}
	_clients = []
	_routers = []
	_ids = []
	_got = []
	_packets = []
	_live = []
	_state = FacilityScareState.State.LOW
	_delivered = []


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


# --- callables ----------------------------------------------------------------------

func _yes(_actor: int) -> bool:
	return true


func _no_hold(_actor: int) -> Dictionary:
	return {}


func _players() -> Array:
	return _live


func _phase() -> FacilityScareState.State:
	return _state


func _cams() -> Surveillance:
	return Surveillance.new(_map, _knobs, _yes, _at_monitor, _no_hold)


var _monitor := Vector3.ZERO


func _at_monitor(_actor: int) -> Vector3:
	return _monitor


func _on_scare_event(e: ServerEvent) -> void:
	_delivered.append(e)


# --- real ENet ----------------------------------------------------------------------

func _root() -> Node:
	var n := Node.new()
	n.name = "Mh%d" % _roots.size()
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


func _all_had_packets() -> bool:
	for p in _packets:
		if p.is_empty():
			return false
	return true


func _on_scare(_tick: int, p: Dictionary, client: int) -> void:
	_got[client].append(p)


func _on_packet(_from: int, bytes: PackedByteArray, client: int) -> void:
	_packets[client].append(bytes)


func _in_grace(_token: String) -> bool:
	return true


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()
		_poll()


static func _contains(bytes: PackedByteArray, needle: PackedByteArray) -> bool:
	return bytes.hex_encode().find(needle.hex_encode()) != -1


func test_viewer_alone_gets_the_image_and_no_other_peer_gets_a_byte() -> void:
	var server_root := _root()
	_net = NetAuthority.new()
	_net.setup(_knobs, SERVER_VERSION, FakeLobby.new())
	_net.known_token_in_grace = _in_grace
	server_root.add_child(_net)
	_next_port += 1
	assert_int(_net.host(_next_port)).is_equal(OK)
	_sm = ServerMovement.new(_knobs, _net, server_root.multiplayer as SceneMultiplayer, TestMoveStep.apply,
			TestMoveStep.WORLD)
	_net.player_joined.connect(_on_joined)
	for i in CLIENTS:
		var root := _root()
		var c := NetAuthority.new()
		c.setup(_knobs, SERVER_VERSION, FakeLobby.new())
		root.add_child(c)
		assert_int(c.join("127.0.0.1", _next_port, "P%d" % i)).is_equal(OK)
		_clients.append(c)
		var smp := root.multiplayer as SceneMultiplayer
		var router := ClientEventRouter.new(smp)
		_routers.append(router)
		_got.append([])
		_packets.append([])
		router.subscribe(&"ScareTriggered", _on_scare.bind(i))
		smp.peer_packet.connect(_on_packet.bind(i))
	await _until(_all_joined, "%d clients joined" % CLIENTS)
	for c in _clients:
		_ids.append(c.local_player_id)
	_live = _ids.duplicate()
	var catalogue := ScareCatalogue.load_shipped()
	var scares := ScareEvents.new(catalogue)
	var fss := FacilityScareState.new()
	var cams := _cams()
	_monitor = cams.point
	_server = auto_free(RoundServer.new())
	add_child(_server)
	assert_array(_server.start_round({TickOrder.SURVEILLANCE: cams, TickOrder.SCARE_EVENTS: scares,
			TickOrder.SCARE_EVENTS + 1: fss,
			TickOrder.SCARE_EVENTS + 3: MonitorHallucination.new(scares, catalogue, cams, fss.state, _players)},
			_knobs)).is_empty()
	_server.tick_runner.set_physics_process(false) # the test steps every tick itself
	_sm.monster = _ids[CLIENTS - 1]
	_sm.attach(_server.tick_runner)
	var rising := EvRoundPhaseChanged.new()
	rising.phase = MatchFlow.Phase.INVESTIGATION
	_server.bus.emit(rising) # a public batch to every peer: sent before the capture starts
	_step(SETTLE_TICKS)
	await _until(_all_had_packets, "first snapshots")
	_step(SETTLE_TICKS)
	await get_tree().process_frame
	_poll()
	assert_int(fss.state()).is_equal(FacilityScareState.State.RISING)
	for p in _packets:
		p.clear()
	var target := 1
	cams.on_complete(_ids[target]) # the monitor press: camera 1
	_step(SETTLE_TICKS)
	await _until(func() -> bool: return _got[target].size() == 1, "viewer got the image")
	_step(SETTLE_TICKS)
	await get_tree().process_frame
	_poll()
	assert_int(_got[target].size()).is_equal(1)
	assert_str(_got[target][0]["scare"]).is_equal(&"surveillance_image")
	assert_int(_got[target][0]["scope"]).is_equal(ScareEntry.Scope.SINGLE_CLIENT)
	assert_vector(_got[target][0]["origin"]).is_equal(cams.point) # the monitor, never a body (rule 21)
	var id_bytes := String("surveillance_image").to_utf8_buffer()
	var origin_bytes := var_to_bytes(cams.point).slice(4) ## the Vector3's 12 float bytes, header dropped
	for i in CLIENTS:
		if i == target:
			continue
		assert_array(_got[i]).is_empty()
		assert_int(_packets[i].size()).override_failure_message("client %d got no snapshots" % i).is_greater(0)
		for b: PackedByteArray in _packets[i]:
			assert_bool(EventBatch.is_message(b)).override_failure_message("client %d got an event batch" % i).is_false()
			assert_bool(_contains(b, id_bytes) or _contains(b, origin_bytes)).override_failure_message(
					"client %d got hallucination bytes" % i).is_false()


# --- headless -----------------------------------------------------------------------

func _headless(scares: ScareEvents) -> Array:
	var cams := _cams()
	_monitor = cams.point
	var catalogue := ScareCatalogue.load_shipped()
	var bus := EventBus.new(_knobs.core.max_flush_rounds)
	bus.subscribe(&"ScareTriggered", _on_scare_event)
	scares.setup(null, bus, null, _knobs)
	var mh := MonitorHallucination.new(scares, catalogue, cams, _phase, _players)
	mh.setup(null, bus, null, _knobs)
	return [cams, mh, bus]


## The catalogue entry's phases decide eligibility: no image in Low (Infiltration), one on the view start in
## Rising, none for staying on the feed or cycling cameras.
func test_fires_once_per_view_start_in_an_eligible_phase_only() -> void:
	_live = [1, 2]
	var scares := SpyScares.new(ScareCatalogue.load_shipped())
	var h := _headless(scares)
	var cams: Surveillance = h[0]
	var mh: MonitorHallucination = h[1]
	cams.on_complete(1)
	mh.server_tick(1)
	assert_array(scares.calls).is_empty()
	cams.on_complete(1) # off -> camera 2 ... still viewing
	cams.on_complete(1)
	cams.on_complete(1)
	cams.on_complete(1) # off
	mh.server_tick(2)
	_state = FacilityScareState.State.RISING
	cams.on_complete(1)
	mh.server_tick(3)
	mh.server_tick(4)
	cams.on_complete(1) # camera 2: no new start
	mh.server_tick(5)
	assert_int(scares.calls.size()).is_equal(1)
	assert_array(scares.calls[0]).is_equal([&"surveillance_image", cams.point, [1], ScareEntry.Source.SURVIVOR, 1])


## Rule 2a: the shapeshifter starting a view is treated exactly like a survivor; each viewer is its own sole
## recipient. A view held from Low into Rising is not a start.
func test_any_player_is_its_own_sole_recipient_and_a_held_view_is_no_start() -> void:
	_live = [1, 2, 9]
	var scares := SpyScares.new(ScareCatalogue.load_shipped())
	var h := _headless(scares)
	var cams: Surveillance = h[0]
	var mh: MonitorHallucination = h[1]
	cams.on_complete(2)
	mh.server_tick(1)
	_state = FacilityScareState.State.EMERGENCY
	cams.on_complete(9)
	mh.server_tick(2)
	assert_int(scares.calls.size()).is_equal(1)
	assert_array(scares.calls[0][2]).is_equal([9])
	assert_int(scares.calls[0][4]).is_equal(9)


## Through fire()'s gating: a second view start right after the first is requested but blocked (rule 11
## repeat block at the monitor; rule 12 caps it further), so the viewer gets one image.
func test_a_quick_second_view_is_gated_out() -> void:
	_live = [1]
	_state = FacilityScareState.State.RISING
	var scares := SpyScares.new(ScareCatalogue.load_shipped())
	var h := _headless(scares)
	var cams: Surveillance = h[0]
	var mh: MonitorHallucination = h[1]
	var bus: EventBus = h[2]
	for v in 2:
		cams.on_complete(1)
		mh.server_tick(v * 2)
		for press in cams.camera_ids().size():
			cams.on_complete(1) # cycles to off
		mh.server_tick(v * 2 + 1)
	bus.flush()
	assert_int(scares.calls.size()).is_equal(2)
	assert_int(_delivered.size()).is_equal(1)
	assert_int((_delivered[0] as EvScareTriggered).recipient).is_equal(1)
