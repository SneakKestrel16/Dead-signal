# Story lobby-role-assignment/010: clash fairness and the Ready preference lock (lobby-role-assignment.md
# rule 12, Formulas "Character assignment"; AC-LB-10, AC-LB-11, AC-LB-20; TR-lobby-006).
# One seeded RNG per test, so every run draws the same sequence.
extends GdUnitTestSuite

const SEED := 10010
const SETS := 1000
const TRIALS := 10000
const TOLERANCE := 0.02 ## over 4 sigma at these counts (AC-LB-11)

var _knobs: Knobs


func before_test() -> void:
	_knobs = Knobs.load_all()


func _rng(s := SEED) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


## Survivors 10, 11, ... preferring `prefs` in order.
func _prefs(prefs: Array[StringName]) -> Dictionary[int, StringName]:
	var out: Dictionary[int, StringName] = {}
	for i in prefs.size():
		out[10 + i] = prefs[i]
	return out


# --- AC1 (AC-LB-10): every result distinct, sole claimants keep their pick ---------------------

func test_1000_seeded_preference_sets_at_3_4_5_survivors_give_valid_assignments() -> void:
	var rng := _rng()
	for n in [3, 4, 5]:
		for s in SETS:
			var picks: Array[StringName] = []
			for i in n: ## set 0 is "all prefer C1"; the rest are uniform random
				picks.append(&"C1" if s == 0 else CharacterDef.IDS[rng.randi_range(0, CharacterDef.IDS.size() - 1)])
			var prefs := _prefs(picks)
			var got := CharacterAssignment.assign(prefs, CharacterDef.IDS, rng)
			assert_array(got.keys()).contains_exactly_in_any_order(prefs.keys())
			var held := {}
			for id: int in got:
				assert_bool(CharacterDef.IDS.has(got[id])).is_true()
				held[got[id]] = true
				if picks.count(prefs[id]) == 1:
					assert_str(got[id]).is_equal(prefs[id])
			assert_int(held.size()).is_equal(n)


# --- AC2 (AC-LB-11): uniform clash winner, uniform deal to each loser ---------------------------

func test_k_claimants_each_keep_the_clash_in_1_over_k_and_losers_get_each_free_in_1_over_free() -> void:
	for k in [2, 3, 5]:
		var picks: Array[StringName] = []
		for i in k:
			picks.append(&"C1")
		var prefs := _prefs(picks)
		var free: Array[StringName] = [&"C2", &"C3", &"C4", &"C5"]
		var wins := {}
		var dealt := {} ## survivor -> {free character -> count}
		for id: int in prefs:
			wins[id] = 0
			dealt[id] = {}
			for c in free:
				dealt[id][c] = 0
		var rng := _rng(SEED + k)
		for t in TRIALS:
			var got := CharacterAssignment.assign(prefs, CharacterDef.IDS, rng)
			for id: int in got:
				if got[id] == &"C1":
					wins[id] += 1
				else:
					dealt[id][got[id]] += 1
		for id: int in prefs:
			assert_float(float(wins[id]) / TRIALS).is_between(1.0 / k - TOLERANCE, 1.0 / k + TOLERANCE)
			var losses: int = TRIALS - wins[id]
			for c in free:
				assert_float(float(dealt[id][c]) / losses) \
					.is_between(1.0 / free.size() - TOLERANCE, 1.0 / free.size() + TOLERANCE)


# --- AC3 (AC-LB-20): a Ready player's preference is locked --------------------------------------

func test_a_ready_player_cannot_change_preference_until_they_unready() -> void:
	var lobby := LobbyState.new(_knobs, _rng())
	lobby.join("t1")
	lobby.set_preference("t1", &"C2")
	lobby.set_ready("t1", true)
	assert_bool(lobby.set_preference("t1", &"C4")).is_false()
	assert_str(lobby.preference("t1")).is_equal("C2")
	lobby.set_ready("t1", false)
	assert_bool(lobby.set_preference("t1", &"C4")).is_true()
	assert_str(lobby.preference("t1")).is_equal("C4")
