# Story lobby-role-assignment/006: no name tags or role indicators on bodies (AC-LB-31, TR-lobby-010,
# ADR-0004). A client can only draw what reaches it, so this checks what a remote body is made of on a
# survivor's client: the snapshot entry (wire format), the PuppetMap state a puppet is built from, and
# the PlayerBody node class. The capture case runs a server and two clients over real ENet on
# 127.0.0.1 and searches every byte the survivor receives in the round for the monster's display name
# and role. Network-authority story 010 covers node paths; story 008 covers player IDs in payloads.
# The client-scene cases (MF-11 RoundClient) inspect what a survivor's client draws: every remote body is
# a script-free Node3D with a capsule "Mesh" and a "Cone" light only, coloured by snapshot appearance
# alone, and no world-space text or sprite exists anywhere in the client's tree, in a composed 5-player
# round over real ENet. Screenshots: production/qa/evidence/no-role-indicators-evidence.md.
extends GdUnitTestSuite

const SERVER_VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
const TICKS := 30
## The only fields a remote body may carry to a client (SnapshotCodec non-own entry). `appearance`
## (borrowed-face story 007, ADR-0004 §4) is the rendered character look: a disguised shapeshifter
## shows the copied survivor's, so it carries no role, name or player id. `drive` / `fuse` are the visible
## carried items ADR-0004 §2 lists on a body entry: the server's carrier state, which a disguise never has
## (borrowed-face.md rule 12, tell T3), so they name no identity.
const REMOTE_FIELDS := ["appearance", "drive", "flashlight", "fuse", "gait", "id", "pos", "transforming", "yaw"]
## Property names that would put identity on a body node.
const IDENTITY := ["role", "player", "name", "tag", "character", "identity", "owner", "peer", "monster", "survivor"]

## The only nodes a remote body is built from (RoundClient._remote): node name -> class; the root is "".
const BODY_NODES := {"": "Node3D", "Mesh": "MeshInstance3D", "Cone": "SpotLight3D"}
## World-space classes that could put a tag, icon or marker over a body.
const TAG_CLASSES := ["Label3D", "Sprite3D", "AnimatedSprite3D", "Decal", "GPUParticles3D", "CPUParticles3D"]
const ROUND_WAIT_S := 8.0

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
var _composer: RoundComposer
var _clients: Array[RoundClient] = []


func before_test() -> void:
	_knobs = Knobs.load_all()


func after_test() -> void:
	if _composer != null:
		_composer.stop()
		_composer = null
	for c in _clients:
		c.close()
	if not _clients.is_empty():
		await get_tree().process_frame
	_roots.append_array(_clients)
	_clients.clear()
	if _sm != null:
		_sm.detach()
		_sm = null
	for r in _roots:
		for n in r.get_children():
			if n is NetAuthority:
				n.close()
		var api := r.multiplayer as SceneMultiplayer
		if api != null and api.multiplayer_peer != null:
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


# --- the client round scene (MF-11) --------------------------------------------

## A survivor's client draws a disguised shapeshifter exactly as the survivor it copies, and the true form
## differs from a survivor by colour only: same node classes, names and children, no script or meta.
func test_client_draws_remote_bodies_by_appearance_only() -> void:
	var c: RoundClient = auto_free(RoundClient.new(_knobs, TestMoveStep.apply, TestMoveStep.make_body,
			MapData.load_map(), false))
	add_child(c)
	c.puppets = PuppetMap.new()
	var survivor_look := 2
	# 7: a survivor; 9: the shapeshifter disguised as 7; 11: a shapeshifter in its true form.
	var packets: Array[PackedByteArray] = [
		HandleTable.encode(PackedInt64Array([HandleTable.INTRODUCE, 7, HandleTable.INTRODUCE, 9,
				HandleTable.INTRODUCE, 11])),
		SnapshotCodec.encode(1, [_remote(7, survivor_look), _remote(9, survivor_look),
				_remote(11, CharacterDef.TRUE_FORM_APPEARANCE_ID)] as Array[Dictionary])]
	for bytes in packets:
		c.puppets.receive(bytes)
		c.receive(bytes)
	c._process(0.016)
	assert_int(c.remotes.size()).is_equal(3)
	for h: int in c.remotes:
		_assert_plain_body(c.remotes[h], [])
	assert_object(_colour(c.remotes[9])).is_equal(_colour(c.remotes[7]))
	assert_object(_colour(c.remotes[11])).is_equal(RoundClient.TRUE_FORM_COLOUR)
	_assert_no_world_tags(c)


## AC-LB-31 in the live client scene: a composed 5-player round over real ENet. On every survivor's
## client, every remote body node is a plain body (no script, meta, tag child, or string naming a player
## or a role), its replicated state carries REMOTE_FIELDS only, and no world-space tag exists anywhere in
## the client's tree (camera, HUD and own body included: the clients render).
func test_survivor_client_scene_shows_no_tag_or_identity() -> void:
	var server_root := Node3D.new()
	server_root.name = "Lb6Host"
	get_tree().root.add_child(server_root)
	_roots.append(server_root)
	get_tree().set_multiplayer(SceneMultiplayer.new(), server_root.get_path())
	var map := MapData.load_map()
	MapGreybox.build(server_root, map)
	var net := NetAuthority.new()
	net.setup(_knobs, _knobs.join_version(RoundClient.VERSION_BUILD), FakeLobby.new())
	server_root.add_child(net)
	_next_port += 1
	assert_int(net.host(_next_port)).is_equal(OK)
	var names: Array[String] = []
	for i in 5:
		var c := RoundClient.new(_knobs, TestMoveStep.apply, TestMoveStep.make_body, map, true)
		c.name = "Lb6Client%d" % i
		get_tree().root.add_child(c)
		_clients.append(c)
		names.append("Mallory%d" % i)
		assert_int(c.join("127.0.0.1", _next_port, names[i])).is_equal(OK)
		c.scripted = InputFrame.new()
	await _round_until(func() -> bool: return _clients.all(func(c: RoundClient) -> bool: return c.is_ready()),
			"5 joined")
	var tokens := PackedStringArray()
	for c in _clients:
		tokens.append("t%d" % c.net.local_player_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var roster := Roster.lock(tokens, _info.bind(net), "s-lb6", 1, _knobs, RotationQueue.new(), rng)
	_composer = RoundComposer.new(_knobs, roster, map, net, server_root.multiplayer as SceneMultiplayer,
			server_root, TestMoveStep.apply, TestMoveStep.WORLD, TestMoveStep.make_body, _look)
	var hidden := HiddenSpawner.new()
	server_root.add_child(hidden)
	_composer.hidden = hidden
	var server := RoundServer.new()
	server_root.add_child(server)
	assert_array(_composer.start(server, rng)).is_empty()
	var survivors := _clients.filter(func(c: RoundClient) -> bool: return c.net.local_player_id != _composer.monster)
	assert_int(survivors.size()).is_equal(4)
	await _round_until(func() -> bool: return survivors.all(_draws_a_body), "every survivor draws a remote body")
	var needles: Array[String] = names.duplicate()
	needles.append_array([String(Roster.SHAPESHIFTER), String(Roster.SURVIVOR), "monster"])
	for c: RoundClient in survivors:
		for h: int in c.remotes:
			_assert_plain_body(c.remotes[h], needles)
		_assert_no_world_tags(c)
		for h: int in c.puppets.handles():
			assert_array(_sorted_keys(c.puppets.state_of(h))).is_equal(REMOTE_FIELDS)


func _info(token: String, net: NetAuthority) -> Dictionary:
	var pid := token.trim_prefix("t").to_int()
	return {"player_id": pid, "name": net.display_name_of(pid)}


func _look(id: int) -> int:
	return 1 + id % 5


func _draws_a_body(c: RoundClient) -> bool:
	return c.remotes.values().any(func(n: Node3D) -> bool: return n.visible)


func _round_until(cond: Callable, what: String) -> void:
	var end := Time.get_ticks_msec() + int(ROUND_WAIT_S * 1000.0)
	while Time.get_ticks_msec() < end and not cond.call():
		await get_tree().physics_frame
	assert_bool(cond.call()).override_failure_message("timeout waiting for " + what).is_true()


func _remote(handle: int, appearance: int) -> Dictionary:
	return {"id": handle, "pos": Vector3(handle, 0, 0), "yaw": 0.0, "gait": 0, "appearance": appearance,
		"flashlight": false}


func _colour(n: Node3D) -> Color:
	return ((n.get_node(^"Mesh") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color


## `body` is built from BODY_NODES only (plus, on a rendering client, the BodyVisual art under
## "Mesh/Visual", a function of the appearance id alone), carries no script or meta, and no String or
## StringName property of any of its nodes contains a needle (case-insensitive).
func _assert_plain_body(body: Node3D, needles: Array[String]) -> void:
	var nodes: Array[Node] = [body]
	nodes.append_array(body.find_children("*", "", true, false))
	var art := body.get_node_or_null(NodePath("Mesh/" + BodyVisual.VISUAL))
	var own := nodes.filter(func(n: Node) -> bool: return art == null or not (n == art or art.is_ancestor_of(n)))
	assert_int(own.size()).override_failure_message("remote body node count").is_equal(BODY_NODES.size())
	for n in nodes:
		var key := "" if n == body else String(n.name)
		var where := "%s (%s)" % [body.get_path_to(n), n.get_class()]
		if n in own:
			assert_str(n.get_class()).override_failure_message("unexpected body node " + where) \
				.is_equal(BODY_NODES.get(key, "?"))
		assert_bool(n.get_script() == null).override_failure_message("scripted body node " + where).is_true()
		assert_array(n.get_meta_list()).override_failure_message("meta on body node " + where).is_empty()
		for prop: Dictionary in n.get_property_list():
			if prop.type != TYPE_STRING and prop.type != TYPE_STRING_NAME:
				continue
			var v := String(n.get(prop.name)).to_lower()
			for needle in needles:
				assert_bool(v.contains(needle.to_lower())) \
					.override_failure_message("%s.%s carries '%s'" % [where, prop.name, needle]).is_false()


## No node in the client's whole tree draws a world-space tag, icon or marker.
func _assert_no_world_tags(client: Node) -> void:
	for n in client.find_children("*", "", true, false):
		assert_bool(n.get_class() in TAG_CLASSES) \
			.override_failure_message("world tag %s (%s)" % [client.get_path_to(n), n.get_class()]).is_false()


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
