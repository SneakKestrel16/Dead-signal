# Story lobby-role-assignment/003: character data and the M1 random deal (lobby-role-assignment.md
# rules 3-7, AC-LB-06, Tuning Knobs).
extends GdUnitTestSuite

const SEED := 3003


func _rng(s: int = SEED) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	return rng


func _survivors(n: int) -> Array[int]:
	var out: Array[int] = []
	for i in n:
		out.append(10 + i)
	return out


# --- AC1: character data --------------------------------------------------------

func test_shipped_data_defines_five_distinct_characters_none_the_true_form() -> void:
	var cast := CharacterDef.load_all()
	assert_array(CharacterDef.errors(cast)).is_empty()
	var ids: Array[StringName] = []
	for c in cast:
		ids.append(c.id)
		assert_int(c.appearance_id).is_not_equal(CharacterDef.TRUE_FORM_APPEARANCE_ID)
	assert_array(ids).is_equal(CharacterDef.IDS)


func test_duplicate_look_colour_or_voice_and_true_form_look_are_errors() -> void:
	var copy: Array[CharacterDef] = []
	for c in CharacterDef.load_all():
		copy.append(c.duplicate() as CharacterDef) ## copies: the cached shipped resources stay untouched
	copy[1].appearance_id = copy[0].appearance_id
	copy[2].colour = copy[0].colour
	copy[3].voice_set = copy[0].voice_set
	copy[4].appearance_id = CharacterDef.TRUE_FORM_APPEARANCE_ID
	var errs := " | ".join(CharacterDef.errors(copy))
	assert_str(errs).contains("C2: same look as C1").contains("C3: same colour as C1") \
		.contains("C4: same voice set as C1").contains("C5: appearance_id 0")


func test_a_missing_character_file_is_an_error() -> void:
	var cast := CharacterDef.load_all("res://tests/no_such_dir/")
	assert_str(" ".join(CharacterDef.errors(cast))).contains("C1: file missing")


# --- AC2: M1 deal ---------------------------------------------------------------

func test_3_4_and_5_survivors_each_get_one_distinct_character() -> void:
	for n in [3, 4, 5]:
		var survivors := _survivors(n)
		var dealt := CharacterAssignment.deal_m1(survivors, CharacterDef.IDS, _rng())
		assert_array(dealt.keys()).contains_exactly_in_any_order(survivors)
		var chars := {}
		for pid: int in dealt:
			assert_bool(dealt[pid] in CharacterDef.IDS).is_true()
			chars[dealt[pid]] = true
		assert_int(chars.size()).override_failure_message("%d survivors" % n).is_equal(n)


## The caller passes survivors only; the deal names exactly them, so a 5-player round deals 4.
func test_the_shapeshifter_gets_no_character() -> void:
	var dealt := CharacterAssignment.deal_m1(_survivors(4), CharacterDef.IDS, _rng())
	assert_int(dealt.size()).is_equal(4)


## Code review 2026-10-14: each survivor gets each character about 1/5 of the time over many seeds
## (a biased shuffle fails). 5000 seeds, 1000 expected per cell; 850-1150 is about 5.3 standard
## deviations wide each side, so a fair deal never fails it.
func test_the_deal_is_uniform_over_seeds() -> void:
	var counts := {}
	for s in 5000:
		var dealt := CharacterAssignment.deal_m1(_survivors(5), CharacterDef.IDS, _rng(s))
		for pid: int in dealt:
			var key := "%d:%s" % [pid, dealt[pid]]
			counts[key] = counts.get(key, 0) + 1
	assert_int(counts.size()).is_equal(25)
	for key: String in counts:
		assert_int(counts[key]).override_failure_message("%s: %d" % [key, counts[key]]).is_between(850, 1150)


func test_fixed_seed_is_deterministic_and_a_redraw_with_a_new_seed_is_valid() -> void:
	var a := CharacterAssignment.deal_m1(_survivors(5), CharacterDef.IDS, _rng())
	assert_dict(CharacterAssignment.deal_m1(_survivors(5), CharacterDef.IDS, _rng())).is_equal(a)
	var differs := false
	for s in range(1, 20): ## a cancelled round redraws (Edge Cases): every redraw is still a valid deal
		var b := CharacterAssignment.deal_m1(_survivors(5), CharacterDef.IDS, _rng(SEED + s))
		assert_int(b.values().size()).is_equal(5)
		assert_array(b.values()).contains_exactly_in_any_order(CharacterDef.IDS)
		differs = differs or b != a
	assert_bool(differs).is_true() ## the draw depends on the seed


func test_more_survivors_than_characters_deals_nothing() -> void:
	assert_dict(CharacterAssignment.deal_m1(_survivors(6), CharacterDef.IDS, _rng())).is_empty()


# --- AC3: LobbyKnobs ------------------------------------------------------------

func _lobby() -> LobbyKnobs:
	var k := LobbyKnobs.new()
	k.min_players = 4
	k.max_players = 6
	k.lobby_countdown_s = 5.0
	k.name_min_chars = 1
	k.name_max_chars = 16
	return k


func test_shipped_lobby_knobs_load_and_validate() -> void:
	var k := Knobs.load_all()
	assert_array(k.errors()).is_empty()
	assert_int(k.lobby.min_players).is_equal(4)
	assert_int(k.lobby.max_players).is_equal(6)
	assert_float(k.lobby.lobby_countdown_s).is_equal(5.0)
	assert_int(k.lobby.name_min_chars).is_equal(1)
	assert_int(k.lobby.name_max_chars).is_equal(16)


func test_out_of_range_lobby_values_are_rejected() -> void:
	for bad: Array in [["min_players", 3], ["max_players", 7], ["lobby_countdown_s", 2.0], ["name_max_chars", KnobUnset.INT]]:
		var k := _lobby()
		k.set(bad[0], bad[1])
		assert_str(" ".join(KnobValidator.validate("lobby", k))).override_failure_message(bad[0]).contains(bad[0])


func test_min_players_above_max_players_is_rejected() -> void:
	var k := _lobby()
	assert_array(k.validate_cross()).is_empty()
	k.min_players = 6
	k.max_players = 5
	assert_str(" ".join(k.validate_cross())).contains("lobby.min_players")


func test_name_length_rule_rejects_zero_and_inverted_limits() -> void:
	var k := _lobby()
	k.name_min_chars = 0
	assert_str(" ".join(k.validate_cross())).contains("lobby.name_min_chars")
	k.name_min_chars = 17
	assert_str(" ".join(k.validate_cross())).contains("lobby.name_min_chars")
