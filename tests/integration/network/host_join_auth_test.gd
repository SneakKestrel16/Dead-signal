# Story network-authority/001: host, join and join validation.
# Integration: server and clients are separate SceneMultiplayer subtrees (SceneTree.set_multiplayer)
# in this one process, over real ENet sockets on 127.0.0.1. Ports differ per test.
extends GdUnitTestSuite

const SERVER_VERSION := "test-1.0+aaaa1111"
const CLIENT_VERSION := "test-0.9+bbbb2222"
const WAIT_S := 5.0

static var _next_port := 24799

class FakeLobby extends RefCounted:
	var st: StringName = &"waiting"
	var count := 0

	func state() -> StringName:
		return st

	func player_count() -> int:
		return count

var _knobs: Knobs
var _lobby: FakeLobby
var _roots: Array[Node] = []
var _uid := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_lobby = FakeLobby.new()


func after_test() -> void:
	# Let pending reject-delay coroutines finish before their node is freed.
	await get_tree().create_timer(_knobs.net.reject_close_delay_s + 0.15).timeout
	for r in _roots:
		for c in r.get_children():
			if c is NetAuthority:
				c.close()
		# Raw clients' lambdas capture their own API (a cycle), and the tree keeps a
		# custom multiplayer registered per path until it is unset: both leak otherwise.
		var api := r.multiplayer as SceneMultiplayer
		if api.multiplayer_peer != null:
			api.multiplayer_peer.close()
		api.multiplayer_peer = null
		api.auth_callback = Callable()
		for c in api.peer_authenticating.get_connections():
			api.peer_authenticating.disconnect(c.callable)
		get_tree().set_multiplayer(null, r.get_path())
		r.free()
	_roots.clear()


func _port() -> int:
	_next_port += 1
	return _next_port


## A node with its own SceneMultiplayer; returns the root so children inherit that API.
func _root() -> Node:
	_uid += 1
	var n := Node.new()
	n.name = "Ep%d" % _uid
	get_tree().root.add_child(n)
	get_tree().set_multiplayer(SceneMultiplayer.new(), n.get_path())
	_roots.append(n)
	return n


func _net(version: String) -> NetAuthority:
	var net := NetAuthority.new()
	net.setup(_knobs, version, _lobby)
	_root().add_child(net)
	return net


func _server(port: int) -> NetAuthority:
	var s := _net(SERVER_VERSION)
	assert_int(s.host(port)).is_equal(OK)
	return s


## A NetAuthority client. Returns {net, rejects: Array[StringName]}.
func _client(port: int, display_name: String, version := SERVER_VERSION) -> Dictionary:
	var c := _net(version)
	var rejects: Array = []
	c.join_rejected.connect(func(r: StringName) -> void: rejects.append(r))
	assert_int(c.join("127.0.0.1", port, display_name)).is_equal(OK)
	return {"net": c, "rejects": rejects}


## A bare SceneMultiplayer client that sends `payload` raw and records the server reply.
## Returns {replies: Array[PackedByteArray], api}.
func _raw_client(port: int, payload: PackedByteArray) -> Dictionary:
	var root := _root()
	var api := root.multiplayer as SceneMultiplayer
	var replies: Array = []
	api.auth_callback = func(_id: int, data: PackedByteArray) -> void: replies.append(data)
	api.peer_authenticating.connect(func(id: int) -> void: api.send_auth(id, payload))
	var peer := ENetMultiplayerPeer.new()
	assert_int(peer.create_client("127.0.0.1", port)).is_equal(OK)
	api.multiplayer_peer = peer
	return {"replies": replies, "api": api}


## Waits for `cond` up to WAIT_S; fails the test with `what` on timeout. Never hangs.
func _until(cond: Callable, what: String) -> bool:
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	assert_bool(cond.call()).override_failure_message("timeout waiting for " + what).is_true()
	return false


## Outcome of a NetAuthority client join: &"ok" or the reject reason.
func _outcome(c: Dictionary) -> StringName:
	var net: NetAuthority = c.net
	var rejects: Array = c.rejects
	await _until(func() -> bool: return net.local_token != "" or not rejects.is_empty(), "join outcome")
	return &"ok" if rejects.is_empty() else rejects[0]


## Reason string a raw client got, or "" if nothing arrived in time.
func _raw_reason(raw: Dictionary) -> String:
	var replies: Array = raw.replies
	await _until(func() -> bool: return not replies.is_empty(), "auth reply")
	if replies.is_empty():
		return ""
	var d: Variant = bytes_to_var(replies[0])
	return String(d.get("reason", "")) if d is Dictionary else "<not a dict>"


## A string of the given code points (kept out of the source so no invisible characters sit in it).
func _chars(codes: Array) -> String:
	var s := ""
	for c in codes:
		s += String.chr(c)
	return s


func _good_payload(extra := {}) -> PackedByteArray:
	var d := {"version": SERVER_VERSION, "display_name": "Ann", "token": ""}
	d.merge(extra, true)
	return var_to_bytes(d)


# --- tests -------------------------------------------------------------------

func test_valid_join_gets_player_id_and_token() -> void:
	var port := _port()
	var s := _server(port)
	var joined: Array = []
	s.player_joined.connect(func(p: int) -> void: joined.append(p))
	var c := _client(port, "Ann")
	assert_str(String(await _outcome(c))).is_equal("ok")
	await _until(func() -> bool: return not joined.is_empty(), "player_joined")
	var cn: NetAuthority = c.net
	assert_int(cn.local_player_id).is_equal(joined[0])
	assert_int(cn.local_token.length()).is_equal(32)
	assert_bool(cn.local_token.is_valid_hex_number()).is_true()
	var peer_id := s.peer_id_of(joined[0])
	assert_int(peer_id).is_not_equal(-1)
	assert_int(s.player_id_of(peer_id)).is_equal(joined[0])
	assert_int(s.player_id_of(999)).is_equal(-1)
	assert_int(s.peer_id_of(999)).is_equal(-1)


func test_two_joins_get_distinct_ids_and_tokens() -> void:
	var port := _port()
	_server(port)
	var a := _client(port, "Ann")
	var b := _client(port, "Bob")
	assert_str(String(await _outcome(a))).is_equal("ok")
	assert_str(String(await _outcome(b))).is_equal("ok")
	assert_int(a.net.local_player_id).is_not_equal(b.net.local_player_id)
	assert_str(a.net.local_token).is_not_equal(b.net.local_token)


func test_join_at_cap_rejected_lobby_full() -> void:
	var port := _port()
	_server(port)
	_lobby.count = _knobs.lobby.max_players
	assert_str(String(await _outcome(_client(port, "Ann")))).is_equal("lobby_full")


func test_join_one_below_cap_accepted() -> void:
	var port := _port()
	_server(port)
	_lobby.count = _knobs.lobby.max_players - 1
	assert_str(String(await _outcome(_client(port, "Ann")))).is_equal("ok")


func test_join_during_countdown_and_in_match_rejected_round_in_progress() -> void:
	var port := _port()
	_server(port)
	for st in [&"countdown", &"in_match"]:
		_lobby.st = st
		assert_str(String(await _outcome(_client(port, "Ann")))).is_equal("round_in_progress")


func test_unknown_token_is_a_new_join_even_when_grace_says_yes() -> void:
	# Story 002: only a token the server issued can rebind; known-token reconnects are in
	# tokens_reconnect_test.gd.
	var port := _port()
	var s := _server(port)
	_lobby.st = &"in_match"
	s.known_token_in_grace = func(_t: String) -> bool: return true
	var raw := _raw_client(port, _good_payload({"token": "ab".repeat(16)}))
	assert_str(await _raw_reason(raw)).is_equal("round_in_progress")


func test_version_mismatch_rejected_with_both_strings() -> void:
	var port := _port()
	_server(port)
	var c := _client(port, "Ann", CLIENT_VERSION)
	assert_str(String(await _outcome(c))).is_equal("version_mismatch")
	assert_str(c.net.last_reject_details.server_version).is_equal(SERVER_VERSION)
	assert_str(c.net.last_reject_details.client_version).is_equal(CLIENT_VERSION)


func test_version_checked_before_name() -> void:
	var port := _port()
	_server(port)
	assert_str(String(await _outcome(_client(port, "", CLIENT_VERSION)))).is_equal("version_mismatch")


func test_name_checked_before_lobby_state() -> void:
	var port := _port()
	_server(port)
	_lobby.st = &"in_match"
	assert_str(String(await _outcome(_client(port, "")))).is_equal("bad_name")


func test_bad_names_rejected_bad_name() -> void:
	var port := _port()
	_server(port)
	var cases := {
		"empty": "",
		"17 chars": "A".repeat(17),
		"controls and bidi only": _chars([0x07, 0x202E, 0x2066, 0x200F, 0x7F, 0x85, 0x01]),
	}
	for label in cases:
		var got := String(await _outcome(_client(port, cases[label])))
		assert_str(got).override_failure_message("name case '%s' got '%s'" % [label, got]).is_equal("bad_name")


func test_names_valid_after_stripping_accepted() -> void:
	var port := _port()
	_server(port)
	assert_str(String(await _outcome(_client(port, "A".repeat(16))))).is_equal("ok")
	# 17 code points, one of them a bidi override: 16 after stripping.
	assert_str(String(await _outcome(_client(port, "A".repeat(16) + _chars([0x202E]))))).is_equal("ok")


func test_oversized_payload_rejected_before_decoding() -> void:
	var port := _port()
	_server(port)
	# Decoded, this would be a valid dictionary with a 17+ char name (bad_name). bad_payload proves the size gate ran first.
	var big := _good_payload({"display_name": "A".repeat(_knobs.net.auth_payload_cap_bytes)})
	assert_int(big.size()).is_greater(_knobs.net.auth_payload_cap_bytes)
	assert_str(await _raw_reason(_raw_client(port, big))).is_equal("bad_payload")


func test_payload_at_cap_is_decoded_not_size_rejected() -> void:
	var port := _port()
	_server(port)
	# Exactly at the cap: the size gate passes it, so the (too long) name is what rejects it.
	var d := {"version": SERVER_VERSION, "display_name": "", "token": ""}
	var pad := _knobs.net.auth_payload_cap_bytes - var_to_bytes(d).size()
	d.display_name = "A".repeat(pad)
	var at_cap := var_to_bytes(d)
	assert_int(at_cap.size()).is_equal(_knobs.net.auth_payload_cap_bytes)
	assert_str(await _raw_reason(_raw_client(port, at_cap))).is_equal("bad_name")


func test_malformed_payloads_rejected_bad_payload() -> void:
	var port := _port()
	_server(port)
	var cases := {
		"not a dictionary": var_to_bytes(42),
		"garbage bytes": PackedByteArray([1, 2, 3, 4, 5]),
		"missing field": var_to_bytes({"version": SERVER_VERSION, "display_name": "Ann"}),
		"wrong type version": var_to_bytes({"version": 7, "display_name": "Ann", "token": ""}),
		"wrong type name": var_to_bytes({"version": SERVER_VERSION, "display_name": ["Ann"], "token": ""}),
		"wrong type token": var_to_bytes({"version": SERVER_VERSION, "display_name": "Ann", "token": 5}),
		"extra field": _good_payload({"admin": true}),
	}
	for label in cases:
		var got := await _raw_reason(_raw_client(port, cases[label]))
		assert_str(got).override_failure_message("payload case '%s' got '%s'" % [label, got]).is_equal("bad_payload")


func test_object_encoded_payload_rejected_and_never_instantiated() -> void:
	var port := _port()
	_server(port)
	var canary := Node.new()
	var whole := var_to_bytes_with_objects(canary)
	var nested := var_to_bytes_with_objects({"version": SERVER_VERSION, "display_name": "Ann", "token": "", "o": canary})
	canary.free()
	var orphans_before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for payload in [whole, nested]:
		assert_str(await _raw_reason(_raw_client(port, payload))).is_equal("bad_payload")
	assert_float(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)).is_equal(orphans_before)


func test_reject_reason_arrives_in_20_of_20_attempts() -> void:
	var port := _port()
	_server(port)
	_lobby.count = _knobs.lobby.max_players
	var arrived := 0
	for i in 20:
		var c := _client(port, "Ann")
		var rejects: Array = c.rejects
		await _until(func() -> bool: return not rejects.is_empty(), "reject reason, attempt %d" % i)
		if not rejects.is_empty() and rejects[0] == &"lobby_full":
			arrived += 1
		# The server drops the peer only after the delay; clean up this client before the next.
		(c.net as NetAuthority).close()
	assert_int(arrived).override_failure_message("reason arrived in %d of 20" % arrived).is_equal(20)


func test_rejected_peer_is_disconnected_after_the_delay() -> void:
	var port := _port()
	_server(port)
	var raw := _raw_client(port, var_to_bytes(1))
	var api: SceneMultiplayer = raw.api
	await _raw_reason(raw)
	var t0 := Time.get_ticks_msec()
	await _until(func() -> bool:
		return api.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED,
		"server to drop the rejected peer")
	var dt := Time.get_ticks_msec() - t0
	assert_int(dt).is_greater(int(_knobs.net.reject_close_delay_s * 1000.0) - 80)


func test_host_on_used_port_emits_host_failed_and_leaves_nothing_set() -> void:
	var port := _port()
	_server(port)
	var second := _net(SERVER_VERSION)
	var failures: Array = []
	second.host_failed.connect(func(e: Error) -> void: failures.append(e))
	var err := second.host(port)
	assert_int(err).is_not_equal(OK)
	assert_array(failures).contains_exactly([err])
	var api := second.multiplayer as SceneMultiplayer
	assert_bool(api.multiplayer_peer is ENetMultiplayerPeer).is_false()
	assert_bool(api.auth_callback.is_valid()).is_false()
	assert_bool(api.server_relay).is_true() # engine default untouched: we never reached the setup
	assert_array(api.get_peers()).is_empty()
	# And the failed instance can host again once a port is free.
	assert_int(second.host(_port())).is_equal(OK)


func test_server_role_runs_with_no_local_player() -> void:
	var s := _server(_port())
	var api := s.multiplayer as SceneMultiplayer
	assert_bool(api.is_server()).is_true()
	assert_int(api.get_unique_id()).is_equal(1)
	assert_array(api.get_peers()).is_empty()
	assert_int(s.player_id_of(1)).is_equal(-1)
	assert_bool(api.server_relay).is_false()
	assert_float(api.auth_timeout).is_equal(_knobs.net.auth_timeout_s)
	assert_int(_lobby.count).is_equal(0)
	await get_tree().create_timer(0.2).timeout
	assert_bool(api.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED).is_true()


func test_sanitize_name_strips_controls_and_bidi() -> void:
	assert_str(NetAuthority.sanitize_name("a" + _chars([0x202E]) + "b" + _chars([1, 0x7F, 0x85, 0x2069, 0x200E]) + "c")).is_equal("abc")
	assert_str(NetAuthority.sanitize_name("Zo" + _chars([0xEB, 0x65E5, 0x672C]))).is_equal("Zo" + _chars([0xEB, 0x65E5, 0x672C]))
