# Story network-authority/003: disconnect detection and host leaving.
# Integration: server and clients are separate SceneMultiplayer subtrees (SceneTree.set_multiplayer)
# in this one process, over real ENet sockets on 127.0.0.1. A side is "killed without closing" by
# unregistering its SceneMultiplayer from the tree: nothing polls its ENet host any more, so it neither
# answers nor says goodbye, which is what the remote end sees of a crashed process.
extends GdUnitTestSuite

const VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
## ENet sends a ping once per second when idle (ENET_PEER_PING_INTERVAL, protocol constant); the timeout
## window starts at the oldest unacknowledged packet, so detection can lag timeout_max by up to one ping.
const ENET_PING_INTERVAL_S := 1.0
## One stalled frame of this length per ping, to inflate the RTT estimate.
const JITTER_STALL_MS := 40
const FILLER_TOKENS: Array[String] = ["f1", "f2", "f3", "f4", "f5"]

static var _next_port := 25400

class FakeLobby extends RefCounted:
	var st: StringName = &"waiting"

	func state() -> StringName:
		return st

	func player_count() -> int:
		return 0

var _knobs: Knobs
var _roots: Array[Node] = []
var _apis: Array[SceneMultiplayer] = []
var _uid := 0
var _tick := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_tick = 0


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


# --- rig ---------------------------------------------------------------------

func _port() -> int:
	_next_port += 1
	return _next_port


func _net(lobby: Object, version := VERSION) -> NetAuthority:
	_uid += 1
	var root := Node.new()
	root.name = "Dh%d" % _uid
	get_tree().root.add_child(root)
	var api := SceneMultiplayer.new()
	get_tree().set_multiplayer(api, root.get_path())
	_roots.append(root)
	_apis.append(api)
	var net := NetAuthority.new()
	net.setup(_knobs, version, lobby)
	root.add_child(net)
	return net


## Stops polling `net`'s multiplayer without closing it: a crashed process, as its peer sees it.
func _kill(net: NetAuthority) -> void:
	get_tree().set_multiplayer(null, net.get_parent().get_path())


func _until(cond: Callable, what: String, wait_s := WAIT_S) -> bool:
	var end := Time.get_ticks_msec() + int(wait_s * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	assert_bool(cond.call()).override_failure_message("timeout waiting for " + what).is_true()
	return false


## A server with a real LobbyState and a ConnectionRouter on the test clock (_tick).
func _routed_server(port: int) -> Dictionary:
	var lobby := LobbyState.new(_knobs)
	var server := _net(lobby)
	var router := ConnectionRouter.new(_knobs, server, lobby, func() -> int: return _tick)
	server.known_token_in_grace = router.in_grace
	assert_int(server.host(port)).is_equal(OK)
	return {"server": server, "lobby": lobby, "router": router}


## Joins a client and waits until the server has bound it. Returns the client NetAuthority.
func _join(server: NetAuthority, port: int, version := VERSION) -> NetAuthority:
	var client := _net(FakeLobby.new(), version)
	assert_int(client.join("127.0.0.1", port, "Ann")).is_equal(OK)
	await _until(func() -> bool: return client.local_player_id >= 0 and server.peer_id_of(client.local_player_id) != -1, "join")
	return client


## Every filler token joined and Ready, plus the real client's: rule 13 holds at the next server_tick.
func _fill_and_ready(lobby: LobbyState, token: String) -> void:
	for t in FILLER_TOKENS.slice(0, _knobs.lobby.min_players - 1):
		lobby.join(t)
		lobby.set_ready(t, true)
	lobby.set_ready(token, true)


func _connection_events(bus: EventBus) -> Array[ServerEvent]:
	bus.flush()
	return bus.take_tick_events().filter(func(e: ServerEvent) -> bool: return e is EvPlayerConnectionChanged)


# --- AC1: dead-peer detection ------------------------------------------------

func test_killed_client_is_reported_dropped_within_the_enet_timeout() -> void:
	var port := _port()
	var server := _net(FakeLobby.new())
	assert_int(server.host(port)).is_equal(OK)
	var client := await _join(server, port)
	var dropped_ms: Array[int] = []
	server.player_dropped.connect(func(_pid: int) -> void: dropped_ms.append(Time.get_ticks_msec()))
	var t0 := Time.get_ticks_msec()
	_kill(client)
	var max_s := _knobs.net.enet_timeout_max_ms / 1000.0
	await _until(func() -> bool: return not dropped_ms.is_empty(), "player_dropped", max_s + ENET_PING_INTERVAL_S + 2.0)
	var detect_s := (dropped_ms[0] - t0) / 1000.0
	var tick_s := 1.0 / _knobs.net.sim_tick_hz
	print("dead-peer detection: %.3f s (set_timeout %d, %d, %d)" % [detect_s, _knobs.net.enet_timeout_limit, _knobs.net.enet_timeout_min_ms, _knobs.net.enet_timeout_max_ms])
	# The ENet default detected in 5.8 s on loopback (ADR-0001 verification 1): this bound fails without set_timeout.
	assert_float(detect_s).is_between(_knobs.net.enet_timeout_min_ms / 1000.0 - tick_s, max_s + ENET_PING_INTERVAL_S + tick_s)


## Raises the client's round-trip estimate the way a slow frame on a real link does: pings the host and
## stalls the process before the reply is read. ENet's retransmit timeout starts at rtt + 4 * variance, so
## this is what exposes a set_timeout limit that backs off past the bound (BUG-0012).
func _jitter_rtt(client: NetAuthority) -> void:
	var peer := (client._smp.multiplayer_peer as ENetMultiplayerPeer).get_peer(1)
	for i in 6:
		peer.ping()
		await get_tree().process_frame
		OS.delay_msec(JITTER_STALL_MS)
		await get_tree().process_frame
	print("client rtt %d ms, variance %d ms" % [peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME), peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME_VARIANCE)])


func test_killed_server_is_detected_by_the_client_within_the_enet_timeout() -> void:
	var port := _port()
	var server := _net(FakeLobby.new())
	assert_int(server.host(port)).is_equal(OK)
	var client := await _join(server, port)
	await _jitter_rtt(client)
	var left_ms: Array[int] = []
	client.host_left.connect(func() -> void: left_ms.append(Time.get_ticks_msec()))
	var t0 := Time.get_ticks_msec()
	_kill(server)
	var max_s := _knobs.net.enet_timeout_max_ms / 1000.0
	await _until(func() -> bool: return not left_ms.is_empty(), "host_left", max_s + ENET_PING_INTERVAL_S + 2.0)
	var tick_s := 1.0 / _knobs.net.sim_tick_hz
	print("host-left detection: %.3f s" % ((left_ms[0] - t0) / 1000.0))
	assert_float((left_ms[0] - t0) / 1000.0).is_less_equal(max_s + ENET_PING_INTERVAL_S + tick_s)


# --- AC2: routing by phase ---------------------------------------------------

func test_drop_in_waiting_removes_the_player_from_the_lobby_at_once() -> void:
	var port := _port()
	var s := await _routed_server(port)
	var client := await _join(s.server, port)
	var token: String = s.server.token_of(client.local_player_id)
	assert_bool(s.lobby.tokens().has(token)).is_true() ## the router added the join
	client.close()
	await _until(func() -> bool: return not s.lobby.tokens().has(token), "lobby removal")
	assert_str(s.lobby.state()).is_equal(LobbyState.WAITING)
	assert_int(s.router.grace_start_tick(client.local_player_id)).is_equal(-1)


func test_drop_in_countdown_removes_the_player_and_cancels_the_countdown() -> void:
	var port := _port()
	var s := await _routed_server(port)
	var client := await _join(s.server, port)
	var token: String = s.server.token_of(client.local_player_id)
	_fill_and_ready(s.lobby, token)
	s.lobby.server_tick(1)
	assert_str(s.lobby.state()).is_equal(LobbyState.COUNTDOWN)
	client.close()
	await _until(func() -> bool: return not s.lobby.tokens().has(token), "lobby removal")
	assert_str(s.lobby.state()).is_equal(LobbyState.WAITING)


func test_drop_in_a_round_starts_grace_at_detection_and_emits_disconnected() -> void:
	var port := _port()
	var s := await _routed_server(port)
	var bus := EventBus.new(_knobs.core.max_flush_rounds)
	s.router.bus = bus
	var client := await _join(s.server, port)
	var pid := client.local_player_id
	var token: String = s.server.token_of(pid)
	_fill_and_ready(s.lobby, token)
	s.lobby.server_tick(1)
	s.lobby.server_tick(1 + _knobs.ticks(_knobs.lobby.lobby_countdown_s))
	assert_str(s.lobby.state()).is_equal(LobbyState.IN_MATCH)
	_tick = 500
	client.close()
	await _until(func() -> bool: return s.router.grace_start_tick(pid) != -1, "grace start")
	assert_int(s.router.grace_start_tick(pid)).is_equal(500)
	var events := _connection_events(bus)
	assert_int(events.size()).is_equal(1)
	assert_int(events[0].player).is_equal(pid)
	assert_int(events[0].status).is_equal(EvPlayerConnectionChanged.DISCONNECTED)
	assert_bool(s.lobby.tokens().has(token)).is_true() ## a round keeps the seat during grace
	var grace := _knobs.ticks(_knobs.match_flow.reconnect_grace_s)
	_tick = 500 + grace - 1
	assert_bool(s.router.in_grace(token)).is_true()
	_tick = 500 + grace
	assert_bool(s.router.in_grace(token)).is_false()


func test_rejoin_inside_grace_emits_reconnected_with_the_same_player_id() -> void:
	var port := _port()
	var s := await _routed_server(port)
	var bus := EventBus.new(_knobs.core.max_flush_rounds)
	s.router.bus = bus
	var client := await _join(s.server, port)
	var pid := client.local_player_id
	_fill_and_ready(s.lobby, s.server.token_of(pid))
	s.lobby.server_tick(1)
	s.lobby.server_tick(1 + _knobs.ticks(_knobs.lobby.lobby_countdown_s))
	var token := client.local_token
	client.close()
	await _until(func() -> bool: return s.router.grace_start_tick(pid) != -1, "grace start")
	_connection_events(bus)
	var again := _net(FakeLobby.new())
	assert_int(again.join("127.0.0.1", port, "Ann", token)).is_equal(OK)
	await _until(func() -> bool: return s.router.grace_start_tick(pid) == -1, "rejoin")
	assert_int(again.local_player_id).is_equal(pid)
	var events := _connection_events(bus)
	assert_int(events.size()).is_equal(1)
	assert_int(events[0].status).is_equal(EvPlayerConnectionChanged.RECONNECTED)


# --- AC3: host leaves ----------------------------------------------------------

func _host_quits_in(state: StringName) -> void:
	var port := _port()
	var lobby := FakeLobby.new()
	var server := _net(lobby)
	assert_int(server.host(port)).is_equal(OK)
	var a := await _join(server, port)
	var b := await _join(server, port)
	lobby.st = state ## clients joined in Waiting; the host now quits in `state`
	var left: Array[int] = []
	a.host_left.connect(func() -> void: left.append(0))
	b.host_left.connect(func() -> void: left.append(1))
	server.close()
	await _until(func() -> bool: return left.size() == 2, "host_left on both clients")
	assert_array(left).contains_exactly_in_any_order([0, 1])


func test_host_quits_in_waiting_every_client_gets_host_left() -> void:
	await _host_quits_in(LobbyState.WAITING)


func test_host_quits_in_countdown_every_client_gets_host_left() -> void:
	await _host_quits_in(LobbyState.COUNTDOWN)


func test_host_quits_in_match_every_client_gets_host_left() -> void:
	await _host_quits_in(LobbyState.IN_MATCH)


func test_rejected_client_does_not_report_host_left() -> void:
	var port := _port()
	var server := _net(FakeLobby.new())
	assert_int(server.host(port)).is_equal(OK)
	var client := _net(FakeLobby.new(), "other-0.0+00000000")
	var left: Array[int] = []
	var rejects: Array[StringName] = []
	client.host_left.connect(func() -> void: left.append(1))
	client.join_rejected.connect(func(r: StringName) -> void: rejects.append(r))
	assert_int(client.join("127.0.0.1", port, "Ann")).is_equal(OK)
	await _until(func() -> bool: return not rejects.is_empty(), "reject")
	await get_tree().create_timer(_knobs.net.reject_close_delay_s + 0.3).timeout ## the server closes it
	assert_array(left).is_empty()


## Code review 2026-10-14: a client admitted once, closed, then refused on its rejoin kept its old
## local_player_id, so the refusing server's disconnect raised host_left (and the harness rejoined in a loop).
func test_refused_rejoin_after_an_admitted_session_does_not_report_host_left() -> void:
	var port := _port()
	var lobby := FakeLobby.new()
	var server := _net(lobby)
	assert_int(server.host(port)).is_equal(OK)
	var client := await _join(server, port)
	var pid := client.local_player_id
	client.close()
	await _until(func() -> bool: return server.peer_id_of(pid) == -1, "drop")
	lobby.st = LobbyState.IN_MATCH ## no grace hook: the stored token is refused round_in_progress
	var left: Array[int] = []
	var rejects: Array[StringName] = []
	client.host_left.connect(func() -> void: left.append(1))
	client.join_rejected.connect(func(r: StringName) -> void: rejects.append(r))
	assert_int(client.join("127.0.0.1", port, "Ann", "")).is_equal(OK)
	await _until(func() -> bool: return not rejects.is_empty(), "reject")
	await get_tree().create_timer(_knobs.net.reject_close_delay_s + 0.3).timeout ## the server closes it
	assert_array(left).is_empty()
	assert_int(client.local_player_id).is_equal(-1)


func test_main_shows_the_host_left_notice_once_and_records_nothing() -> void:
	Main.notice = "Host left"
	var main: Main = auto_free(load("res://src/main.tscn").instantiate())
	add_child(main)
	assert_str(main.get_node("Status").text).contains("Host left")
	assert_str(Main.notice).is_empty() ## shown once; the next boot shows no notice
