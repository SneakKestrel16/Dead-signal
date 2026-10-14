# Story lobby-role-assignment/001: ready and countdown state machine (lobby-role-assignment.md rule 13,
# Lobby countdown formula, AC-LB-05/21/22/23; ADR-0002 tick-counted timers). The clock is the tick
# number passed to server_tick(); seconds convert at the fixture's 60 Hz (t = 100.0 s is tick 6000).
extends GdUnitTestSuite

const HZ := 60
const COUNTDOWN_S := 5.0 ## the GDD's lobby_countdown_s (rule 13); fixture, not the shipped file
const MIN_PLAYERS := 5 ## MVP 5/5 (story Implementation Notes)
const FIVE: PackedStringArray = ["a", "b", "c", "d", "e"]

var _locked: Array = []


func _knobs(countdown_s := COUNTDOWN_S) -> Knobs:
	var k := Knobs.new()
	k.net = NetKnobs.new()
	k.net.sim_tick_hz = HZ
	k.lobby = LobbyKnobs.new()
	k.lobby.min_players = MIN_PLAYERS
	k.lobby.max_players = 6
	k.lobby.lobby_countdown_s = countdown_s
	return k


func _tick_of(seconds: float) -> int:
	return roundi(seconds * HZ)


## A lobby with `players` joined (and all Ready when `ready`), roster_locked recorded in _locked.
func _lobby(players: PackedStringArray, ready := true, countdown_s := COUNTDOWN_S) -> LobbyState:
	_locked.clear()
	var lobby := LobbyState.new(_knobs(countdown_s))
	lobby.roster_locked.connect(func(t: PackedStringArray) -> void: _locked.append(t))
	for p in players:
		lobby.join(p)
		if ready:
			lobby.set_ready(p, true)
	return lobby


## Ticks the lobby on every tick in [from, to].
func _run(lobby: LobbyState, from: int, to: int) -> void:
	for t in range(from, to + 1):
		lobby.server_tick(t)


func test_all_ready_at_100_gives_1_8_left_at_103_2_and_locks_at_105() -> void:
	var lobby := _lobby(FIVE)
	var start := _tick_of(100.0)
	lobby.server_tick(start)
	assert_str(lobby.state()).is_equal(LobbyState.COUNTDOWN)
	_run(lobby, start + 1, _tick_of(103.2))
	assert_float(lobby.remaining_s(_tick_of(103.2))).is_equal_approx(1.8, 0.0001)
	_run(lobby, _tick_of(103.2) + 1, _tick_of(105.0) - 1)
	assert_str(lobby.state()).is_equal(LobbyState.COUNTDOWN)
	assert_array(_locked).is_empty()
	lobby.server_tick(_tick_of(105.0))
	assert_str(lobby.state()).is_equal(LobbyState.IN_MATCH)
	assert_array(_locked).is_equal([FIVE])


func test_remaining_stays_within_0_and_countdown_s() -> void:
	var lobby := _lobby(FIVE)
	var start := _tick_of(100.0)
	assert_float(lobby.remaining_s(start - 50)).is_equal(COUNTDOWN_S) ## none running: full value
	lobby.server_tick(start)
	for t in range(start - 10, _tick_of(110.0)):
		var r := lobby.remaining_s(t)
		assert_bool(r >= 0.0 and r <= COUNTDOWN_S).override_failure_message("remaining %f at tick %d" % [r, t]).is_true()
	assert_float(lobby.remaining_s(_tick_of(105.0))).is_equal(0.0) ## exactly 0 on the boundary tick


func test_no_countdown_while_one_player_is_not_ready() -> void:
	var lobby := _lobby(FIVE)
	lobby.set_ready("c", false)
	_run(lobby, 0, _tick_of(10.0))
	assert_str(lobby.state()).is_equal(LobbyState.WAITING)
	assert_array(_locked).is_empty()


func test_three_ready_players_stay_waiting_with_only_their_tokens() -> void:
	var lobby := _lobby(["a", "b", "c"])
	_run(lobby, 0, _tick_of(10.0))
	assert_str(lobby.state()).is_equal(LobbyState.WAITING)
	assert_array(lobby.tokens()).is_equal(PackedStringArray(["a", "b", "c"])) ## no bot seat
	assert_array(_locked).is_empty()


func _cancel_and_restart(trigger: Callable, restore: Callable) -> void:
	var lobby := _lobby(FIVE)
	lobby.server_tick(0)
	_run(lobby, 1, _tick_of(3.0))
	trigger.call(lobby)
	assert_str(lobby.state()).is_equal(LobbyState.WAITING)
	assert_float(lobby.remaining_s(_tick_of(3.0))).is_equal(COUNTDOWN_S) ## a cancelled countdown shows full
	lobby.server_tick(_tick_of(3.0) + 1)
	assert_str(lobby.state()).is_equal(LobbyState.WAITING)
	restore.call(lobby)
	var again := _tick_of(4.0)
	lobby.server_tick(again)
	assert_str(lobby.state()).is_equal(LobbyState.COUNTDOWN)
	assert_float(lobby.remaining_s(again)).is_equal(COUNTDOWN_S) ## full value, not the 2 s left before
	_run(lobby, again + 1, again + _tick_of(COUNTDOWN_S) - 1)
	assert_array(_locked).is_empty()
	lobby.server_tick(again + _tick_of(COUNTDOWN_S))
	assert_int(_locked.size()).is_equal(1)


func test_an_unready_cancels_and_the_countdown_restarts_in_full() -> void:
	_cancel_and_restart(func(l: LobbyState) -> void: l.set_ready("b", false),
		func(l: LobbyState) -> void: l.set_ready("b", true))


func test_a_leave_cancels_and_the_countdown_restarts_in_full() -> void:
	_cancel_and_restart(func(l: LobbyState) -> void: l.leave("b"),
		func(l: LobbyState) -> void: l.join("b"); l.set_ready("b", true))


func test_a_join_cancels_and_the_countdown_restarts_in_full() -> void:
	_cancel_and_restart(func(l: LobbyState) -> void: l.join("f"),
		func(l: LobbyState) -> void: l.set_ready("f", true))


func test_everyone_unready_at_once_cancels() -> void:
	var lobby := _lobby(FIVE)
	lobby.server_tick(0)
	for p in FIVE:
		lobby.set_ready(p, false)
	_run(lobby, 1, _tick_of(COUNTDOWN_S) + 1)
	assert_str(lobby.state()).is_equal(LobbyState.WAITING)
	assert_array(_locked).is_empty()


func test_a_disconnect_on_the_lock_tick_returns_to_waiting_with_no_roster() -> void:
	var lobby := _lobby(FIVE)
	lobby.server_tick(0)
	var lock := _tick_of(COUNTDOWN_S)
	_run(lobby, 1, lock - 1)
	lobby.leave("e") ## processed in the lock tick, before the lobby's step
	lobby.server_tick(lock)
	assert_str(lobby.state()).is_equal(LobbyState.WAITING)
	assert_array(_locked).is_empty()


func test_countdown_length_comes_from_the_knob() -> void:
	var lobby := _lobby(FIVE, true, 3.0)
	lobby.server_tick(0)
	_run(lobby, 1, _tick_of(3.0) - 1)
	assert_array(_locked).is_empty()
	lobby.server_tick(_tick_of(3.0))
	assert_int(_locked.size()).is_equal(1)
