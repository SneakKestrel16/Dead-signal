# Story lobby-role-assignment/004: proximity voice replication (lobby-role-assignment.md rule 16,
# AC-LB-26). After the host toggles the setting in Waiting, every client reports the new value; a
# player who joins later gets the current value; a client applies only the server's exact notices.
# Integration: server and clients are separate SceneMultiplayer subtrees (SceneTree.set_multiplayer)
# in this one process, over real ENet sockets on 127.0.0.1. The lobby half (host-only, Waiting-only)
# is in tests/unit/lobby/proximity_voice_setting_test.gd.
extends GdUnitTestSuite

const VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
const HOST := "host-tok"

static var _next_port := 25800

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
	root.name = "Pv%d" % _uid
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


func _join(server: NetAuthority, port: int) -> NetAuthority:
	var client := _net(FakeLobby.new())
	assert_int(client.join("127.0.0.1", port, "Ann")).is_equal(OK)
	await _until(func() -> bool: return client.local_player_id >= 0 and server.peer_id_of(client.local_player_id) != -1, "join")
	return client


func _server(port: int) -> Array:
	var lobby := LobbyState.new(_knobs)
	var server := _net(lobby)
	var router := ConnectionRouter.new(_knobs, server, lobby, func() -> int: return 0)
	assert_int(server.host(port)).is_equal(OK)
	lobby.host_token = HOST
	lobby.join(HOST) ## the host's own player, added by the composition root
	return [server, lobby, router]


func test_host_toggle_reaches_every_client_and_a_late_joiner_gets_the_current_value() -> void:
	_next_port += 1
	var port := _next_port
	var s := _server(port)
	var server: NetAuthority = s[0]
	var lobby: LobbyState = s[1]
	var a := await _join(server, port)
	var b := await _join(server, port)
	assert_bool(a.proximity_voice).is_false()

	assert_bool(lobby.set_proximity_voice(HOST, true)).is_true()
	await _until(func() -> bool: return a.proximity_voice and b.proximity_voice, "both clients on")

	var late := await _join(server, port)
	await _until(func() -> bool: return late.proximity_voice, "late joiner on")

	assert_bool(lobby.set_proximity_voice(HOST, false)).is_true()
	await _until(func() -> bool: return not (a.proximity_voice or b.proximity_voice or late.proximity_voice), "all off")


func test_client_ignores_anything_but_the_exact_notice() -> void:
	_next_port += 1
	var port := _next_port
	var s := _server(port)
	var server: NetAuthority = s[0]
	var a := await _join(server, port)
	var smp := server.multiplayer as SceneMultiplayer
	var peer := server.peer_id_of(a.local_player_id)
	for junk: Variant in [{"proximity_voice": 1}, {"proximity_voice": "true"}, {"proximity_voice": true, "x": 0}, [true]]:
		smp.send_bytes(var_to_bytes(junk), peer, MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	smp.send_bytes(PackedByteArray([1, 2, 3]), peer, MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	# A marker sent last on the same reliable ordered channel: once it lands, every junk packet has too.
	var got: Array[int] = []
	a.kicked.connect(func(_r: StringName) -> void: got.append(1))
	server.kick(a.local_player_id)
	await _until(func() -> bool: return not got.is_empty(), "marker")
	assert_bool(a.proximity_voice).is_false()
