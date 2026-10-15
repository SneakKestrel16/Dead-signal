# Story lobby-role-assignment/011: host kick over the network (lobby-role-assignment.md rule 20,
# AC-LB-30). A kick the lobby accepted disconnects the player's peer with a reason; the kicked client
# reports that, not "Host left"; the token keeps its player ID, so the player can rejoin.
# Integration: server and client are separate SceneMultiplayer subtrees (SceneTree.set_multiplayer)
# in this one process, over real ENet sockets on 127.0.0.1. The lobby half is in
# tests/unit/lobby/host_kick_test.gd.
extends GdUnitTestSuite

const VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
const HOST := "host-tok"

static var _next_port := 25700

class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0

var _knobs: Knobs
var _roots: Array[Node] = []
var _apis: Array[SceneMultiplayer] = []
var _uid := 0


func before_test() -> void:
	_knobs = Knobs.load_all()


func after_test() -> void:
	await get_tree().create_timer(_knobs.net.reject_close_delay_s + 0.15).timeout
	for r in _roots:
		for c in r.get_children():
			if c is NetAuthority:
				c.close()
	for api in _apis:
		if api.multiplayer_peer != null:
			api.multiplayer_peer.close()
		api.multiplayer_peer = null
		api.auth_callback = Callable()
	for r in _roots:
		get_tree().set_multiplayer(null, r.get_path())
		r.free()
	_roots.clear()
	_apis.clear()


func _net(lobby: Object) -> NetAuthority:
	_uid += 1
	var root := Node.new()
	root.name = "Hk%d" % _uid
	get_tree().root.add_child(root)
	var api := SceneMultiplayer.new()
	get_tree().set_multiplayer(api, root.get_path())
	_roots.append(root)
	_apis.append(api)
	var net := NetAuthority.new()
	net.setup(_knobs, VERSION, lobby)
	root.add_child(net)
	return net


func _until(cond: Callable, what: String) -> bool:
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	assert_bool(cond.call()).override_failure_message("timeout waiting for " + what).is_true()
	return false


func _join(server: NetAuthority, port: int, token := "") -> NetAuthority:
	var client := _net(FakeLobby.new())
	assert_int(client.join("127.0.0.1", port, "Ann", token)).is_equal(OK)
	await _until(func() -> bool: return client.local_player_id >= 0 and server.peer_id_of(client.local_player_id) != -1, "join")
	return client


func _is_disconnected(net: NetAuthority) -> bool:
	var api := net.multiplayer as SceneMultiplayer
	return api.multiplayer_peer == null \
		or api.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED


func test_kick_disconnects_with_a_reason_and_the_player_can_rejoin_under_its_token() -> void:
	_next_port += 1
	var port := _next_port
	var lobby := LobbyState.new(_knobs)
	var server := _net(lobby)
	var router := ConnectionRouter.new(_knobs, server, lobby, func() -> int: return 0)
	server.known_token_in_grace = router.in_grace
	assert_int(server.host(port)).is_equal(OK)
	lobby.host_token = HOST
	lobby.join(HOST) ## the host's own player, added by the composition root
	var dropped: Array[int] = []
	server.player_dropped.connect(func(p: int) -> void: dropped.append(p))
	var client := await _join(server, port)
	var pid := client.local_player_id
	var token: String = server.token_of(pid)
	var kicks: Array[StringName] = []
	var left: Array[int] = []
	client.kicked.connect(func(r: StringName) -> void: kicks.append(r))
	client.host_left.connect(func() -> void: left.append(1))

	assert_bool(lobby.kick(HOST, token)).is_true()
	assert_int(server.peer_id_of(pid)).is_equal(-1) ## unbound at once: no input counts from here
	await _until(func() -> bool: return _is_disconnected(client), "kicked peer disconnected")
	assert_array(kicks).is_equal([NetAuthority.REASON_KICKED])
	assert_array(left).is_empty()
	assert_array(dropped).is_empty() ## the lobby already removed it; nothing routes a second leave
	assert_bool(lobby.tokens().has(token)).is_false()

	var back := await _join(server, port, client.local_token)
	assert_int(back.local_player_id).is_equal(pid)
	assert_bool(lobby.tokens().has(token)).is_true()


func test_rejected_kick_disconnects_nobody() -> void:
	_next_port += 1
	var port := _next_port
	var lobby := LobbyState.new(_knobs)
	var server := _net(lobby)
	var _router := ConnectionRouter.new(_knobs, server, lobby, func() -> int: return 0)
	assert_int(server.host(port)).is_equal(OK)
	lobby.host_token = HOST
	var client := await _join(server, port)
	var token: String = server.token_of(client.local_player_id)
	assert_bool(lobby.kick(token, token)).is_false() ## not the host
	await get_tree().create_timer(_knobs.net.reject_close_delay_s + 0.1).timeout
	assert_bool(_is_disconnected(client)).is_false()
	assert_int(server.peer_id_of(client.local_player_id)).is_not_equal(-1)
