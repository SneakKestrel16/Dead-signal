# Story lobby-role-assignment/002: roster lock, Match Flow hand-off and return to Waiting
# (lobby-role-assignment.md rules 7, 8, 13, 14; AC-LB-01, AC-LB-24, AC-LB-27). A LobbyState runs its
# countdown on the server clock; RosterHandoff locks the roster, publishes RosterView in a
# StateRegistry and hands it to a stand-in Match Flow (a signal recorder).
extends GdUnitTestSuite

const SEED := 2002
const SESSION := "s-1"

var _knobs: Knobs
var _lobby: LobbyState
var _handoff: RosterHandoff
var _registry: StateRegistry
var _got: Array[Roster] = []
var _tick := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_lobby = LobbyState.new(_knobs)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_handoff = RosterHandoff.new(_lobby, _info, _knobs, rng, SESSION)
	_registry = StateRegistry.new()
	_registry.fail_hard = false
	_got = []
	# Stand-in Match Flow: starts the round (a fresh registry), then the root publishes the view.
	_handoff.handed_off.connect(func(r: Roster) -> void:
		_got.append(r)
		_handoff.publish(_registry))


func after_test() -> void:
	assert_array(_registry.violations).is_empty() # one registration per key and round
	_tick = 0


## Test stand-in for NetAuthority: token "t<n>" is player n, named "P<n>".
func _info(token: String) -> Dictionary:
	var n := token.trim_prefix("t").to_int()
	return {"player_id": n, "name": "P%d" % n}


func _tokens(n: int) -> PackedStringArray:
	var out := PackedStringArray()
	for i in n:
		out.append("t%d" % (i + 1))
	return out


func _rng(s := SEED) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


## Joins `n` players, readies them all and runs the countdown to 0.
func _lock(n: int) -> void:
	for t in _tokens(n):
		_lobby.join(t)
		_lobby.set_ready(t, true)
	for i in _knobs.ticks(_knobs.lobby.lobby_countdown_s) + 2:
		_tick += 1
		_lobby.server_tick(_tick)


func _roles(r: Roster) -> Dictionary:
	var count := {Roster.SHAPESHIFTER: 0, Roster.SURVIVOR: 0}
	for id in r.player_ids():
		count[r.entry(id).role] += 1
	return count


# --- AC1: 4-6 players, exactly one shapeshifter ----------------------------------

func test_four_five_and_six_players_hold_one_shapeshifter() -> void:
	for n: int in [4, 5, 6]:
		var r := Roster.lock(_tokens(n), _info, SESSION, 1, _knobs, RotationQueue.new(), _rng())
		assert_int(r.player_count()).is_equal(n)
		assert_dict(_roles(r)).override_failure_message("%d players" % n) \
			.is_equal({Roster.SHAPESHIFTER: 1, Roster.SURVIVOR: n - 1})


func test_three_or_seven_players_are_refused() -> void:
	for n: int in [3, 7]:
		assert_object(Roster.lock(_tokens(n), _info, SESSION, 1, _knobs, RotationQueue.new(), _rng())) \
			.override_failure_message("%d players" % n).is_null()


## Code review 2026-10-14: two tokens naming one player counted it twice.
func test_two_tokens_naming_one_player_are_refused() -> void:
	var info := func(t: String) -> Dictionary: return {"player_id": 1, "name": "P1"} if t == "t2" else _info(t)
	assert_object(Roster.lock(_tokens(4), info, SESSION, 1, _knobs, RotationQueue.new(), _rng())).is_null()


## Code review 2026-10-14: a player who drops in the lock tick (info gives -1) refuses the roster
## and the lobby returns to Waiting with no hand-off.
func test_a_roster_that_cannot_lock_sends_the_lobby_back_to_waiting() -> void:
	var lobby := LobbyState.new(_knobs)
	var handoff := RosterHandoff.new(lobby, func(_t: String) -> Dictionary: return {"player_id": -1}, _knobs, _rng(), SESSION)
	var fired := []
	handoff.handed_off.connect(func(r: Roster) -> void: fired.append(r))
	for t in _tokens(4):
		lobby.join(t)
		lobby.set_ready(t, true)
	for i in _knobs.ticks(_knobs.lobby.lobby_countdown_s) + 2:
		lobby.server_tick(i + 1)
	assert_array(fired).is_empty()
	assert_str(lobby.state()).is_equal(LobbyState.WAITING)
	assert_object(handoff.roster).is_null()


func test_an_unknown_token_is_refused() -> void:
	var tokens := _tokens(4)
	tokens[2] = "nobody"
	var info := func(t: String) -> Dictionary: return {"player_id": -1} if t == "nobody" else _info(t)
	assert_object(Roster.lock(tokens, info, SESSION, 1, _knobs, RotationQueue.new(), _rng())).is_null()


## The first round's pick (Q_1's head, story 007) is uniform: over 4000 seeds each of 4 players is the
## shapeshifter about 1000 times (850-1150 is about 5.5 standard deviations wide each side).
func test_first_round_shapeshifter_pick_is_uniform_over_seeds() -> void:
	var counts := {}
	for s in 4000:
		var r := Roster.lock(_tokens(4), _info, SESSION, 1, _knobs, RotationQueue.new(), _rng(s))
		for id in r.player_ids():
			if r.entry(id).role == Roster.SHAPESHIFTER:
				counts[id] = counts.get(id, 0) + 1
	assert_int(counts.size()).is_equal(4)
	for id: int in counts:
		assert_int(counts[id]).override_failure_message("player %d: %d" % [id, counts[id]]).is_between(850, 1150)


# --- AC2: hand-off at countdown 0 ------------------------------------------------

func test_countdown_zero_hands_match_flow_the_roster() -> void:
	_lock(5)
	assert_int(_got.size()).is_equal(1)
	var r := _got[0]
	assert_str(_lobby.state()).is_equal(LobbyState.IN_MATCH)
	assert_int(r.player_count()).is_equal(5)
	assert_str(r.session_id()).is_equal(SESSION)
	assert_int(r.round_index()).is_equal(1)
	var chars := {}
	for id in r.player_ids():
		var e := r.entry(id)
		assert_str(e.name).is_equal("P%d" % id)
		if e.role == Roster.SHAPESHIFTER:
			assert_str(e.character).is_equal("")
		else:
			assert_bool(e.character in CharacterDef.IDS).is_true()
			chars[e.character] = true
	assert_int(chars.size()).is_equal(4) # each survivor a distinct character


## Code review 2026-10-14: the handed-off Roster had public writable fields; now nothing outside
## lock() can change them (getters only).
func test_handed_off_roster_has_no_writable_field() -> void:
	_lock(4)
	for p in _got[0].get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			assert_str(p.name).override_failure_message("public field " + p.name).starts_with("_")


func test_player_count_does_not_change_for_the_round() -> void:
	_lock(5)
	_lobby.leave("t2") # a survivor disconnects mid-round
	_lobby.join("t9") # a joiner waits in the dormant lobby
	var view := _registry.view(StateKeys.PLAYER_ROSTER, RosterView) as RosterView
	assert_int(view.get_player_count()).is_equal(5)
	assert_int(_got[0].player_count()).is_equal(5)


func test_the_roster_is_published_as_a_roster_view() -> void:
	_lock(4)
	var view := _registry.view(StateKeys.PLAYER_ROSTER, RosterView) as RosterView
	assert_object(view).is_not_null()
	var r := _got[0]
	assert_array(view.get_player_ids()).is_equal(r.player_ids())
	for id in r.player_ids():
		assert_str(view.get_role(id)).is_equal(r.entry(id).role)
		assert_str(view.get_display_name(id)).is_equal(r.entry(id).name)
		assert_str(view.get_character(id)).is_equal(r.entry(id).character)


# --- AC3: RosterView is read-only ------------------------------------------------

func test_roster_view_exposes_no_setter_and_no_public_field() -> void:
	var view := RosterView.new(Roster.lock(_tokens(4), _info, SESSION, 1, _knobs, RotationQueue.new(), _rng()))
	for m in (view.get_script() as Script).get_script_method_list(): # its own methods, not Object's
		assert_bool(String(m.name).begins_with("set_")).override_failure_message(m.name).is_false()
	for p in view.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			assert_str(p.name).override_failure_message("public field " + p.name).starts_with("_")


func test_roster_entries_are_copies() -> void:
	var r := Roster.lock(_tokens(4), _info, SESSION, 1, _knobs, RotationQueue.new(), _rng())
	var id := r.player_ids()[0]
	r.entry(id).role = &"hacked"
	assert_str(r.entry(id).role).is_not_equal("hacked")


# --- AC4: back to Waiting ---------------------------------------------------------

func test_after_results_everyone_is_back_in_waiting_with_ready_cleared() -> void:
	_lock(5)
	var gone := -1
	for id in _got[0].player_ids():
		if _got[0].entry(id).role == Roster.SURVIVOR:
			gone = id
	_lobby.leave("t%d" % gone) # a survivor whose grace expired mid-round
	_lobby.join("t9") # joined the dormant lobby mid-match
	_handoff.end_round(true)
	assert_str(_lobby.state()).is_equal(LobbyState.WAITING)
	var expected := ["t1", "t2", "t3", "t4", "t5", "t9"]
	expected.erase("t%d" % gone)
	assert_array(Array(_lobby.tokens())).is_equal(expected)
	assert_object(_handoff.roster).is_null()
	_tick += 1
	_lobby.server_tick(_tick) # nobody is Ready: no countdown starts
	assert_str(_lobby.state()).is_equal(LobbyState.WAITING)


func test_after_a_cancelled_round_the_next_lock_is_round_two() -> void:
	_lock(4)
	_handoff.end_round(false) # Cancelled: same return path
	_tick += 1
	_lobby.server_tick(_tick)
	assert_str(_lobby.state()).is_equal(LobbyState.WAITING) # Ready cleared: no countdown starts
	_registry = StateRegistry.new() # the next round's fresh registry
	_registry.fail_hard = false
	for t in _lobby.tokens():
		_lobby.set_ready(t, true)
	for i in _knobs.ticks(_knobs.lobby.lobby_countdown_s) + 2:
		_tick += 1
		_lobby.server_tick(_tick)
	assert_int(_got.size()).is_equal(2)
	assert_int(_got[1].round_index()).is_equal(2)


func test_a_disconnect_during_the_countdown_locks_no_roster() -> void:
	for t in _tokens(4):
		_lobby.join(t)
		_lobby.set_ready(t, true)
	for i in 10:
		_tick += 1
		_lobby.server_tick(_tick)
	_lobby.leave("t4")
	for i in _knobs.ticks(_knobs.lobby.lobby_countdown_s) + 2:
		_tick += 1
		_lobby.server_tick(_tick)
	assert_array(_got).is_empty()
	assert_str(_lobby.state()).is_equal(LobbyState.WAITING)
