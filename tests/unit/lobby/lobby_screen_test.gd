# Story lobby-role-assignment/005: the logic behind the lobby screen (lobby-role-assignment.md UI
# Requirements, AC-LB-02; TR-lobby-001, -007, -010). The screen only displays server state: the server
# encodes the lobby (LobbySync.encode), every client decodes it (LobbySync.decode, untrusted bytes), and
# a client's only request is Ready on or off, matched byte for byte (LobbySync.ready_request). The host's
# own player is minted locally (NetAuthority.add_host_player). The look is in production/qa/evidence/lobby-screen/.
extends GdUnitTestSuite

const A := "tok-a"
const B := "tok-b"

var _knobs: Knobs
var _lobby: LobbyState
var _ids: Dictionary[String, int] = {A: 0, B: 3}
var _names: Dictionary[int, String] = {0: "Ann", 3: "Bob"}


func before_test() -> void:
	_knobs = Knobs.load_all()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5005
	_lobby = LobbyState.new(_knobs, rng)
	_lobby.host_token = A
	_lobby.join(A)
	_lobby.join(B)


func _id_of(token: String) -> int:
	return _ids.get(token, -1)


func _name_of(id: int) -> String:
	return _names.get(id, "")


func _encode(tick: int = 0) -> PackedByteArray:
	return LobbySync.encode(_lobby, tick, _id_of, _name_of)


func test_round_trip_lists_every_player_in_join_order_by_id() -> void:
	_lobby.set_ready(B, true)
	var s := LobbySync.decode(_encode())
	assert_str(s.state).is_equal("waiting")
	assert_int(s.host).is_equal(0)
	assert_bool(s.voice).is_false()
	assert_int(s.players.size()).is_equal(2)
	assert_dict(s.players[0]).is_equal({"id": 0, "name": "Ann", "ready": false, "pref": String(_lobby.preference(A))})
	assert_dict(s.players[1]).is_equal({"id": 3, "name": "Bob", "ready": true, "pref": String(_lobby.preference(B))})


func test_tokens_never_leave_the_server() -> void:
	var wire := var_to_str(bytes_to_var(_encode()))
	assert_bool(wire.contains("Ann")).is_true() # the dump does show strings
	for token in [A, B]:
		assert_bool(wire.contains(token)).is_false()


func test_countdown_shows_server_seconds_left_rounded_up() -> void:
	for i in range(2, _knobs.lobby.min_players):
		_lobby.join("tok-%d" % i)
	for t in _lobby.tokens():
		_lobby.set_ready(t, true)
	_lobby.server_tick(100)
	var hz := _knobs.net.sim_tick_hz
	var s := LobbySync.decode(_encode(100 + hz / 2))
	assert_str(s.state).is_equal("countdown")
	assert_int(s.countdown_s).is_equal(ceili(_knobs.lobby.lobby_countdown_s - 0.5))


func test_decode_rejects_bad_bytes() -> void:
	var good: Dictionary = bytes_to_var(_encode())
	assert_dict(LobbySync.decode(var_to_bytes(good))).is_not_empty() # control: re-encoded good bytes pass
	var other_ready := good.duplicate(true)
	other_ready.players[1].ready = "yes"
	assert_dict(LobbySync.decode(var_to_bytes(other_ready))).is_empty()
	assert_dict(LobbySync.decode(PackedByteArray([1, 2, 3]))).is_empty()
	assert_dict(LobbySync.decode(var_to_bytes([1, 2]))).is_empty()
	var big := PackedByteArray()
	big.resize(LobbySync.MAX_BYTES + 1)
	assert_dict(LobbySync.decode(big)).is_empty()
	var bad_ready := good.duplicate(true)
	bad_ready.players[0].ready = 1
	assert_dict(LobbySync.decode(var_to_bytes(bad_ready))).is_empty()
	var bad_state := good.duplicate(true)
	bad_state.state = "lol"
	assert_dict(LobbySync.decode(var_to_bytes(bad_state))).is_empty()
	var too_many := good.duplicate(true)
	for i in LobbySync.MAX_ROWS:
		too_many.players.append(good.players[0])
	assert_dict(LobbySync.decode(var_to_bytes(too_many))).is_empty()
	var extra := good.duplicate(true)
	extra["x"] = 1
	assert_dict(LobbySync.decode(var_to_bytes(extra))).is_empty()


func test_ready_request_matches_exact_packets_only() -> void:
	assert_int(LobbySync.ready_request(LobbySync.ready_packet(true))).is_equal(1)
	assert_int(LobbySync.ready_request(LobbySync.ready_packet(false))).is_equal(0)
	assert_int(LobbySync.ready_request(var_to_bytes({"ready": 1}))).is_equal(-1)
	var longer := LobbySync.ready_packet(true).duplicate()
	longer.append(0)
	assert_int(LobbySync.ready_request(longer)).is_equal(-1)
	assert_int(LobbySync.ready_request(_encode())).is_equal(-1)


func test_a_client_ready_request_cannot_start_a_countdown_alone() -> void:
	# A Ready request only sets that player's flag; the countdown still needs rule 13 on the server.
	LobbySync.apply_ready(_lobby, B, LobbySync.ready_packet(true))
	_lobby.server_tick(1)
	assert_bool(_lobby.is_ready(B)).is_true()
	assert_str(_lobby.state()).is_equal(LobbyState.WAITING)
	LobbySync.apply_ready(_lobby, B, var_to_bytes({"state": "countdown"}))
	assert_bool(_lobby.is_ready(B)).is_true()
	LobbySync.apply_ready(_lobby, B, LobbySync.ready_packet(false))
	assert_bool(_lobby.is_ready(B)).is_false()


func test_host_player_is_minted_locally() -> void:
	var net := NetAuthority.new()
	net.setup(_knobs, "v", _lobby)
	assert_int(net.add_host_player("Q".repeat(_knobs.lobby.name_max_chars + 1))).is_equal(-1)
	var id := net.add_host_player("Host" + char(0x202E))
	assert_int(id).is_equal(0)
	assert_int(net.local_player_id).is_equal(0)
	assert_str(net.display_name_of(id)).is_equal("Host")
	assert_int(net.player_id_of_token(net.local_token)).is_equal(id)
	assert_bool(net.local_token.is_empty()).is_false()
	net.free()


func test_reject_text_names_the_reason() -> void:
	assert_str(LobbyScreen.reject_text(NetAuthority.REASON_LOBBY_FULL, {})).is_equal("Lobby full")
	assert_str(LobbyScreen.reject_text(NetAuthority.REASON_ROUND_IN_PROGRESS, {})) \
			.is_equal("Round in progress, try again shortly")
	var v: String = LobbyScreen.reject_text(NetAuthority.REASON_VERSION_MISMATCH,
			{"server_version": "1.0+aa", "client_version": "0.9+bb"})
	assert_bool(v.contains("1.0+aa") and v.contains("0.9+bb")).is_true()
	assert_str(LobbyScreen.reject_text(&"whatever", {})).is_equal("Could not join")
