# Story lobby-role-assignment/006: no name tags or role indicators on bodies (AC-LB-31, TR-lobby-010,
# ADR-0004). A client can only draw what reaches it, so this checks what a remote body is made of on a
# survivor's client: the snapshot entry (wire format), the PuppetMap state a puppet is built from, and
# the PlayerBody node class. The capture case runs a server and two clients over real ENet on
# 127.0.0.1 and searches every byte the survivor receives in the round for the monster's display name
# and role. Network-authority story 010 covers node paths; story 008 covers player IDs in payloads.
extends GdUnitTestSuite

const SERVER_VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
const TICKS := 30
## The only fields a remote body may carry to a client (SnapshotCodec non-own entry). `appearance`
## (borrowed-face story 007, ADR-0004 §4) is the rendered character look: a disguised shapeshifter
## shows the copied survivor's, so it carries no role, name or player id.
const REMOTE_FIELDS := ["appearance", "gait", "id", "pos", "yaw"]
## Property names that would put identity on a body node.
const IDENTITY := ["role", "player", "name", "tag", "character", "identity", "owner", "peer", "monster", "survivor"]

static var _next_port := 27600

class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0

var _knobs: Knobs
var _roots: Array[Node] = []
var _runner: TickRunner
var _sm: ServerMovement


func before_test() -> void:
	_knobs = Knobs.load_all()


func after_test() -> void:
	if _sm != null:
		_sm.detach()
		_sm = null
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
	if _runner != null:
		_runner.free()
		_runner = null


# --- wire format and client state ---------------------------------------------

func test_remote_snapshot_entry_drops_identity_fields() -> void:
	var entry := {"id": 777, "pos": Vector3(1, 0, 2), "yaw": 0.5, "gait": 1,
		"role": Roster.SHAPESHIFTER, "name": "Mallory", "player_id": 42, "character": &"doc"}
	var snap := SnapshotCodec.decode(SnapshotCodec.encode(1, [entry] as Array[Dictionary]))
	assert_array(_sorted_keys(snap.bodies[0])).is_equal(REMOTE_FIELDS)


func test_puppet_state_carries_only_motion_fields() -> void:
	var puppets := PuppetMap.new()
	puppets.receive(HandleTable.encode(PackedInt64Array([HandleTable.INTRODUCE, 777])))
	var entry := {"id": 777, "pos": Vector3(1, 0, 2), "yaw": 0.5, "gait": 1}
	puppets.receive(SnapshotCodec.encode(1, [entry] as Array[Dictionary]))
	assert_array(_sorted_keys(puppets.state_of(777))).is_equal(REMOTE_FIELDS)


# --- the body node -------------------------------------------------------------

func test_player_body_declares_no_identity_property() -> void:
	var body: PlayerBody = auto_free(PlayerBody.new())
	for prop: Dictionary in body.get_script().get_script_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue ## the script's category entry, named after its file
		var n := String(prop.name).to_lower()
		for word: String in IDENTITY:
			assert_bool(n.contains(word)).override_failure_message("PlayerBody.%s names identity" % prop.name).is_false()


func test_player_body_has_no_tag_or_indicator_child() -> void:
	var body: PlayerBody = auto_free(PlayerBody.new())
	body.setup(_knobs, PhysicsLayers.MOVE_PREDICT)
	for c in body.get_children(true):
		assert_bool(c is CollisionShape3D).override_failure_message("PlayerBody child %s" % c.get_class()).is_true()
	assert_int(body.get_meta_list().size()).is_equal(0)


# --- survivor capture over real ENet -------------------------------------------

func _root() -> Node:
	var n := Node.new()
	n.name = "Nr%d" % _roots.size()
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


## The monster stands next to the survivor for TICKS ticks, making footsteps. Nothing the survivor's
## client receives in the round holds the monster's display name or a role name, and every remote body
## it could draw carries motion fields only.
func test_survivor_receives_no_name_or_role_for_a_visible_body() -> void:
	var server_root := _root()
	var server := NetAuthority.new()
	server.setup(_knobs, SERVER_VERSION, FakeLobby.new())
	server_root.add_child(server)
	_next_port += 1
	assert_int(server.host(_next_port)).is_equal(OK)
	_runner = TickRunner.new()
	_runner.fail_hard = false
	_runner.boot(_knobs)
	_runner.bus = EventBus.new(_knobs.core.max_flush_rounds)
	_sm = ServerMovement.new(_knobs, server, server_root.multiplayer as SceneMultiplayer, TestMoveStep.apply, TestMoveStep.WORLD)
	_sm.attach(_runner)
	var bodies := {}
	server.player_joined.connect(_on_joined.bind(server_root, bodies))
	var clients: Array[NetAuthority] = []
	for name in ["Survivor", "Mallory"]:
		var root := _root()
		var net := NetAuthority.new()
		net.setup(_knobs, SERVER_VERSION, FakeLobby.new())
		root.add_child(net)
		assert_int(net.join("127.0.0.1", _next_port, name)).is_equal(OK)
		clients.append(net)
	await _until(func() -> bool: return bodies.size() == 2 and clients[0].local_player_id != -1 and clients[1].local_player_id != -1, "both joined")
	var monster := clients[1].local_player_id
	_sm.monster = monster
	var capture: Array[PackedByteArray] = []
	var survivor_api := clients[0].multiplayer as SceneMultiplayer
	survivor_api.peer_packet.connect(func(_peer: int, bytes: PackedByteArray) -> void: capture.append(bytes))
	var puppets := PuppetMap.new(survivor_api)
	var body: CharacterBody3D = bodies[monster]
	body.global_position = Vector3(1.5, 0.0, 0.0) ## well inside relevance_near_m
	for i in TICKS:
		_sm.emit_sound(body.global_position, &"steps_c2", _knobs.controller.footstep_radius_sprint_m, monster)
		_runner.step()
		_poll()
		await get_tree().process_frame
		_poll()
	await _until(func() -> bool: return puppets.handles().size() == 1 and not puppets.state_of(puppets.handles()[0]).is_empty(), "the monster drawn")
	puppets.close()
	var needles: Array[PackedByteArray] = [server.display_name_of(monster).to_utf8_buffer(),
		String(Roster.SHAPESHIFTER).to_utf8_buffer(), String(Roster.SURVIVOR).to_utf8_buffer()]
	assert_int(capture.size()).is_greater(TICKS / 2)
	for bytes in capture:
		for needle in needles:
			assert_bool(_contains(bytes, needle)) \
				.override_failure_message("round packet carries '%s': %s" % [needle.get_string_from_utf8(), bytes.hex_encode()]).is_false()
	for h: int in puppets.handles():
		assert_array(_sorted_keys(puppets.state_of(h))).is_equal(REMOTE_FIELDS)


func _on_joined(pid: int, parent: Node, bodies: Dictionary) -> void:
	bodies[pid] = TestMoveStep.make_body(parent, Vector3.ZERO)
	_sm.add_player(pid, bodies[pid])
	_sm.set_frozen(pid, true)


## Keys as sorted strings (StringName `<` does not sort by text).
func _sorted_keys(d: Dictionary) -> Array:
	var keys: Array = []
	for k: Variant in d:
		keys.append(str(k))
	keys.sort()
	return keys


## True when `needle` occurs in `hay` as a byte run.
func _contains(hay: PackedByteArray, needle: PackedByteArray) -> bool:
	for i in hay.size() - needle.size() + 1:
		if hay.slice(i, i + needle.size()) == needle:
			return true
	return false
