# Story data-config/001: knob section range + unset validation, Knobs.ticks.
extends GdUnitTestSuite

## Inner section with a trailing flag in its hint, to prove only min,max are used.
class OrGreaterSection extends Resource:
	@export_range(1.0, 4.0, 0.1, "or_greater") var x: float = NAN


## Inner section with a non-exported helper var, which is not a knob.
class PrivateVarSection extends Resource:
	@export_range(0.0, 1.0) var a: float = NAN
	var _cache: float = NAN


## Inner section with an int-array knob, unset when empty.
class ArraySection extends Resource:
	@export var budget: PackedInt32Array = PackedInt32Array()


## Inner section with three fields, so three bad fields sit in one section.
class ThreeFieldSection extends Resource:
	@export_range(0.0, 1.0) var a: float = NAN
	@export_range(1, 5) var b: int = KnobUnset.INT
	@export_range(0.0, 1.0) var c: float = NAN


## Valid DefenseKnobs without file I/O: every ranged field at its range minimum,
## then the two fields these tests reason about at known values.
func _valid_defense() -> DefenseKnobs:
	var d := DefenseKnobs.new()
	for prop in d.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.hint == PROPERTY_HINT_RANGE:
			var lo := KnobValidator.parse_range(prop.hint_string).x
			d.set(prop.name, int(lo) if prop.type == TYPE_INT else lo)
	d.stun_duration_s = 2.0
	d.stun_item_charges = 2
	return d


func test_validate_all_fields_in_range_returns_no_errors() -> void:
	assert_array(KnobValidator.validate("defense", _valid_defense())).is_empty()


func test_validate_nan_float_reports_named_unset_error() -> void:
	var d := _valid_defense()
	d.stun_duration_s = NAN
	assert_array(KnobValidator.validate("defense", d)).contains_exactly(["defense.stun_duration_s unset"])


func test_validate_unset_int_reports_named_unset_error() -> void:
	var d := _valid_defense()
	d.stun_item_charges = KnobUnset.INT
	assert_array(KnobValidator.validate("defense", d)).contains_exactly(["defense.stun_item_charges unset"])


func test_validate_value_below_min_reports_value_and_range() -> void:
	var d := _valid_defense()
	d.stun_duration_s = 0.5
	assert_array(KnobValidator.validate("defense", d)).contains_exactly(
			["defense.stun_duration_s = 0.5 outside range [1.0, 3.0]"])


func test_validate_value_above_max_reports_value_and_range() -> void:
	var d := _valid_defense()
	d.stun_item_charges = 4
	assert_array(KnobValidator.validate("defense", d)).contains_exactly(
			["defense.stun_item_charges = 4 outside range [1.0, 3.0]"])


func test_validate_values_exactly_at_min_and_max_are_valid() -> void:
	var d := _valid_defense()
	d.stun_duration_s = 1.0
	d.stun_item_charges = 3
	assert_array(KnobValidator.validate("defense", d)).is_empty()
	d.stun_duration_s = 3.0
	d.stun_item_charges = 1
	assert_array(KnobValidator.validate("defense", d)).is_empty()


func test_validate_three_bad_fields_in_one_section_reports_three_errors() -> void:
	var s := ThreeFieldSection.new()
	s.a = NAN # unset
	s.b = KnobUnset.INT # unset
	s.c = 9.0 # above max
	assert_array(KnobValidator.validate("three", s)).contains_exactly([
		"three.a unset", "three.b unset", "three.c = 9.0 outside range [0.0, 1.0]"])


## Sections the two-section tests below do not set, in Knobs.SECTIONS order.
func _missing_except_defense_net() -> Array:
	var out := []
	for name in Knobs.SECTIONS:
		if name != "defense" and name != "net":
			out.append("%s section missing" % name)
	return out


func test_knobs_errors_collects_across_sections() -> void:
	var k := Knobs.new()
	k.net = NetKnobs.new() # sim_tick_hz and the other net fields unset
	var d := DefenseKnobs.new()
	d.stun_duration_s = 9.0 # out of range: 1 error; every other defense field unset
	k.defense = d
	var errs := k.errors()
	assert_array(errs).contains(["defense.stun_duration_s = 9.0 outside range [1.0, 3.0]",
			"defense.stun_item_charges unset", "net.sim_tick_hz unset"])
	assert_array(errs).contains(_missing_except_defense_net())


func test_knobs_errors_missing_sections_reports_each() -> void:
	var expected := []
	for name in Knobs.SECTIONS:
		expected.append("%s section missing" % name)
	assert_array(Knobs.new().errors()).contains_exactly(expected)


func test_validate_private_non_exported_var_is_ignored() -> void:
	var s := PrivateVarSection.new()
	s.a = 0.5
	assert_array(KnobValidator.validate("private", s)).is_empty()


func test_parse_range_int_hint_reported_as_floats_parses() -> void:
	assert_vector(KnobValidator.parse_range("1.0,3.0")).is_equal(Vector2(1.0, 3.0))


func test_parse_range_trailing_or_greater_flag_ignored() -> void:
	var hint := ""
	for prop in OrGreaterSection.new().get_property_list():
		if prop.name == "x":
			hint = prop.hint_string
	assert_str(hint).contains("or_greater")
	assert_vector(KnobValidator.parse_range(hint)).is_equal(Vector2(1.0, 4.0))


func test_ticks_half_second_at_60hz_returns_30() -> void:
	var k := Knobs.new()
	k.net = NetKnobs.new()
	k.net.sim_tick_hz = 60
	assert_int(k.ticks(0.5)).is_equal(30)


## SR-1 review 2026-10-14: 0.5 s at 60 Hz is exactly 30, so truncation passed too; 1.5 ticks
## tells roundi from int().
func test_ticks_rounds_half_a_tick_up_not_down() -> void:
	var k := Knobs.new()
	k.net = NetKnobs.new()
	k.net.sim_tick_hz = 60
	assert_int(k.ticks(0.025)).is_equal(2)


func test_ticks_zero_seconds_returns_zero() -> void:
	var k := Knobs.new()
	k.net = NetKnobs.new()
	k.net.sim_tick_hz = 60
	assert_int(k.ticks(0.0)).is_equal(0)


func test_validate_empty_int_array_reports_unset() -> void:
	assert_array(KnobValidator.validate("arr", ArraySection.new())).contains_exactly(["arr.budget unset"])


func test_validate_filled_int_array_is_valid() -> void:
	var s := ArraySection.new()
	s.budget = PackedInt32Array([2, 6, 4])
	assert_array(KnobValidator.validate("arr", s)).is_empty()


## SR-1 review 2026-10-14: max_flush_rounds had no range, so 0 passed and every flush overflowed on
## its first round, delivering no event at all.
func test_max_flush_rounds_zero_is_rejected() -> void:
	var k := CoreKnobs.new()
	k.max_flush_rounds = 0
	assert_str(" ".join(KnobValidator.validate("core", k))).contains("core.max_flush_rounds")
	k.max_flush_rounds = 8
	assert_array(KnobValidator.validate("core", k)).is_empty()


## SR-1 review 2026-10-14: a float knob with no range hint skipped every check but unset, so
## INF (e.g. net.starvation_window_s) loaded clean. Non-finite floats are now rejected everywhere.
func test_infinite_float_without_a_range_is_rejected() -> void:
	var k := Knobs.load_all()
	k.net.starvation_window_s = INF
	assert_str(" ".join(KnobValidator.validate("net", k.net))).contains("net.starvation_window_s")
