# Story network-authority/002: session tokens and reconnect rebinding.
# Integration: the server and every client are separate SceneMultiplayer subtrees in this one process
# over real ENet sockets on 127.0.0.1. Each client goes through a UdpLink (no delay) so the bytes the
# server sends it can be captured.
extends GdUnitTestSuite

const SERVER_VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
const SYNC_MOVE := Vector3(1.0, 2.0, 3.0)

static var _next_port := 25600

## Lobby stand-in: a rotation queue of player IDs, kept by the NetAuthority signals the way the real
## lobby will be (join appends, drop removes).
class FakeLobby extends RefCounted:
	var st: StringName = &"waiting"
	var queue: Array[int] = []

	func state() -> StringName:
		return st

	func player_count() -> int:
		return queue.size()

var _knobs: Knobs
var _lobby: FakeLobby
var _roots: Array[Node] = []
var _links: Array[UdpLink] = []
var _uid := 0
var _server: NetAuthority
var _port: int
var _joined: Array[int] = []
var _dropped: Array[int] = []
var _rejoined: Array = []
var _runner: TickRunner
var _sm: ServerMovement
var _saved_hz: int


func before_test() -> void:
	_knobs = Knobs.load_all()
	_lobby = FakeLobby.new()
	_saved_hz = Engine.physics_ticks_per_second
	_joined.clear()
	_dropped.clear()
	_rejoined.clear()
	_server = NetAuthority.new()
	_server.setup(_knobs, SERVER_VERSION, _lobby)
	_root().add_child(_server)
	_next_port += 1
	_port = _next_port
	assert_int(_server.host(_port)).is_equal(OK)
	_server.player_joined.connect(func(p: int) -> void:
		_joined.append(p)
		_lobby.queue.append(p))
	_server.player_dropped.connect(func(p: int) -> void:
		_dropped.append(p)
		_lobby.queue.erase(p))
	_server.player_rejoined.connect(func(p: int, peer: int) -> void: _rejoined.append([p, peer]))


func after_test() -> void:
	# Let pending reject-delay coroutines finish before their node is freed.
	await get_tree().create_timer(_knobs.net.reject_close_delay_s + 0.15).timeout
	if _sm != null:
		_sm.detach()
		_sm = null
	if _runner != null:
		_runner.free()
		_runner = null
	for l in _links:
		l.stop()
	_links.clear()
	for r in _roots:
		if r.has_node("Vis"):
			r.get_node("Vis").free() ## synchronizers go before their multiplayer is unset
		for c in r.get_children():
			if c is NetAuthority:
				c.close()
		var api := r.multiplayer as SceneMultiplayer
		if api.multiplayer_peer != null:
			api.multiplayer_peer.close()
		api.multiplayer_peer = null
		api.auth_callback = Callable()
		get_tree().set_multiplayer(null, r.get_path())
		r.free()
	_roots.clear()
	Engine.physics_ticks_per_second = _saved_hz


# --- rig ---------------------------------------------------------------------

func _root() -> Node:
	_uid += 1
	var n := Node.new()
	n.name = "Tr%d" % _uid
	get_tree().root.add_child(n)
	get_tree().set_multiplayer(SceneMultiplayer.new(), n.get_path())
	_roots.append(n)
	return n


## A NetAuthority client behind its own UdpLink. Returns {net, root, link, rejects}.
## `prepare` runs on the client root before joining (e.g. to add a synchronizer mirror).
func _client(display_name: String, token := "", prepare := Callable()) -> Dictionary:
	var root := _root()
	if prepare.is_valid():
		prepare.call(root)
	var net := NetAuthority.new()
	net.setup(_knobs, SERVER_VERSION, _lobby)
	root.add_child(net)
	var rejects: Array = []
	net.join_rejected.connect(func(r: StringName) -> void: rejects.append(r))
	_next_port += 1
	var link := UdpLink.new(_next_port)
	link.record_down = true
	assert_int(link.start(_next_port, _port)).is_equal(OK)
	_links.append(link)
	assert_int(net.join("127.0.0.1", _next_port, display_name, token)).is_equal(OK)
	return {"net": net, "root": root, "link": link, "rejects": rejects}


func _until(cond: Callable, what: String) -> bool:
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while Time.get_ticks_msec() < end:
		for l in _links:
			l.pump(Time.get_ticks_msec() / 1000.0)
		if cond.call():
			return true
		await get_tree().process_frame
	assert_bool(cond.call()).override_failure_message("timeout waiting for " + what).is_true()
	return false


## Waits for the join outcome: &"ok" once the server has bound the client's peer, else the reason.
func _outcome(c: Dictionary) -> StringName:
	var net: NetAuthority = c.net
	var rejects: Array = c.rejects
	await _until(func() -> bool:
		return not rejects.is_empty() or (net.local_player_id != -1 \
			and _server.peer_id_of(net.local_player_id) == _server_peer_of(c)), "join outcome")
	return &"ok" if rejects.is_empty() else rejects[0]


## The server-side peer ID of client `c`, or -2 when it has none yet.
func _server_peer_of(c: Dictionary) -> int:
	var api := c.root.multiplayer as SceneMultiplayer
	return api.get_unique_id() if api.multiplayer_peer != null \
		and api.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED else -2


func _joined_client(display_name: String) -> Dictionary:
	var c := _client(display_name)
	assert_str(String(await _outcome(c))).is_equal("ok")
	return c


func _is_disconnected(c: Dictionary) -> bool:
	var api := c.root.multiplayer as SceneMultiplayer
	return api.multiplayer_peer == null \
		or api.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED


## Every byte the server sent client `c`, as one hex string.
func _captured_hex(c: Dictionary) -> String:
	var all := PackedByteArray()
	for d in c.link.captured_down:
		all.append_array(d)
	return all.hex_encode()


## The hex of a token as it travels (var_to_bytes stores a String as UTF-8).
func _wire_hex(token: String) -> String:
	return token.to_utf8_buffer().hex_encode()


## A node with a MultiplayerSynchronizer on `position`, hidden unless granted per peer. The same
## structure is built on the server and on a client, at the same path under each root.
func _sync_node(root: Node) -> Node3D:
	var n := Node3D.new()
	n.name = "Vis"
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var config := SceneReplicationConfig.new()
	config.add_property(NodePath(".:position"))
	sync.replication_config = config
	sync.public_visibility = false
	n.add_child(sync)
	root.add_child(n)
	sync.root_path = NodePath("..")
	return n


# --- tests -------------------------------------------------------------------

func test_reconnect_while_old_peer_connected_evicts_it_without_drop_and_keeps_queue_position() -> void:
	var a := await _joined_client("Ann")
	var b := await _joined_client("Bob")
	var pid: int = a.net.local_player_id
	var old_peer := _server.peer_id_of(pid)
	var queue_before := _lobby.queue.duplicate()
	var a2 := _client("Ann", a.net.local_token)
	assert_str(String(await _outcome(a2))).is_equal("ok")
	await _until(func() -> bool: return _is_disconnected(a), "old peer evicted")
	await _until(func() -> bool: return _server.player_id_of(old_peer) == -1, "old peer unbound")
	assert_int(a2.net.local_player_id).is_equal(pid)
	assert_str(a2.net.local_token).is_equal(a.net.local_token)
	assert_int(_server.peer_id_of(pid)).is_not_equal(old_peer)
	assert_array(_rejoined).is_equal([[pid, _server.peer_id_of(pid)]])
	assert_array(_dropped).is_empty()
	assert_array(_joined).is_equal([pid, b.net.local_player_id]) ## no new ID was issued
	assert_array(_lobby.queue).is_equal(queue_before)


func test_rebound_peer_gets_full_snapshot_first() -> void:
	_runner = TickRunner.new()
	_runner.fail_hard = false
	_runner.boot(_knobs)
	_sm = ServerMovement.new(_knobs, _server, _server.multiplayer as SceneMultiplayer, TestMoveStep.apply, TestMoveStep.WORLD)
	_sm.attach(_runner)
	var a := await _joined_client("Ann")
	var b := await _joined_client("Bob")
	for c in [a, b]:
		_sm.add_player(c.net.local_player_id, TestMoveStep.make_body(_roots[0], Vector3(c.net.local_player_id * 2.0, 0.0, 0.0)))
	var pid: int = a.net.local_player_id
	var a2 := _client("Ann", a.net.local_token)
	var states: Array[Dictionary] = []
	(a2.root.multiplayer as SceneMultiplayer).peer_packet.connect(func(_id: int, bytes: PackedByteArray) -> void:
		states.append(SnapshotCodec.decode(bytes)))
	assert_str(String(await _outcome(a2))).is_equal("ok")
	await _until(func() -> bool:
		_runner.step()
		return states.size() >= 3, "snapshots on the rebound peer")
	assert_bool(states[0].is_empty()).is_false() ## decodes
	assert_int(states[0].bodies.size()).is_equal(2) ## every body, not a delta
	var own: Array = states[0].bodies.filter(func(e: Dictionary) -> bool: return e.get("own", false))
	assert_int(own.size()).is_equal(1)
	assert_int(own[0].id).is_equal(pid)


func test_visibility_follows_the_player_to_the_new_peer() -> void:
	var server_node := _sync_node(_roots[0])
	var a := _client("Ann", "", _sync_node)
	assert_str(String(await _outcome(a))).is_equal("ok")
	var pid: int = a.net.local_player_id
	_server.set_player_visibility(server_node.get_node("Sync"), pid, true)
	server_node.position = SYNC_MOVE
	var mirror_a: Node3D = a.root.get_node("Vis")
	await _until(func() -> bool: return mirror_a.position == SYNC_MOVE, "granted node visible on the first peer")
	var a2 := _client("Ann", a.net.local_token, _sync_node)
	assert_str(String(await _outcome(a2))).is_equal("ok")
	var mirror_a2: Node3D = a2.root.get_node("Vis")
	server_node.position = SYNC_MOVE * 2.0
	await _until(func() -> bool: return mirror_a2.position == SYNC_MOVE * 2.0, "granted node visible on the new peer")
	var sync: MultiplayerSynchronizer = server_node.get_node("Sync")
	assert_bool(sync.get_visibility_for(_server.peer_id_of(pid))).is_true()


func test_non_owner_capture_contains_no_other_token() -> void:
	var a := await _joined_client("Ann")
	var b := await _joined_client("Bob")
	var a2 := _client("Ann", a.net.local_token) ## a reconnect sends A's token again
	assert_str(String(await _outcome(a2))).is_equal("ok")
	await _until(func() -> bool: return _is_disconnected(a), "old peer evicted")
	var b_bytes := _captured_hex(b)
	assert_bool(b_bytes.contains(_wire_hex(b.net.local_token))).is_true() ## the capture sees tokens at all
	assert_bool(b_bytes.contains(_wire_hex(a.net.local_token))).is_false()
	assert_bool(_captured_hex(a2).contains(_wire_hex(b.net.local_token))).is_false()


func test_reconnect_after_grace_is_rejected_round_in_progress() -> void:
	var a := await _joined_client("Ann")
	var pid: int = a.net.local_player_id
	a.net.close()
	await _until(func() -> bool: return _dropped == [pid], "player_dropped")
	_lobby.st = &"in_match"
	_server.known_token_in_grace = func(_t: String) -> bool: return false
	assert_str(String(await _outcome(_client("Ann", a.net.local_token)))).is_equal("round_in_progress")


func test_reconnect_inside_grace_after_drop_rebinds_same_id() -> void:
	var a := await _joined_client("Ann")
	var pid: int = a.net.local_player_id
	var token: String = a.net.local_token
	a.net.close()
	await _until(func() -> bool: return _dropped == [pid], "player_dropped")
	_lobby.st = &"in_match"
	_server.known_token_in_grace = func(t: String) -> bool: return t == token
	var a2 := _client("Ann", token)
	assert_str(String(await _outcome(a2))).is_equal("ok")
	assert_int(a2.net.local_player_id).is_equal(pid)
	assert_array(_rejoined).is_equal([[pid, _server.peer_id_of(pid)]])


func test_unknown_token_in_countdown_is_rejected() -> void:
	await _joined_client("Ann")
	_lobby.st = &"countdown"
	_server.known_token_in_grace = func(_t: String) -> bool: return true
	assert_str(String(await _outcome(_client("Eve", "cd".repeat(16))))).is_equal("round_in_progress")


func test_two_reconnects_with_the_same_token_one_wins() -> void:
	var a := await _joined_client("Ann")
	var pid: int = a.net.local_player_id
	var x := _client("Ann", a.net.local_token)
	var y := _client("Ann", a.net.local_token)
	await _until(func() -> bool:
		return (x.net.local_player_id != -1 or not x.rejects.is_empty()) \
			and (y.net.local_player_id != -1 or not y.rejects.is_empty()), "both outcomes")
	var outcomes := ["ok" if x.rejects.is_empty() else String(x.rejects[0]), "ok" if y.rejects.is_empty() else String(y.rejects[0])]
	outcomes.sort()
	assert_array(outcomes).is_equal(["ok", String(NetAuthority.REASON_TOKEN_IN_USE)])
	await _until(func() -> bool: return _rejoined.size() == 1, "player_rejoined")
	assert_int(_rejoined[0][0]).is_equal(pid)
	assert_array(_dropped).is_empty()


func test_old_peer_dropping_as_the_new_one_authenticates_ends_bound_to_the_new_peer() -> void:
	var a := await _joined_client("Ann")
	var pid: int = a.net.local_player_id
	var token: String = a.net.local_token
	_lobby.st = &"in_match"
	_server.known_token_in_grace = func(t: String) -> bool: return t == token
	var old_peer := _server.peer_id_of(pid)
	a.net.close() ## same frame as the new join below
	var a2 := _client("Ann", token)
	assert_str(String(await _outcome(a2))).is_equal("ok")
	await _until(func() -> bool: return _server.player_id_of(old_peer) == -1, "old peer gone")
	# Either order is legal: the drop lands first (reported, then the grace rebind) or the rebind
	# lands first (the old peer is evicted, nothing reported). Never two drops, never two rebinds.
	assert_bool(_dropped.is_empty() or _dropped == [pid]).is_true()
	assert_array(_rejoined).is_equal([[pid, _server.peer_id_of(pid)]])
	assert_int(a2.net.local_player_id).is_equal(pid)
