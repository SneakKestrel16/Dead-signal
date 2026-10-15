# Story lobby-role-assignment/008: queue positions for absent, reconnecting and new players
# (lobby-role-assignment.md rule 10, Edge Cases; AC-LB-14, AC-LB-17, AC-LB-18). Whole rounds through
# LobbyState and RosterHandoff with a stand-in Match Flow ending each round. The network half of
# AC-LB-18 (a known token rejoining in Waiting keeps its token and player ID) is in
# tests/integration/network/tokens_reconnect_test.gd.
extends GdUnitTestSuite

const SEED := 8008
const SESSION := "s-1"
const SRC_DIR := "res://src"

var _knobs: Knobs
var _lobby: LobbyState
var _handoff: RosterHandoff
var _got: Array[Roster] = []
var _tick := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_lobby = LobbyState.new(_knobs)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_handoff = RosterHandoff.new(_lobby, _info, _knobs, rng, SESSION)
	_got = []
	_tick = 0
	_handoff.handed_off.connect(_on_handed_off)


func _on_handed_off(r: Roster) -> void:
	_got.append(r)


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


## Joins t1..t<n>, plays round 1 to Ended and returns Q_1 (the seeded shuffle) as [A, B, ...].
func _first_round(n: int) -> PackedStringArray:
	for i in n:
		_lobby.join("t%d" % (i + 1))
	var monster := _play_round()
	var q1 := _handoff.queue_order()
	assert_str(monster).is_equal(q1[0])
	_handoff.end_round(true)
	return q1


# --- AC1 (AC-LB-17): an absent token is skipped and keeps its place --------------------------------

func test_absent_player_is_skipped_keeps_place_and_goes_next_on_return() -> void:
	var q := _first_round(5) ## Q_1 = [A, B, C, D, E]; A was the shapeshifter
	var a := q[0]
	var b := q[1]
	var c := q[2]
	var d := q[3]
	var e := q[4]
	_lobby.leave(b) ## B absent for round 2
	assert_str(_play_round()).is_equal(c)
	_handoff.end_round(true)
	assert_array(Array(_handoff.queue_order())).is_equal([b, d, e, a, c])
	_lobby.join(b) ## B back for round 3
	assert_str(_play_round()).is_equal(b)


func test_cancelled_round_with_an_absent_head_leaves_the_queue_unchanged() -> void:
	var q := _first_round(5)
	_lobby.leave(q[1])
	var before := _handoff.queue_order()
	assert_str(_play_round()).is_equal(q[2])
	_handoff.end_round(false)
	assert_array(Array(_handoff.queue_order())).is_equal(Array(before))


func test_absent_tokens_are_never_pruned() -> void:
	var q := _first_round(6)
	_lobby.leave(q[1])
	_lobby.leave(q[2])
	for r in 3:
		_play_round()
		_handoff.end_round(true)
	var kept := Array(_handoff.queue_order())
	assert_int(kept.size()).is_equal(6)
	assert_bool(q[1] in kept and q[2] in kept).is_true()


# --- AC2 (AC-LB-18): same token keeps its place; a new token goes to the back ---------------------

func test_rejoin_with_the_same_token_keeps_the_queue_position() -> void:
	var q := _first_round(5)
	var before := _handoff.queue_order()
	_lobby.leave(q[2]) ## dropped; the rejoin arrives under a new peer ID, the same token
	_lobby.join(q[2])
	assert_str(_play_round()).is_equal(before[0])
	_handoff.end_round(false)
	assert_array(Array(_handoff.queue_order())).is_equal(Array(before))


func test_new_token_after_round_one_is_appended_at_the_back() -> void:
	var q := _first_round(5)
	_lobby.leave(q[1])
	_lobby.join("t9") ## q[1] lost their token: a new joiner to the server
	_lobby.join("t6") ## first join after round 1
	_play_round()
	var order := Array(_handoff.queue_order())
	assert_array(order.slice(order.size() - 2)).is_equal(["t9", "t6"])
	assert_int(order.find(q[1])).is_equal(0) ## the old token still holds its place, absent


# --- AC3 (AC-LB-14): no client can request a role ----------------------------------------------------

## A role reaches a Roster only through Roster.lock's queue pick; there is no RPC a client could call
## to ask for one. Scans src/ for any @rpc function whose name mentions a role.
func test_no_rpc_takes_a_role_request() -> void:
	var found := PackedStringArray()
	for path in _scripts(SRC_DIR):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size() - 1:
			if lines[i].strip_edges().begins_with("@rpc"):
				var decl := lines[i] + lines[i + 1]
				var name := decl.substr(decl.find("func ")).to_lower()
				if decl.find("func ") != -1 and (name.contains("role") or name.contains("shapeshifter")):
					found.append("%s:%d" % [path, i + 1])
	assert_array(Array(found)).is_empty()


func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(sub)))
	return out
