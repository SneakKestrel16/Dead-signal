# Story network-authority/010: hidden entities, RPC paths, spectators and reconnect re-issue
# (ADR-0004 §7-9). One server and several clients over real ENet on 127.0.0.1, each on its own
# SceneMultiplayer subtree. The audited client connects through a UDP proxy that records every datagram
# the server sends it, so node paths and payloads are checked as raw bytes.
extends GdUnitTestSuite

const SERVER_VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
const SEED := 10010
## Bodies far apart (beyond relevance_near_m) in pairs: each survivor has one body near it.
const NEAR_B := Vector3(0.0, 0.0, 0.0)
const NEAR_B_OTHER := Vector3(2.0, 0.0, 0.0)
const NEAR_C := Vector3(60.0, 0.0, 0.0)
const NEAR_C_OTHER := Vector3(62.0, 0.0, 0.0)

static var _next_port := 26800

class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0


## Forwards UDP between one client and the server, recording what the server sends down.
class UdpProxy extends RefCounted:
	var down: Array[PackedByteArray] = []
	var _front := PacketPeerUDP.new()
	var _back := PacketPeerUDP.new()
	var _client_ip := ""
	var _client_port := 0

	func start(listen_port: int, server_port: int) -> void:
		_front.bind(listen_port, "127.0.0.1")
		_back.connect_to_host("127.0.0.1", server_port)

	func pump() -> void:
		while _front.get_available_packet_count() > 0:
			var p := _front.get_packet()
			_client_ip = _front.get_packet_ip()
			_client_port = _front.get_packet_port()
			_back.put_packet(p)
		while _back.get_available_packet_count() > 0:
			var p := _back.get_packet()
			down.append(p)
			if _client_port != 0:
				_front.set_dest_address(_client_ip, _client_port)
				_front.put_packet(p)

	func stop() -> void:
		_front.close()
		_back.close()


class Client extends RefCounted:
	var root: Node
	var net: NetAuthority
	var hidden: HiddenSpawner
	var spawned: Array[StringName] = []
	## Set when the client joined through a proxy: every datagram the server sent it.
	var proxy: UdpProxy


var _knobs: Knobs
var _port: int
var _roots: Array[Node] = []
var _proxies: Array[UdpProxy] = []
var _server: NetAuthority
var _server_hidden: HiddenSpawner
var _runner: TickRunner
var _sm: ServerMovement
var _bodies: Dictionary = {}
## Display name -> body position; a joiner not listed here gets no body (a spectator).
var _places: Dictionary = {}


func before_test() -> void:
	_knobs = Knobs.load_all()
	_bodies = {}
	_places = {}
	_next_port += 4
	_port = _next_port
	var root := _root()
	_server = NetAuthority.new()
	_server.setup(_knobs, SERVER_VERSION, FakeLobby.new())
	root.add_child(_server)
	_server_hidden = HiddenSpawner.new()
	root.add_child(_server_hidden)
	_server_hidden.setup(_server)
	assert_int(_server.host(_port)).is_equal(OK)
	_runner = TickRunner.new()
	_runner.fail_hard = false
	_runner.boot(_knobs)
	_runner.bus = EventBus.new(_knobs.core.max_flush_rounds)
	_sm = ServerMovement.new(_knobs, _server, root.multiplayer as SceneMultiplayer, TestMoveStep.apply, TestMoveStep.WORLD)
	_sm.attach(_runner)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_sm.scope = ReplicationScope.new(_knobs, rng)
	_server.player_joined.connect(func(pid: int) -> void:
		var place: Variant = _places.get(_server.display_name_of(pid))
		if place != null:
			_bodies[pid] = TestMoveStep.make_body(root, place)
			_sm.add_player(pid, _bodies[pid])
			_sm.set_frozen(pid, true))


func after_test() -> void:
	_server_hidden.clear() ## round end: despawn everywhere before the roots go
	for i in 5:
		_poll()
		await get_tree().process_frame
	if _sm != null:
		_sm.detach()
		_sm = null
	for proxy in _proxies:
		proxy.stop()
	_proxies.clear()
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


# --- rig ---------------------------------------------------------------------------

func _root() -> Node:
	var n := Node.new()
	n.name = "Hd%d" % _roots.size()
	get_tree().root.add_child(n)
	get_tree().set_multiplayer(SceneMultiplayer.new(), n.get_path())
	_roots.append(n)
	return n


func _poll() -> void:
	for proxy in _proxies:
		proxy.pump()
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


## Runs `n` server ticks with polling between them.
func _ticks(n: int) -> void:
	for i in n:
		_runner.step()
		_poll()
		await get_tree().process_frame
		_poll()


## Joins `display_name` (through the proxy when `proxied`); returns once it has a player ID.
func _join(display_name: String, proxied := false, token := "") -> Client:
	var c := Client.new()
	c.root = _root()
	c.net = NetAuthority.new()
	c.net.setup(_knobs, SERVER_VERSION, FakeLobby.new())
	c.root.add_child(c.net)
	c.hidden = HiddenSpawner.new()
	c.root.add_child(c.hidden)
	c.hidden.spawned.connect(func(n: Node3D) -> void: c.spawned.append(n.name))
	var port := _port
	if proxied:
		c.proxy = UdpProxy.new()
		_proxies.append(c.proxy)
		port = _port + _proxies.size()
		c.proxy.start(port, _port)
	assert_int(c.net.join("127.0.0.1", port, display_name, token)).is_equal(OK)
	await _until(func() -> bool: return c.net.local_player_id != -1, display_name + " joined")
	return c


## Waits `seconds` while polling (lets a spawn or a sync reach every client that will get it).
func _settle(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		_poll()
		await get_tree().process_frame


func _contains(hay: PackedByteArray, needle: PackedByteArray) -> bool:
	var n := needle.size()
	if n == 0:
		return false
	for i in hay.size() - n + 1:
		if hay[i] == needle[0] and hay.slice(i, i + n) == needle:
			return true
	return false


# --- AC1: a hidden spawn reaches only its grantee ------------------------------------

func test_hidden_spawn_granted_to_one_client_never_reaches_another() -> void:
	var ann := await _join("Ann")
	var bob := await _join("Bob")
	var e := _server_hidden.spawn({"kind": &"fuse", "pos": Vector3(1, 0, 2)}, [ann.net.local_player_id])
	for i in 30: ## the entity moves: its synchronizer sends to whoever may see it
		e.position.x += 0.05
		_poll()
		await get_tree().process_frame
	await _until(func() -> bool: return ann.hidden.has_node(NodePath("Entities/" + e.name)), "spawn on Ann")
	await _settle(0.5)
	var on_ann := ann.hidden.get_node(NodePath("Entities/" + e.name)) as Node3D
	assert_float(on_ann.position.x).is_equal_approx(e.position.x, 0.001) ## synced, not only spawned
	assert_array(ann.spawned).is_equal([e.name])
	assert_bool(bob.hidden.has_node(NodePath("Entities/" + e.name))).is_false()
	assert_array(bob.spawned).is_empty() ## no node and no spawned signal


func test_a_later_grant_delivers_and_despawn_removes_it() -> void:
	var ann := await _join("Ann")
	var bob := await _join("Bob")
	var e := _server_hidden.spawn({"kind": &"drive_room"}, [] as Array[int])
	await _settle(0.5)
	assert_array(ann.spawned).is_empty() ## granted to nobody: nobody gets it
	_server_hidden.grant(e, bob.net.local_player_id, true) ## e.g. discovered
	await _until(func() -> bool: return bob.hidden.has_node(NodePath("Entities/" + e.name)), "grant to Bob")
	assert_array(ann.spawned).is_empty()
	var path := NodePath("Entities/" + e.name)
	_server_hidden.despawn(e)
	await _until(func() -> bool: return not bob.hidden.has_node(path), "despawn on Bob")


func test_a_grant_follows_the_player_to_its_reconnected_peer() -> void:
	var ann := await _join("Ann")
	var e := _server_hidden.spawn({"kind": &"marker"}, [ann.net.local_player_id])
	await _until(func() -> bool: return ann.spawned.size() == 1, "spawn on Ann")
	var ann2 := await _join("Ann", false, ann.net.local_token)
	await _until(func() -> bool: return ann2.hidden.has_node(NodePath("Entities/" + e.name)), "spawn on Ann's new peer")


# --- AC2: no node path or payload names an identity ----------------------------------

## A scripted round on the server: bodies, events, sounds, hidden spawns for each player, a despawn.
## The survivor's and the monster's clients both connect through a proxy; every datagram each receives
## is scanned for what it must not learn: any other player's peer ID and any other viewer's handle (both
## travel as binary u32, so they are scanned as u32 bytes), the other display names, and role words.
## Display names are long so a chance match in tens of KB of binary is negligible (a 3-byte needle is
## not). The capture is proven to carry node paths at all (the spawner's path and the node name).
func test_no_node_path_or_payload_sent_to_a_client_names_an_identity() -> void:
	_places = {"Annabelle": NEAR_B, "Bartholomew": NEAR_B_OTHER, "Cydonia": NEAR_C}
	var ann := await _join("Annabelle", true)
	var bob := await _join("Bartholomew", true)
	var cyd := await _join("Cydonia")
	var clients: Array[Client] = [ann, bob, cyd]
	var names := {ann: "Annabelle", bob: "Bartholomew", cyd: "Cydonia"}
	_sm.monster = bob.net.local_player_id
	var mine := _server_hidden.spawn({"kind": &"hallucination", "pos": NEAR_B}, [ann.net.local_player_id])
	var theirs := _server_hidden.spawn({"kind": &"marker"}, [bob.net.local_player_id])
	for i in 20:
		var shocked := EvPlayerShocked.new()
		shocked.player = bob.net.local_player_id
		_runner.bus.emit(shocked)
		_sm.emit_sound(NEAR_B_OTHER, &"steps_c2", _knobs.controller.footstep_radius_sprint_m, bob.net.local_player_id)
		await _ticks(1)
	await _until(func() -> bool: return ann.spawned.size() == 1 and bob.spawned.size() == 1, "each one's entity")
	# Every node a client got from the network is its own grant, named E<n>, never by an identity.
	assert_array(ann.spawned).is_equal([mine.name])
	assert_array(bob.spawned).is_equal([theirs.name])
	for n: StringName in [mine.name, theirs.name]:
		assert_bool(RegEx.create_from_string("^E\\d+$").search(String(n)) != null).override_failure_message(n).is_true()
	var mine_name := String(mine.name)
	_server_hidden.despawn(mine)
	await _until(func() -> bool: return not ann.hidden.has_node(NodePath("Entities/" + mine_name)), "despawn on Ann")
	for viewer: Client in [ann, bob]:
		var all := PackedByteArray()
		for p in viewer.proxy.down:
			all.append_array(p)
		assert_int(viewer.proxy.down.size()).is_greater(20)
		assert_bool(_contains(all, "Spawner".to_utf8_buffer())).is_true() ## the scan sees paths
		var needles: Array[PackedByteArray] = []
		for word in ["shapeshifter", "survivor", "monster"]:
			needles.append(String(word).to_utf8_buffer())
		for other: Client in clients:
			var pid := other.net.local_player_id
			if other == viewer:
				continue
			needles.append(String(names[other]).to_utf8_buffer())
			needles.append(_u32(_server.peer_id_of(pid)))
			for body: int in _sm.scope.handles.bodies_of(pid):
				needles.append(_u32(_sm.scope.handles.handle_for(pid, body)))
		for needle in needles:
			assert_bool(_contains(all, needle)).override_failure_message("%s got %s" % [names[viewer], needle.hex_encode()]).is_false()
	# Positive control: a viewer's own handle does travel, as the same u32 bytes the scan looks for.
	var down := PackedByteArray()
	for p in ann.proxy.down:
		down.append_array(p)
	assert_bool(_sm.scope.handles.has(ann.net.local_player_id, bob.net.local_player_id)).is_true()
	assert_bool(_contains(down, _u32(_sm.scope.handles.handle_for(ann.net.local_player_id, bob.net.local_player_id)))).is_true()


func _u32(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_u32(0, v)
	return b


# --- AC3: spectator switch and reconnect re-issue every handle ------------------------

## Ann (eliminated: no body) watches Bob, then Cyd. Each stream mirrors the watched survivor's: its own
## entry is that survivor, its other bodies are the ones near that survivor, under Ann's own handles.
func test_spectator_switch_and_reconnect_give_an_entirely_new_handle_set() -> void:
	_places = {"Bob": NEAR_B, "Bo2": NEAR_B_OTHER, "Cyd": NEAR_C, "Cy2": NEAR_C_OTHER}
	var ann := await _join("Ann")
	var bob := await _join("Bob")
	var bo2 := await _join("Bo2")
	var cyd := await _join("Cyd")
	var cy2 := await _join("Cy2")
	var a := ann.net.local_player_id
	var own := []
	var api := ann.net.multiplayer as SceneMultiplayer
	api.peer_packet.connect(func(_p: int, bytes: PackedByteArray) -> void:
		var s := SnapshotCodec.decode(bytes)
		if not s.is_empty():
			for e: Dictionary in s.bodies:
				if e.get("own", false):
					own.append(e.id))
	var shocks := []
	api.peer_packet.connect(func(_p: int, bytes: PackedByteArray) -> void:
		if EventBatch.is_message(bytes):
			for entry: Array in EventBatch.decode(bytes).entries:
				if entry[0] == &"PlayerShocked":
					shocks.append(entry[1].body))
	var puppets := PuppetMap.new(api)
	_sm.watch(a, bob.net.local_player_id)
	await _ticks(5)
	await _until(func() -> bool: return _shows(puppets, bo2.net.local_player_id, a), "Bo2 under Ann's handle")
	var shocked := EvPlayerShocked.new() ## Bob sees Bo2 shocked; Ann's mirror gets it under her handle
	shocked.player = bo2.net.local_player_id
	_runner.bus.emit(shocked)
	await _ticks(1)
	await _until(func() -> bool: return not shocks.is_empty(), "the shock on Ann's stream")
	assert_array(shocks).is_equal([_sm.scope.handles.handle_for(a, bo2.net.local_player_id)])
	assert_int(own.back()).is_equal(bob.net.local_player_id)
	var first: Array = puppets.handles().duplicate()
	assert_int(first.size()).is_equal(1)
	assert_bool(first[0] == _sm.scope.handles.handle_for(bob.net.local_player_id, bo2.net.local_player_id)).is_false() ## Ann's own table

	_sm.watch(a, cyd.net.local_player_id) ## the switch: the server's RESET clears Ann's map in order
	await _ticks(5)
	await _until(func() -> bool: return _shows(puppets, cy2.net.local_player_id, a), "Cy2 after the switch")
	assert_int(own.back()).is_equal(cyd.net.local_player_id)
	var second: Array = puppets.handles().duplicate()
	assert_array(second).has_size(1) ## Bo2 is gone: nothing stale survives the switch
	assert_bool(second[0] in first).is_false()

	puppets.close()
	var ann2 := await _join("Ann", false, ann.net.local_token) ## reconnect while watching Cyd
	var puppets2 := PuppetMap.new(ann2.net.multiplayer as SceneMultiplayer)
	await _ticks(5)
	await _until(func() -> bool: return _shows(puppets2, cy2.net.local_player_id, a), "Cy2 after the reconnect")
	var third: Array = puppets2.handles()
	assert_array(third).has_size(1)
	assert_bool(third[0] in first or third[0] in second).is_false()
	puppets2.close()


## Code review 2026-10-14: a player with a body, or watching itself, would get two streams on one peer.
func test_watch_refuses_a_player_with_a_body_and_itself() -> void:
	_places = {"Bob": NEAR_B}
	var bob := await _join("Bob")
	var b := bob.net.local_player_id
	await _until(func() -> bool: return _bodies.has(b), "Bob's body")
	_sm.watch(b, b + 1) ## still has a body
	_sm.watch(b + 1, b + 1) ## itself
	assert_int(_sm.watched_by(b)).is_equal(-1)
	assert_int(_sm.watched_by(b + 1)).is_equal(-1)


## RESET travels with handle 0 and only with it; INTRODUCE and RETIRE still refuse 0.
func test_reset_message_carries_handle_0_only() -> void:
	var ok := HandleTable.decode(HandleTable.encode(PackedInt64Array([HandleTable.RESET, 0, HandleTable.INTRODUCE, 9])))
	assert_array(Array(ok)).is_equal([HandleTable.RESET, 0, HandleTable.INTRODUCE, 9])
	for bad: PackedInt64Array in [PackedInt64Array([HandleTable.RESET, 9]), PackedInt64Array([HandleTable.INTRODUCE, 0]), PackedInt64Array([4, 9])]:
		assert_array(Array(HandleTable.decode(HandleTable.encode(bad)))).override_failure_message(str(bad)).is_empty()


## True when `puppets` holds the server's current handle for `body` as `viewer` sees it, with the
## server's position for that body (the state matches the server's projection).
func _shows(puppets: PuppetMap, body: int, viewer: int) -> bool:
	if not _sm.scope.handles.has(viewer, body):
		return false
	var h := _sm.scope.handles.handle_for(viewer, body)
	var s := puppets.state_of(h)
	return puppets.handles().size() == 1 and not s.is_empty() \
		and (s.pos as Vector3).distance_to((_bodies[body] as Node3D).global_position) < 0.05
