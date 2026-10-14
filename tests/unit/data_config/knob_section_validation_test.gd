# Story data-config/001: knob section range + unset validation, Knobs.ticks.
extends GdUnitTestSuite

## Inner section with a trailing flag in its hint, to prove only min,max are used.
class OrGreaterSection extends Resource:
	@export_range(1.0, 4.0, 0.1, "or_greater") var x: float = NAN


## Inner section with a non-exported helper var, which is not a knob.
class PrivateVarSection extends Resource:
	@export_range(0.0, 1.0) var a: float = NAN
	var _cache: float = NAN


## Inner section with three fields, so three bad fields sit in one section.
class ThreeFieldSection extends Resource:
	@export_range(0.0, 1.0) var a: float = NAN
	@export_range(1, 5) var b: int = KnobUnset.INT
	@export_range(0.0, 1.0) var c: float = NAN


func _valid_defense() -> DefenseKnobs:
	var d := DefenseKnobs.new()
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


func test_knobs_errors_collects_across_sections() -> void:
	var k := Knobs.new()
	k.net = NetKnobs.new() # sim_tick_hz unset: 1 error
	var d := DefenseKnobs.new()
	d.stun_duration_s = 9.0 # out of range: 1 error; charges unset: 1 error
	k.defense = d
	assert_array(k.errors()).contains_exactly([
		"net.sim_tick_hz unset",
		"defense.stun_duration_s = 9.0 outside range [1.0, 3.0]",
		"defense.stun_item_charges unset"])


func test_knobs_errors_missing_sections_reports_each() -> void:
	assert_array(Knobs.new().errors()).contains_exactly(
			["net section missing", "defense section missing"])


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


func test_ticks_zero_seconds_returns_zero() -> void:
	var k := Knobs.new()
	k.net = NetKnobs.new()
	k.net.sim_tick_hz = 60
	assert_int(k.ticks(0.0)).is_equal(0)
