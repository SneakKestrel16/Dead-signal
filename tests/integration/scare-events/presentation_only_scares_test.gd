# Story scare-events/007 (TR-scare-010; design/gdd/scare-events.md rules 4, 7, 21; ADR-0005, ADR-0007). A composed
# round on the shipped map plus the level doc's 9 scare anchors (injected in memory, as story 006's test does: the
# map file does not carry them yet). A RoundScript slammed door leaves its door's server state unchanged, and the
# lunge's, observation's and ping's door checks through the open anchor door answer the same before and after
# the slam (and change once the door really closes, so the probes are connected). Over a scripted round through
# Low, Rising and Emergency, with a player walked through every anchor volume, no client batch (real ENet) carries
# a positional sound (footsteps, voice), a ping or a callout, and every ScareTriggered is a RoundScript scare.
extends GdUnitTestSuite

const SERVER_VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
const SESSION := "s-se7"
## Off the map: no anchor volume, far from every door (ambush_lunge_flinch_test's spot).
const PARK := Vector3(300.0, 0.0, 300.0)
## The anchor door sd1 guards (research-facility.md Scare anchors: sd1 = A2-A3 door).
const ANCHOR_DOOR := &"A2-A3"
## Batch entry types no RoundScript scare may cause (rule 21, TR-scare-010): footsteps and voices ride in
## positional sounds; callouts are delivered as ping records.
const FORBIDDEN := [EventBatch.SOUND, EventBatch.PING, EventBatch.PING_REJECTED]

static var _next_port := 28960


class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0


var _knobs: Knobs
var _server: RoundServer
var _c: RoundComposer
var _roots: Array[Node] = []
var _clients: Array[NetAuthority] = []
var _net: NetAuthority
## Every ScareTriggered on the server bus.
var _fired: Array[EvScareTriggered] = []
## Per client: [type, payload] of every batch entry it received.
var _got: Array[Array] = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_clients = []
	_fired = []
	_got = []


func after_test() -> void:
	if _c != null:
		_c.stop()
		_c = null
	await get_tree().process_frame
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
	n.name = "Po%d" % _roots.size()
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


func _on_batch(_peer: int, bytes: PackedByteArray, client: int) -> void:
	if EventBatch.is_message(bytes):
		_got[client].append_array(EventBatch.decode(bytes).get("entries", []))


## Hosts on a fresh port and joins `clients` real ENet clients, each recording its event batches.
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
		assert_int(c.join("127.0.0.1", _next_port, "P%d" % i)).is_equal(OK)
		_clients.append(c)
		_got.append([])
		(root.multiplayer as SceneMultiplayer).peer_packet.connect(_on_batch.bind(i))
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while Time.get_ticks_msec() < end and not _all_joined():
		_poll()
		await get_tree().process_frame
	assert_bool(_all_joined()).override_failure_message("clients never joined").is_true()


## The shipped map plus the level doc's 9 scare anchors (research-facility.md Scare anchors), as story 006's
## test places them. Inference: the map file does not carry them yet.
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


## A composed, Running round (joined clients, or 5 made-up ids and no network), every player parked and frozen.
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
	rng.seed = 7
	var roster := Roster.lock(tokens, _info, SESSION, 1, _knobs, RotationQueue.new(), rng)
	var server_root := _roots[0]
	_c = RoundComposer.new(_knobs, roster, _map_with_anchors(), _net, server_root.multiplayer as SceneMultiplayer,
			server_root as Node3D, TestMoveStep.apply, TestMoveStep.WORLD, TestMoveStep.make_body, _no_look)
	_server = auto_free(RoundServer.new())
	add_child(_server)
	assert_array(_c.start(_server, rng)).is_empty()
	_server.tick_runner.set_physics_process(false)
	_server.bus.subscribe(&"ScareTriggered", _on_scare)
	for id in roster.player_ids():
		_c.lifecycle.report_loaded(id)
	for i in _knobs.ticks(1.0):
		if _c.lifecycle.state() == RoundLifecycle.State.RUNNING:
			break
		_step(1)
	assert_int(_c.lifecycle.state()).is_equal(RoundLifecycle.State.RUNNING)
	for id in roster.player_ids():
		_place(id, PARK + Vector3(5.0 * id, 0.0, 0.0))
	_step(2)
	_fired.clear()


func _on_scare(e: ServerEvent) -> void:
	_fired.append(e as EvScareTriggered)


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()
		_poll()


func _place(id: int, at: Vector3) -> void:
	_c.sm.set_frozen(id, true)
	_c.bodies[id].global_position = at


func _door_net(id: StringName) -> int:
	var targets := _c.map.interactables()
	for i in targets.size():
		if targets[i] is MapPassage and (targets[i] as MapPassage).id == id:
			return i
	return -1


## [observation sight, ping sight, lunge hit] straight through door `p` (leaf across z at its x: the swing box
## is wider in x), each through the composer's own Callable the module uses.
func _probes(p: MapPassage) -> Array[bool]:
	var eye := p.position + Vector3(-0.6, _knobs.controller.eye_height_m, 0.0)
	var chest := p.position + Vector3(0.6, _knobs.controller.capsule_height_m * 0.75, 0.0)
	var target := {"id": _c.survivors[0], "pos": p.position + Vector3(0.6, 0.0, 0.0),
		"radius": _knobs.controller.player_radius_m, "height": _knobs.controller.capsule_height_m, "chest": chest}
	var lunge := MonsterAbilities.hit_test(eye, Vector3.RIGHT, _knobs.ability.lunge_hit_radius_m,
			deg_to_rad(_knobs.ability.lunge_cone_deg), [target], Callable(), _c._clear_sight)
	return [_c._clear_sight(eye, chest), _c._ping_clear(_c.survivors[1], eye, chest, -1), lunge.hit == _c.survivors[0]]


## AC-1: entering sd1's volume fires the slammed door at its anchor; the anchor door stays open (registry view
## and Doors), every other door is untouched, and the three door checks through it answer as before. Closing
## the door for real flips all three: the probes read live door state.
func test_slammed_door_leaves_door_state_and_door_checks_unchanged() -> void:
	_compose()
	var net_id := _door_net(ANCHOR_DOOR)
	assert_int(net_id).is_not_equal(-1)
	var door: MapPassage = _c.map.interactables()[net_id]
	var view := _server.registry.view(StateKeys.DOOR_STATE, Doors.DoorStateView) as Doors.DoorStateView
	var states := _c.doors.closed_states()
	var before := _probes(door)
	assert_array(before).is_equal([true, true, true])
	_place(_c.survivors[2], Vector3(9.5, 0.0, 19.0)) # sd1, in A3
	_step(2)
	var slams := _fired.filter(func(e: EvScareTriggered) -> bool: return e.scare_id == &"slammed_door")
	assert_int(slams.size()).is_greater(0)
	assert_vector(slams[0].origin).is_equal(Vector3(9.5, 0.0, 19.0))
	assert_bool(view.is_closed(net_id)).is_false()
	assert_array(_c.doors.closed_states()).is_equal(states)
	assert_array(_probes(door)).is_equal(before)
	_place(_c.survivors[2], PARK)
	_step(1)
	assert_bool(_c.doors.toggle(net_id)).is_true()
	assert_bool(view.is_closed(net_id)).is_true()
	assert_array(_probes(door)).is_equal([false, false, false])


## AC-2 over real ENet: a scripted round through Low, Rising and Emergency, a survivor and the monster walked
## through every anchor volume in each phase; no client batch carries a sound, ping or callout, the scares that
## reached clients are RoundScript's slammed door and glass break, and no door changed.
func test_scripted_round_never_produces_footsteps_voice_ping_or_callout() -> void:
	await _rig(5)
	_compose()
	var states := _c.doors.closed_states()
	var volumes: Array[StringName] = [&"A3", &"A4", &"A6", &"B1", &"C2", &"C5", &"A7"]
	var boxes := {}
	for v in _c.map.volumes:
		boxes[v.id] = v.box
	for phase in [MatchFlow.Phase.INFILTRATION, MatchFlow.Phase.INVESTIGATION, MatchFlow.Phase.EVACUATION]:
		var e := EvRoundPhaseChanged.new()
		e.phase = phase
		_server.bus.emit(e)
		_step(2)
		for v in volumes:
			var c: Vector3 = (boxes[v] as AABB).get_center()
			for id in [_c.survivors[0], _c.monster]:
				_place(id, Vector3(c.x, (boxes[v] as AABB).position.y, c.z))
			_step(2)
			for id in [_c.survivors[0], _c.monster]:
				_place(id, PARK + Vector3(5.0 * id, 0.0, 0.0))
			_step(2)
		# Let the minor-scare cooldown run out so the next phase's scares pass gating too.
		_step(_knobs.ticks(_knobs.scare.minor_scare_cooldown_s) + 1)
	for i in 10:
		_poll()
		await get_tree().process_frame
	assert_int(_c.scare_state.state()).is_equal(FacilityScareState.State.EMERGENCY)
	assert_int(_fired.size()).is_greater(0)
	for e in _fired:
		assert_int(e.source).is_equal(ScareEntry.Source.ROUND_SCRIPT)
		assert_bool(e.scare_id in [&"slammed_door", &"glass_break"]).is_true()
	var scares_seen := 0
	for i in _got.size():
		for entry: Array in _got[i]:
			assert_bool(entry[0] in FORBIDDEN).override_failure_message(
					"client %d got %s %s" % [i, entry[0], entry[1]]).is_false()
			if entry[0] == &"ScareTriggered":
				scares_seen += 1
	assert_int(scares_seen).is_greater(0)
	assert_array(_c.doors.closed_states()).is_equal(states)
