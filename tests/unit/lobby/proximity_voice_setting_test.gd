# Story lobby-role-assignment/004: host session setting, proximity voice (lobby-role-assignment.md
# rule 16, AC-LB-25; TR-lobby-009: a host-only, server-validated action). Server side only: the
# fan-out to clients (AC-LB-26) is in tests/integration/lobby/proximity_voice_replication_test.gd.
extends GdUnitTestSuite

const HOST := "host-tok"
const FIVE: PackedStringArray = ["host-tok", "b", "c", "d", "e"]

var _changes: Array = []


func _lobby() -> LobbyState:
	_changes.clear()
	var k := Knobs.new()
	k.net = NetKnobs.new()
	k.net.sim_tick_hz = 60
	k.lobby = LobbyKnobs.new()
	k.lobby.min_players = 5
	k.lobby.max_players = 6
	k.lobby.lobby_countdown_s = 5.0
	var lobby := LobbyState.new(k)
	lobby.host_token = HOST
	lobby.proximity_voice_changed.connect(_on_changed)
	for p in FIVE:
		lobby.join(p)
	return lobby


func _on_changed(on: bool) -> void:
	_changes.append(on)


func _ready_all(lobby: LobbyState) -> void:
	for p in FIVE:
		lobby.set_ready(p, true)


func test_new_session_proximity_voice_is_off() -> void:
	assert_bool(_lobby().proximity_voice()).is_false()


func test_host_in_waiting_change_is_accepted_and_announced() -> void:
	var lobby := _lobby()
	assert_bool(lobby.set_proximity_voice(HOST, true)).is_true()
	assert_bool(lobby.proximity_voice()).is_true()
	assert_bool(lobby.set_proximity_voice(HOST, false)).is_true()
	assert_bool(lobby.proximity_voice()).is_false()
	assert_array(_changes).is_equal([true, false])


func test_non_host_change_is_rejected() -> void:
	var lobby := _lobby()
	assert_bool(lobby.set_proximity_voice("b", true)).is_false()
	assert_bool(lobby.set_proximity_voice("stranger", true)).is_false()
	assert_bool(lobby.proximity_voice()).is_false()
	assert_array(_changes).is_empty()


func test_no_host_set_rejects_even_an_empty_token() -> void:
	var lobby := _lobby()
	lobby.host_token = ""
	assert_bool(lobby.set_proximity_voice("", true)).is_false()
	assert_bool(lobby.proximity_voice()).is_false()


func test_host_in_countdown_change_is_rejected() -> void:
	var lobby := _lobby()
	_ready_all(lobby)
	lobby.server_tick(0)
	assert_str(lobby.state()).is_equal(LobbyState.COUNTDOWN)
	assert_bool(lobby.set_proximity_voice(HOST, true)).is_false()
	assert_bool(lobby.proximity_voice()).is_false()
	assert_array(_changes).is_empty()


func test_host_in_match_change_is_rejected() -> void:
	var lobby := _lobby()
	_ready_all(lobby)
	lobby.server_tick(0)
	lobby.server_tick(300) # 5 s at 60 Hz: the countdown reaches 0 and the roster locks
	assert_str(lobby.state()).is_equal(LobbyState.IN_MATCH)
	assert_bool(lobby.set_proximity_voice(HOST, true)).is_false()
	assert_bool(lobby.proximity_voice()).is_false()
	assert_array(_changes).is_empty()


func test_setting_unchanged_is_accepted_without_announcement() -> void:
	var lobby := _lobby()
	assert_bool(lobby.set_proximity_voice(HOST, false)).is_true()
	assert_array(_changes).is_empty()


func test_setting_survives_a_round() -> void:
	var lobby := _lobby()
	lobby.set_proximity_voice(HOST, true)
	_ready_all(lobby)
	lobby.server_tick(0)
	lobby.server_tick(300)
	lobby.return_to_waiting()
	assert_bool(lobby.proximity_voice()).is_true()
