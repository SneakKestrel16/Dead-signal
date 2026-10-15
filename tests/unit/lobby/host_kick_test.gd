# Story lobby-role-assignment/011: host kick (lobby-role-assignment.md rule 20, AC-LB-30; TR-lobby-009:
# a host-only, server-validated action). The lobby half: validation, removal and the queue place. The
# network half (the peer is disconnected with a reason and can rejoin under its token) is in
# tests/integration/lobby/host_kick_net_test.gd.
extends GdUnitTestSuite

const SEED := 8011
const SESSION := "s-1"

var _knobs: Knobs
var _lobby: LobbyState
var _handoff: RosterHandoff
var _got: Array[Roster] = []
var _kicked: Array[String] = []
var _tick := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_lobby = LobbyState.new(_knobs)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_handoff = RosterHandoff.new(_lobby, _info, _knobs, rng, SESSION)
	_got = []
	_kicked = []
	_tick = 0
	_handoff.handed_off.connect(_on_handed_off)
	_lobby.player_kicked.connect(_on_kicked)
	_lobby.host_token = "t1"
	for i in 5:
		_lobby.join("t%d" % (i + 1))


func _on_handed_off(r: Roster) -> void:
	_got.append(r)


func _on_kicked(token: String) -> void:
	_kicked.append(token)


## Test stand-in for NetAuthority: token "t<n>" is player n, named "P<n>".
func _info(token: String) -> Dictionary:
	var n := token.trim_prefix("t").to_int()
	return {"player_id": n, "name": "P%d" % n}


## Readies everyone in the lobby and runs the countdown to 0; returns the shapeshifter's token.
func _play_round() -> String:
	for t in _lobby.tokens():
		_lobby.set_ready(t, true)
	for i in _knobs.ticks(_knobs.lobby.lobby_countdown_s) + 2:
		_tick += 1
		_lobby.server_tick(_tick)
	var r: Roster = _got.back()
	for id in r.player_ids():
		if r.entry(id).role == Roster.SHAPESHIFTER:
			return "t%d" % id
	return ""


func _to_countdown() -> void:
	for t in _lobby.tokens():
		_lobby.set_ready(t, true)
	_tick += 1
	_lobby.server_tick(_tick)
	assert_str(_lobby.state()).is_equal(LobbyState.COUNTDOWN)


# --- AC1: in Waiting the host's kick removes the player --------------------------------------------

func test_host_kick_in_waiting_removes_the_player_and_announces_it() -> void:
	var pref := _lobby.preference("t3")
	assert_bool(_lobby.kick("t1", "t3")).is_true()
	assert_array(Array(_lobby.tokens())).is_equal(["t1", "t2", "t4", "t5"])
	assert_array(_kicked).is_equal(["t3"])
	assert_str(_lobby.preference("t3")).is_equal(pref) ## removed like a leaver: the token's data stays


func test_kicked_player_can_rejoin() -> void:
	_lobby.kick("t1", "t3")
	_lobby.join("t3")
	assert_bool(_lobby.tokens().has("t3")).is_true()


func test_kicked_player_keeps_queue_position_and_goes_next_on_return() -> void:
	var a := _play_round()
	var q := _handoff.queue_order() ## Q_1 = [A, B, C, D, E]
	_handoff.end_round(true)
	_lobby.return_to_waiting()
	var b := q[1]
	_lobby.host_token = q[4] if b != q[4] else q[3]
	assert_bool(_lobby.kick(_lobby.host_token, b)).is_true()
	assert_str(_play_round()).is_equal(q[2]) ## B is absent and skipped
	_handoff.end_round(true)
	_lobby.return_to_waiting()
	assert_array(Array(_handoff.queue_order())).is_equal([b, q[3], q[4], a, q[2]])
	_lobby.join(b)
	assert_str(_play_round()).is_equal(b) ## back, and still at the head


# --- AC2: anyone else, or the host outside Waiting, is rejected -----------------------------------

func test_non_host_kick_is_rejected() -> void:
	assert_bool(_lobby.kick("t2", "t3")).is_false()
	assert_bool(_lobby.kick("stranger", "t3")).is_false()
	assert_int(_lobby.player_count()).is_equal(5)
	assert_array(_kicked).is_empty()


func test_no_host_set_rejects_even_an_empty_token() -> void:
	_lobby.host_token = ""
	assert_bool(_lobby.kick("", "t3")).is_false()
	assert_int(_lobby.player_count()).is_equal(5)


func test_host_kick_in_countdown_is_rejected() -> void:
	_to_countdown()
	assert_bool(_lobby.kick("t1", "t3")).is_false()
	assert_str(_lobby.state()).is_equal(LobbyState.COUNTDOWN)
	assert_int(_lobby.player_count()).is_equal(5)
	assert_array(_kicked).is_empty()


func test_host_kick_in_match_is_rejected() -> void:
	_play_round()
	assert_str(_lobby.state()).is_equal(LobbyState.IN_MATCH)
	assert_bool(_lobby.kick("t1", "t3")).is_false()
	assert_int(_lobby.player_count()).is_equal(5)
	assert_array(_kicked).is_empty()


func test_host_cannot_kick_themselves_or_an_absent_player() -> void:
	assert_bool(_lobby.kick("t1", "t1")).is_false()
	assert_bool(_lobby.kick("t1", "nobody")).is_false()
	_lobby.leave("t3")
	assert_bool(_lobby.kick("t1", "t3")).is_false()
	assert_array(_kicked).is_empty()
