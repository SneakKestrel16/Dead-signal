# Story lobby-role-assignment/009: character preferences and clash resolution (lobby-role-assignment.md
# rules 6, 7, 17, Formulas "Character assignment"; AC-LB-07, AC-LB-08, AC-LB-09, AC-LB-12).
# CharacterAssignment.assign on its own, then whole rounds through LobbyState and RosterHandoff.
extends GdUnitTestSuite

const SEED := 9009
const SESSION := "s-1"

var _knobs: Knobs
var _lobby: LobbyState
var _handoff: RosterHandoff
var _got: Array[Roster] = []
var _tick := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_lobby = LobbyState.new(_knobs, _rng())
	_handoff = RosterHandoff.new(_lobby, _info, _knobs, _rng(SEED + 1), SESSION)
	_got = []
	_tick = 0
	_handoff.handed_off.connect(_on_handed_off)


func _on_handed_off(r: Roster) -> void:
	_got.append(r)


## Test stand-in for NetAuthority: token "t<n>" is player n, named "P<n>".
func _info(token: String) -> Dictionary:
	var n := token.trim_prefix("t").to_int()
	return {"player_id": n, "name": "P%d" % n}


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


## Survivors 10, 11, ... preferring `prefs` in order.
func _prefs(prefs: Array[StringName]) -> Dictionary[int, StringName]:
	var out: Dictionary[int, StringName] = {}
	for i in prefs.size():
		out[10 + i] = prefs[i]
	return out


# --- AC1 (AC-LB-07): a joiner's preference is drawn from the RNG and kept ----------------------

func test_a_new_player_gets_a_seeded_preference_from_c1_to_c5() -> void:
	var a := LobbyState.new(_knobs, _rng())
	var b := LobbyState.new(_knobs, _rng())
	a.join("t1")
	b.join("t1")
	assert_bool(a.preference("t1") in CharacterDef.IDS).is_true()
	assert_str(a.preference("t1")).is_equal(b.preference("t1"))
	var seen := {}
	for s in 50: ## the draw depends on the seed and reaches every character
		var l := LobbyState.new(_knobs, _rng(s))
		l.join("t1")
		seen[l.preference("t1")] = true
	assert_int(seen.size()).is_equal(5)


func test_preferences_are_unchanged_after_3_rounds() -> void:
	for i in 5:
		_lobby.join("t%d" % (i + 1))
	var before := {}
	for t in _lobby.tokens():
		before[t] = _lobby.preference(t)
	for r in 3:
		_play_round()
		_handoff.end_round(r != 1) ## Ended, Cancelled, Ended
	for t in _lobby.tokens():
		assert_str(_lobby.preference(t)).is_equal(before[t])


## Inference (TR-lobby-004: the token keys the preference): a leaver who rejoins keeps it, like their
## queue position. The GDD does not say; a designer ruling on rule 17 would settle it.
func test_a_rejoining_player_keeps_their_preference() -> void:
	_lobby.join("t1")
	var pref := _lobby.preference("t1")
	_lobby.leave("t1")
	for i in 20: ## would redraw on a rejoin treated as new
		_lobby.join("t%d" % (i + 2))
	_lobby.join("t1")
	assert_str(_lobby.preference("t1")).is_equal(pref)


func test_set_preference_accepts_a_character_and_rejects_anything_else() -> void:
	_lobby.join("t1")
	assert_bool(_lobby.set_preference("t1", &"C4")).is_true()
	assert_str(_lobby.preference("t1")).is_equal("C4")
	assert_bool(_lobby.set_preference("t1", &"C6")).is_false()
	assert_bool(_lobby.set_preference("t9", &"C1")).is_false()
	assert_str(_lobby.preference("t1")).is_equal("C4")
	assert_str(_lobby.preference("t9")).is_equal("")


# --- AC2 (AC-LB-08): distinct preferences are all honoured -------------------------------------

func test_distinct_preferences_each_get_their_pick() -> void:
	var cases: Array = [[&"C5", &"C1", &"C3"], [&"C2", &"C4", &"C1", &"C5"], [&"C3", &"C1", &"C5", &"C2", &"C4"]]
	for c: Array in cases:
		var picks: Array[StringName] = []
		picks.assign(c)
		var prefs := _prefs(picks)
		for s in 20:
			assert_dict(CharacterAssignment.assign(prefs, CharacterDef.IDS, _rng(s))).is_equal(prefs)


# --- AC3 (AC-LB-09): clashes keep one claimant, losers are dealt the free characters ------------

func test_clash_c1_c1_c2_c4_c4_keeps_one_of_each_and_deals_c3_c5_to_the_losers() -> void:
	var prefs := _prefs([&"C1", &"C1", &"C2", &"C4", &"C4"])
	var got := CharacterAssignment.assign(prefs, CharacterDef.IDS, _rng())
	assert_array(got.keys()).contains_exactly_in_any_order(prefs.keys())
	assert_str(got[12]).is_equal("C2")
	assert_int([got[10], got[11]].count(&"C1")).is_equal(1)
	assert_int([got[13], got[14]].count(&"C4")).is_equal(1)
	var losers: Array = []
	for id: int in got:
		if got[id] != prefs[id]:
			losers.append(got[id])
	assert_array(losers).contains_exactly_in_any_order([&"C3", &"C5"])
	assert_array(got.values()).contains_exactly_in_any_order(CharacterDef.IDS)
	assert_dict(CharacterAssignment.assign(prefs, CharacterDef.IDS, _rng())).is_equal(got) ## fixed seed


## Either claimant can win and either loser can get either free character, over seeds.
func test_clash_winner_and_loser_deal_vary_with_the_seed() -> void:
	var prefs := _prefs([&"C1", &"C1", &"C2", &"C4", &"C4"])
	var seen := {}
	for s in 200:
		var got := CharacterAssignment.assign(prefs, CharacterDef.IDS, _rng(s))
		seen["%s%s%s%s" % [got[10], got[11], got[13], got[14]]] = true
	assert_int(seen.size()).is_equal(8) ## 2 C1 winners x 2 C4 winners x 2 orders of {C3, C5}


# --- AC4 (AC-LB-12): the shapeshifter's preference is ignored for the round and kept -----------

func test_shapeshifter_preferring_c3_gets_none_a_survivor_gets_c3_and_the_preference_stays() -> void:
	for i in 5:
		_lobby.join("t%d" % (i + 1))
	var first := _play_round()
	_handoff.end_round(false) ## Cancelled: the same token is the shapeshifter again (rule 9)
	var monster := _shapeshifter_token(first)
	var survivors := Array(_lobby.tokens()).filter(func(t: String) -> bool: return t != monster)
	_lobby.set_preference(monster, &"C3")
	var picks: Array[StringName] = [&"C1", &"C2", &"C3", &"C4"] ## the C3 survivor is its sole survivor claimant
	for i in survivors.size():
		_lobby.set_preference(survivors[i], picks[i])
	var second := _play_round()
	assert_str(_shapeshifter_token(second)).is_equal(monster)
	assert_str(second.entry(monster.trim_prefix("t").to_int()).character).is_equal("")
	assert_str(second.entry(survivors[2].trim_prefix("t").to_int()).character).is_equal("C3")
	_handoff.end_round(true)
	assert_str(_lobby.preference(monster)).is_equal("C3")
