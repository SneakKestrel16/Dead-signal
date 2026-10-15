# Story scare-events/002: per-recipient scare gating, budgets and repeat block (scare-events.md rules 9-12,
# Formulas "Scare gating (per recipient)"). Values come from the shipped ScareKnobs (45/10/120 s, budget 2/6/4,
# 2 hallucinations); the expectations below are the GDD's own numbers.
extends GdUnitTestSuite

const S1 := 2
const S2 := 3
const MONSTER := 1
const BLOCKED := ScareGating.BLOCKED
const MAJOR := ScareEntry.Intensity.MAJOR
const MINOR := ScareEntry.Intensity.MINOR
const LOW := ScareEntry.Phase.LOW
const RISING := ScareEntry.Phase.RISING
const EMERGENCY := ScareEntry.Phase.EMERGENCY

var _knobs: Knobs
var _g: ScareGating


func before_test() -> void:
	_knobs = Knobs.load_all()
	_g = ScareGating.new(_knobs.scare)


func _entry(id: StringName, source: int, intensity: int, scope: int = ScareEntry.Scope.SHARED,
		once: bool = false) -> ScareEntry:
	var e := ScareEntry.new()
	e.scare_id = id
	e.source = source
	e.intensity = intensity
	e.scope = scope
	e.once_per_round = once
	return e


func _monster(id: StringName = &"door_burst") -> ScareEntry:
	return _entry(id, ScareEntry.Source.MONSTER, MAJOR)


func _script(id: StringName, intensity: int = MINOR) -> ScareEntry:
	return _entry(id, ScareEntry.Source.ROUND_SCRIPT, intensity)


## Distinct locations, so the repeat block never hides the rule under test.
func _at(i: int) -> Vector3:
	return Vector3(i, 0, 0)


func test_gdd_example_burst_blocks_recording_reduces_reveal_then_allows_glass() -> void:
	# Formulas example: burst (Monster, Major) at 3:00; RoundScript at 3:20 blocked; reveal at 3:30 as
	# Minor; RoundScript glass at 3:46 allowed (3:00 + 45 s cooldown passed, 3:30 + 10 s passed).
	assert_int(_g.gate(S1, _monster(), _at(0), 180.0, RISING)).is_equal(MAJOR)
	assert_int(_g.gate(S1, _script(&"recording"), _at(1), 200.0, RISING)).is_equal(BLOCKED)
	assert_int(_g.gate(S1, _monster(&"transformation_reveal"), _at(2), 210.0, RISING)).is_equal(MINOR)
	assert_int(_g.gate(S1, _script(&"glass_break"), _at(3), 226.0, RISING)).is_equal(MINOR)


func test_major_cooldown_blocks_round_script_and_survivor_but_only_reduces_monster() -> void:
	_g.gate(S1, _monster(), _at(0), 0.0, LOW)
	var survivor := _entry(&"alarm_fuse", ScareEntry.Source.SURVIVOR, MAJOR)
	assert_int(_g.gate(S1, _script(&"a"), _at(1), 44.9, LOW)).is_equal(BLOCKED)
	assert_int(_g.gate(S1, survivor, _at(2), 44.9, LOW)).is_equal(BLOCKED)
	assert_int(_g.gate(S1, _monster(&"ambush_lunge"), _at(3), 44.9, LOW)).is_equal(MINOR)
	# A reduced Minor does not restart the Major cooldown, but does restart the any-scare cooldown.
	assert_int(_g.gate(S1, survivor, _at(2), 45.0, LOW)).is_equal(BLOCKED)
	assert_int(_g.gate(S1, survivor, _at(2), 54.8, LOW)).is_equal(BLOCKED)
	assert_int(_g.gate(S1, survivor, _at(2), 55.0, LOW)).is_equal(MAJOR)


func test_monster_major_after_cooldown_plays_major_again() -> void:
	assert_int(_g.gate(S1, _monster(), _at(0), 0.0, LOW)).is_equal(MAJOR)
	assert_int(_g.gate(S1, _monster(), _at(1), 45.0, LOW)).is_equal(MAJOR)


func test_any_scare_cooldown_blocks_round_script_for_ten_seconds() -> void:
	assert_int(_g.gate(S1, _script(&"a"), _at(0), 0.0, RISING)).is_equal(MINOR)
	assert_int(_g.gate(S1, _script(&"b"), _at(1), 9.9, RISING)).is_equal(BLOCKED)
	assert_int(_g.gate(S1, _script(&"b"), _at(1), 10.0, RISING)).is_equal(MINOR)


func test_gating_is_per_recipient() -> void:
	assert_int(_g.gate(S1, _monster(), _at(0), 0.0, LOW)).is_equal(MAJOR)
	assert_int(_g.gate(S1, _monster(), _at(1), 1.0, LOW)).is_equal(MINOR)
	assert_int(_g.gate(S2, _monster(), _at(1), 1.0, LOW)).is_equal(MAJOR)
	assert_int(_g.gate(S2, _script(&"a"), _at(2), 1.0, LOW)).is_equal(BLOCKED)


func test_phase_budget_caps_round_script_per_client_per_phase() -> void:
	var budget := _knobs.scare.phase_budget
	for phase: int in [LOW, RISING, EMERGENCY]:
		var g := ScareGating.new(_knobs.scare)
		var t := 0.0
		for i in budget[phase]:
			assert_int(g.gate(S1, _script(&"s%d" % i), _at(i), t, phase)).is_equal(MINOR)
			t += 10.0
		assert_int(g.gate(S1, _script(&"over"), _at(99), t, phase)).is_equal(BLOCKED)
		# Survivor-source scares are not budgeted; other clients have their own budget.
		assert_int(g.gate(S1, _entry(&"alarm", ScareEntry.Source.SURVIVOR, MINOR), _at(98), t, phase)).is_equal(MINOR)
		assert_int(g.gate(S2, _script(&"over"), _at(99), t, phase)).is_equal(MINOR)


func test_phase_budget_resets_when_the_phase_changes() -> void:
	# Spend the whole Rising budget (6), then Emergency (budget 4) still allows one.
	for i in _knobs.scare.phase_budget[RISING]:
		assert_int(_g.gate(S1, _script(&"s%d" % i), _at(i), i * 10.0, RISING)).is_equal(MINOR)
	assert_int(_g.gate(S1, _script(&"c"), _at(50), 60.0, RISING)).is_equal(BLOCKED)
	assert_int(_g.gate(S1, _script(&"c"), _at(50), 60.0, EMERGENCY)).is_equal(MINOR)


func test_same_scare_at_same_location_blocked_for_120_seconds() -> void:
	assert_int(_g.gate(S1, _script(&"slammed_door"), _at(0), 0.0, RISING)).is_equal(MINOR)
	assert_int(_g.gate(S1, _script(&"slammed_door"), _at(0), 119.9, RISING)).is_equal(BLOCKED)
	assert_int(_g.gate(S1, _script(&"slammed_door"), _at(1), 119.9, RISING)).is_equal(MINOR)
	assert_int(_g.gate(S1, _script(&"slammed_door"), _at(0), 130.0, RISING)).is_equal(MINOR)


func test_once_per_round_scare_fires_once() -> void:
	var rec := _entry(&"recording", ScareEntry.Source.ROUND_SCRIPT, MINOR, ScareEntry.Scope.SHARED, true)
	assert_int(_g.gate(S1, rec, _at(0), 0.0, RISING)).is_equal(MINOR)
	assert_int(_g.gate(S1, rec, _at(1), 300.0, RISING)).is_equal(BLOCKED)


func test_at_most_two_hallucinations_per_client_per_round() -> void:
	var t := 0.0
	for i in _knobs.scare.hallucination_max_per_client:
		var h := _entry(&"h%d" % i, ScareEntry.Source.ROUND_SCRIPT, MINOR, ScareEntry.Scope.SINGLE_CLIENT)
		assert_int(_g.gate(S1, h, _at(i), t, EMERGENCY)).is_equal(MINOR)
		t += 200.0
	var last := _entry(&"hx", ScareEntry.Source.ROUND_SCRIPT, MINOR, ScareEntry.Scope.SINGLE_CLIENT)
	assert_int(_g.gate(S1, last, _at(9), t, EMERGENCY)).is_equal(BLOCKED)
	assert_int(_g.gate(S2, last, _at(9), t, EMERGENCY)).is_equal(MINOR)


func test_disguised_shapeshifter_recipient_is_gated_exactly_like_a_survivor() -> void:
	var log_s: Array[int] = []
	var log_m: Array[int] = []
	var seq: Array = [[_script(&"slammed_door"), 0.0], [_script(&"glass_break"), 5.0],
		[_monster(), 20.0], [_script(&"recording"), 30.0], [_monster(&"ambush_lunge"), 40.0],
		[_script(&"slammed_door"), 100.0], [_script(&"slammed_door"), 130.0]]
	for step: Array in seq:
		log_s.append(_g.gate(S1, step[0], Vector3.ONE, step[1], RISING))
		log_m.append(_g.gate(MONSTER, step[0], Vector3.ONE, step[1], RISING))
	assert_array(log_m).is_equal(log_s)
	assert_array(log_s).is_equal([MINOR, BLOCKED, MAJOR, BLOCKED, MINOR, BLOCKED, MINOR])


func test_fire_gates_each_recipient_and_reads_the_round_clock() -> void:
	var bus := EventBus.new(_knobs.core.max_flush_rounds)
	var registry := StateRegistry.new()
	var mf := MatchFlow.new()
	mf.setup(null, bus, registry, _knobs)
	var scares := ScareEvents.new(ScareCatalogue.load_shipped())
	scares.setup(null, bus, registry, _knobs)
	scares.fire(&"door_burst", Vector3.ZERO, [S1], ScareEntry.Source.MONSTER, MONSTER)
	scares.fire(&"door_burst", Vector3.ZERO, [S1, S2], ScareEntry.Source.MONSTER, MONSTER)
	scares.fire(&"slammed_door", Vector3.ONE, [S1, S2], ScareEntry.Source.ROUND_SCRIPT)
	bus.flush()
	var got: Array = []
	for e: ServerEvent in bus.take_tick_events():
		var s := e as EvScareTriggered
		got.append([s.scare_id, s.recipient, s.intensity])
	assert_array(got).is_equal([[&"door_burst", S1, MAJOR], [&"door_burst", S1, MINOR],
		[&"door_burst", S2, MAJOR]])
	# A new round (setup again) resets every record.
	scares.setup(null, bus, registry, _knobs)
	scares.fire(&"door_burst", Vector3.ZERO, [S1], ScareEntry.Source.MONSTER, MONSTER)
	bus.flush()
	assert_int((bus.take_tick_events()[0] as EvScareTriggered).intensity).is_equal(MAJOR)
	registry.clear()
