# Story scare-events/003 (TR-scare-002; design/gdd/scare-events.md rules 19-21; ADR-0004 §5). With 5 real
# ENet clients on 127.0.0.1: a shared scare reaches exactly the clients ScareRelevance picks (within the
# entry's audible range, or line of sight to the origin) with the same scare_id and origin; a hallucination
# reaches only its target, and the raw packets the other 4 peers (monster included) receive carry no event
# batch and no byte of it. Headless: the relevance rule at its range boundary, RoundScript routed through it,
# and the catalogue refusing a hallucination entry rule 21 forbids.
extends GdUnitTestSuite

const SERVER_VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
const CLIENTS := 5
const SETTLE_TICKS := 5
## Test wall for the line-of-sight stub: a listener with x beyond it, or z below WALL_Z, is blocked.
const WALL_X := 50.0
const WALL_Z := -10.0

static var _next_port := 28960


class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0


var _knobs: Knobs
var _server: RoundServer
var _net: NetAuthority
var _scares: ScareEvents
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
## player -> listener point for the relevance stub
var _points: Dictionary = {}


func before_test() -> void:
	_knobs = Knobs.load_all()
	_bodies = {}
	_clients = []
	_routers = []
	_ids = []
	_got = []
	_packets = []
	_points = {}


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
	n.name = "Sd%d" % _roots.size()
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


func _on_scare(_tick: int, p: Dictionary, client: int) -> void:
	_got[client].append(p)


func _on_packet(_from: int, bytes: PackedByteArray, client: int) -> void:
	_packets[client].append(bytes)


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
	_scares = ScareEvents.new(ScareCatalogue.load_shipped())
	_server = auto_free(RoundServer.new())
	add_child(_server)
	assert_array(_server.start_round({TickOrder.SCARE_EVENTS: _scares}, _knobs)).is_empty()
	_server.tick_runner.set_physics_process(false) # the test steps every tick itself
	_sm.monster = _ids[CLIENTS - 1]
	_sm.attach(_server.tick_runner)
	_step(SETTLE_TICKS) # handles and first snapshots out of the way
	await _until(_all_had_packets, "first snapshots")


func _all_had_packets() -> bool:
	for p in _packets:
		if p.is_empty():
			return false
	return true


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()
		_poll()


func _point(id: int) -> Vector3:
	return _points[id]


func _clear(from: Vector3, _to: Vector3) -> bool:
	return from.x <= WALL_X and from.z >= WALL_Z


func _clear_never(_from: Vector3, _to: Vector3) -> bool:
	return false


## True when `needle` occurs anywhere in `bytes` (hex search; an odd-offset hit only makes the absence
## check stricter).
static func _contains(bytes: PackedByteArray, needle: PackedByteArray) -> bool:
	return bytes.hex_encode().find(needle.hex_encode()) != -1


func test_shared_scare_reaches_exactly_the_relevant_clients() -> void:
	await _rig()
	var origin := Vector3(0.0, 0.0, 0.0)
	var burst := ScareCatalogue.load_shipped().entry(&"door_burst") ## audible_range_m 25
	## 0 in range, 1 in range, 2 out of range with sight, 3 and 4 (the monster) out of range behind the wall.
	_points = {_ids[0]: Vector3(5, 1.6, 0), _ids[1]: Vector3(0, 1.6, 24), _ids[2]: Vector3(40, 1.6, 0),
		_ids[3]: Vector3(0, 1.6, -40), _ids[4]: Vector3(60, 1.6, 60)}
	var rel := ScareRelevance.new(_point, _clear)
	var to := rel.recipients(burst, origin, _ids)
	assert_array(to).contains_exactly_in_any_order([_ids[0], _ids[1], _ids[2]])
	assert_bool(_scares.fire(&"door_burst", origin, to, ScareEntry.Source.MONSTER, _ids[4])).is_true()
	_step(SETTLE_TICKS)
	await _until(func() -> bool: return _got[0].size() + _got[1].size() + _got[2].size() == 3, "3 relevant clients")
	_step(SETTLE_TICKS)
	await get_tree().process_frame
	_poll()
	for i in 3:
		assert_int(_got[i].size()).is_equal(1)
		assert_str(_got[i][0]["scare"]).is_equal(&"door_burst")
		assert_vector(_got[i][0]["origin"]).is_equal(origin)
	assert_array(_got[3]).is_empty()
	assert_array(_got[4]).is_empty()


func test_hallucination_reaches_only_its_target_and_no_other_peer_gets_a_byte() -> void:
	await _rig()
	var target := 1
	var origin := Vector3(7.25, 0.5, -3.75)
	for p in _packets:
		p.clear()
	## A hallucination to two clients is refused outright (rule 20).
	assert_bool(_scares.fire(&"surveillance_image", origin, [_ids[0], _ids[1]], ScareEntry.Source.SURVIVOR,
			_ids[0])).is_false()
	assert_bool(_scares.fire(&"surveillance_image", origin, [_ids[target]], ScareEntry.Source.SURVIVOR,
			_ids[target])).is_true()
	_step(SETTLE_TICKS)
	await _until(func() -> bool: return _got[target].size() == 1, "target got the hallucination")
	_step(SETTLE_TICKS)
	await get_tree().process_frame
	_poll()
	var id_bytes := String("surveillance_image").to_utf8_buffer()
	var origin_bytes := var_to_bytes(origin).slice(4) ## the Vector3's 12 float bytes, header dropped
	var target_has := false
	for b: PackedByteArray in _packets[target]:
		target_has = target_has or (EventBatch.is_message(b) and _contains(b, id_bytes))
	assert_bool(target_has).override_failure_message("positive control: target's batch names the scare").is_true()
	for i in CLIENTS:
		if i == target:
			continue
		assert_array(_got[i]).is_empty()
		assert_int(_packets[i].size()).override_failure_message("client %d got no snapshots" % i).is_greater(0)
		for b: PackedByteArray in _packets[i]:
			assert_bool(EventBatch.is_message(b)).override_failure_message("client %d got an event batch" % i).is_false()
			assert_bool(_contains(b, id_bytes) or _contains(b, origin_bytes)).override_failure_message(
					"client %d got hallucination bytes" % i).is_false()


# --- headless ----------------------------------------------------------------------

func test_relevance_counts_the_audible_range_inclusive_and_sight_without_range() -> void:
	var e := ScareEntry.new()
	e.scope = ScareEntry.Scope.SHARED
	e.audible_range_m = 10.0
	_points = {1: Vector3(10, 0, 0), 2: Vector3(10.01, 0, 0), 3: Vector3(0, 0, 500)}
	var blind := ScareRelevance.new(_point, _clear_never)
	assert_array(blind.recipients(e, Vector3.ZERO, [1, 2, 3])).contains_exactly([1])
	var seeing := ScareRelevance.new(_point, _clear)
	assert_array(seeing.recipients(e, Vector3.ZERO, [1, 2, 3])).contains_exactly([1, 2, 3])


## Records RoundScript's fire() requests before gating.
class SpyScares extends ScareEvents:
	var calls: Array = []

	func fire(scare_id: StringName, origin: Vector3, recipients: Array, source: int, player: int = -1) -> bool:
		calls.append([scare_id, origin, recipients.duplicate(), source, player])
		return true


func _players() -> Array:
	return _points.keys()


## A RoundScript anchor scare goes to the relevant live players only.
func test_roundscript_sends_anchor_scares_to_relevant_players_only() -> void:
	var map := MapData.load_map() ## ships sd1 at (9.5, 0, 19) and sg1 at (9.5, 0, 24) in A3
	var scares := SpyScares.new(ScareCatalogue.load_shipped())
	var rs := RoundScript.new(scares, ScareCatalogue.load_shipped(), FacilityScareState.new(), map, _players,
			_point, ScareRelevance.new(_point, _clear_never))
	_points = {1: Vector3(5, 0, 34), 2: Vector3(9.5, 0, 50)} ## A1; 31 m from sd1, beyond slammed_door's 25 m
	rs.server_tick(1)
	_points[1] = Vector3(5, 0, 20) ## enters A3
	rs.server_tick(2)
	assert_array(scares.calls.map(func(c: Array) -> StringName: return c[0])).contains_exactly_in_any_order(
			[&"slammed_door", &"glass_break"]) ## sd1 and sg1
	for c: Array in scares.calls:
		assert_array(c[2]).contains_exactly([1])


## Rule 21 where it is data: a Monster-source hallucination would place the monster's own action, its real
## position, in front of one client, so the catalogue refuses it at load.
func test_catalogue_refuses_a_hallucination_rule_21_forbids() -> void:
	var e := ScareEntry.new()
	e.scare_id = &"fake"
	e.category = ScareEntry.Category.DECEPTION
	e.source = ScareEntry.Source.MONSTER
	e.scope = ScareEntry.Scope.SINGLE_CLIENT
	e.intensity = ScareEntry.Intensity.MINOR
	assert_bool("\n".join(e.errors()).contains("rule 21")).is_true()
	e.source = ScareEntry.Source.SURVIVOR
	assert_array(e.errors()).is_empty()
	assert_array(ScareCatalogue.load_shipped().errors()).is_empty()


## Rule 21 on the wire: what a hallucination's recipient gets has no field that could carry a teammate,
## ping, callout, pickup, objective or timer value, or a player (source and player are stripped).
func test_hallucination_payload_carries_only_scare_scope_origin_intensity() -> void:
	var e := EvScareTriggered.new()
	e.scare_id = &"surveillance_image"
	e.scope = ScareEntry.Scope.SINGLE_CLIENT
	e.source = ScareEntry.Source.SURVIVOR
	e.player = 7
	e.recipient = 7
	assert_array(e.project(7, null, 9).keys()).contains_exactly_in_any_order(["scare", "scope", "origin", "intensity"])
	assert_dict(e.project(9, null, 9)).is_empty()
