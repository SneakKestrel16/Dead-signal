# Story lobby-role-assignment/007: shapeshifter rotation queue (lobby-role-assignment.md rules 8-10,
# Formulas "Rotation queue"; AC-LB-13, AC-LB-15, AC-LB-16). RotationQueue on its own, then whole
# rounds through LobbyState and RosterHandoff with a stand-in Match Flow ending each round.
extends GdUnitTestSuite

const SEED := 7007
const SESSION := "s-1"

var _knobs: Knobs
var _lobby: LobbyState
var _handoff: RosterHandoff
var _got: Array[Roster] = []
var _tick := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_lobby = LobbyState.new(_knobs, _rng(SEED + 1)) ## seeded preferences: the redeal check below is deterministic
	_handoff = RosterHandoff.new(_lobby, _info, _knobs, _rng(), SESSION)
	_got = []
	_tick = 0
	_handoff.handed_off.connect(func(r: Roster) -> void: _got.append(r))


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


## Readies everyone in the lobby and runs the countdown to 0; returns the locked roster.
func _play_round() -> Roster:
	for t in _lobby.tokens():
		_lobby.set_ready(t, true)
	for i in _knobs.ticks(_knobs.lobby.lobby_countdown_s) + 2:
		_tick += 1
		_lobby.server_tick(_tick)
	return _got.back()


func _shapeshifter_token(r: Roster) -> String:
	for id in r.player_ids():
		if r.entry(id).role == Roster.SHAPESHIFTER:
			return "t%d" % id
	return ""


# --- AC1 (AC-LB-13): Q_1 is a seeded shuffle, its head the shapeshifter -------------------------

func test_first_queue_holds_each_token_once_reproducibly_from_the_seed() -> void:
	for n: int in [4, 5, 6]:
		var a := RotationQueue.new()
		var b := RotationQueue.new()
		a.pick(_tokens(n), _rng())
		b.pick(_tokens(n), _rng())
		var sorted := Array(a.order())
		sorted.sort()
		assert_array(sorted).override_failure_message("%d tokens" % n).is_equal(Array(_tokens(n)))
		assert_array(Array(a.order())).is_equal(Array(b.order()))


func test_first_queue_is_shuffled_not_join_order() -> void:
	var orders := {}
	for s in 20:
		var q := RotationQueue.new()
		q.pick(_tokens(5), _rng(s))
		orders[",".join(q.order())] = true
	assert_int(orders.size()).is_greater(1)


func test_first_round_shapeshifter_is_the_head_of_the_queue() -> void:
	for t in _tokens(5):
		_lobby.join(t)
	var r := _play_round()
	assert_str(_shapeshifter_token(r)).is_equal(_handoff.queue_order()[0])


# --- AC2 (AC-LB-15): stable roster, 2N Ended rounds -------------------------------------------

func test_stable_roster_rotates_through_first_queue_each_token_twice() -> void:
	for n: int in [4, 5, 6]:
		before_test()
		for t in _tokens(n):
			_lobby.join(t)
		var q1 := PackedStringArray()
		var turns: Dictionary[String, int] = {}
		for rnd in range(1, 2 * n + 1):
			var ss := _shapeshifter_token(_play_round())
			if rnd == 1:
				q1 = _handoff.queue_order()
			assert_str(ss).override_failure_message("N=%d round %d" % [n, rnd]).is_equal(q1[(rnd - 1) % n])
			turns[ss] = turns.get(ss, 0) + 1
			# Round 2 stands for the AC's forfeit: a forfeit reaches Ended (rule 9), and end_round takes
			# only Ended or Cancelled; Match Flow's forfeit-to-Ended mapping is tested in its own story.
			_handoff.end_round(true)
		assert_int(turns.size()).is_equal(n)
		for t: String in turns:
			assert_int(turns[t]).override_failure_message("N=%d %s" % [n, t]).is_equal(2)


# --- AC3 (AC-LB-16): a Cancelled round does not advance the queue ------------------------------

func test_cancelled_round_keeps_the_queue_and_shapeshifter_and_redeals_characters() -> void:
	for t in _tokens(6):
		_lobby.join(t)
	var first := _play_round()
	var queue := _handoff.queue_order()
	_handoff.end_round(false)
	var second := _play_round()
	assert_array(Array(_handoff.queue_order())).is_equal(Array(queue))
	assert_str(_shapeshifter_token(second)).is_equal(_shapeshifter_token(first))
	assert_object(second).is_not_same(first)
	# The deal ran again on the moved RNG: the same survivors hold a different set of characters (the
	# seed is fixed, so this is deterministic; a deal that was copied from round 1 would match).
	var chars := {}
	var changed := false
	for id in second.player_ids():
		if second.entry(id).role == Roster.SURVIVOR:
			chars[second.entry(id).character] = true
			changed = changed or second.entry(id).character != first.entry(id).character
	assert_int(chars.size()).is_equal(5) # every survivor dealt a distinct character again
	assert_bool(changed).is_true()


# --- Rule 10: a first-time joiner goes to the back --------------------------------------------

func test_first_time_joiner_is_appended_at_the_back() -> void:
	for t in _tokens(4):
		_lobby.join(t)
	_play_round()
	_handoff.end_round(true)
	var q_before := _handoff.queue_order()
	_lobby.join("t9")
	_play_round()
	var q_after := _handoff.queue_order()
	assert_int(q_after.size()).is_equal(5)
	assert_str(q_after[4]).is_equal("t9")
	assert_array(Array(q_after.slice(0, 4))).is_equal(Array(q_before))


# --- RotationQueue.advance on its own ----------------------------------------------------------

func test_advance_moves_the_picked_token_to_the_back_once() -> void:
	var q := RotationQueue.new()
	var head := q.pick(_tokens(4), _rng())
	var start := q.order()
	q.advance()
	q.advance() ## a second call without a pick does nothing
	var expected := Array(start.slice(1))
	expected.append(head)
	assert_array(Array(q.order())).is_equal(expected)


func test_advance_without_a_pick_does_nothing() -> void:
	var q := RotationQueue.new()
	q.advance()
	assert_array(Array(q.order())).is_empty()
