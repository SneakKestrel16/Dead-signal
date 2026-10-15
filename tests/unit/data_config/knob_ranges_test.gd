# BUG-0002: every int knob and every *_alpha / *_mult float knob carries a range hint.
# Reads the shipped data/knobs/*.tres (as shipped_knobs_test does); the field list comes from the scripts.
extends GdUnitTestSuite


## True for the fields BUG-0002 requires a range on: every int, plus floats named *_alpha or *_mult.
func _needs_range(prop: Dictionary) -> bool:
	if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.usage & PROPERTY_USAGE_STORAGE):
		return false
	var field: String = prop.name
	return prop.type == TYPE_INT or (prop.type == TYPE_FLOAT and (field.ends_with("_alpha") or field.ends_with("_mult")))


## "section.field" of every field that needs a range but has no PROPERTY_HINT_RANGE.
func _unranged_fields(k: Knobs) -> Array:
	var out := []
	for name in Knobs.SECTIONS:
		for prop in (k.get(name) as Resource).get_property_list():
			if _needs_range(prop) and prop.hint != PROPERTY_HINT_RANGE:
				out.append("%s.%s" % [name, prop.name])
	return out


func test_ranges_every_int_and_alpha_mult_field_has_a_range_hint() -> void:
	assert_array(_unranged_fields(Knobs.load_all())).is_empty()


func test_ranges_shipped_knobs_load_with_no_errors() -> void:
	assert_array(Knobs.load_all().errors()).is_empty()


func test_ranges_port_zero_is_reported_by_errors() -> void:
	var k := Knobs.load_all()
	k.net.port = 0
	assert_array(k.errors()).contains(["net.port = 0 outside range [1.0, 65535.0]"])


func test_ranges_alpha_above_one_is_reported_by_errors() -> void:
	var k := Knobs.load_all()
	k.net.tick_estimate_rise_alpha = 1.5
	assert_array(k.errors()).contains(["net.tick_estimate_rise_alpha = 1.5 outside range [0.0, 1.0]"])


func test_ranges_every_ranged_field_rejects_just_outside_and_accepts_both_bounds() -> void:
	var k := Knobs.load_all()
	for name in Knobs.SECTIONS:
		var section: Resource = k.get(name)
		for prop in section.get_property_list():
			if not _needs_range(prop) or prop.hint != PROPERTY_HINT_RANGE:
				continue
			var field: String = prop.name
			var original: Variant = section.get(field)
			var bounds := KnobValidator.parse_range(prop.hint_string)
			var is_int: bool = prop.type == TYPE_INT
			for edge in [bounds.x, bounds.y]:
				section.set(field, int(edge) if is_int else edge)
				assert_str(" ".join(KnobValidator.validate(name, section))).override_failure_message(
						"%s.%s = %s at its bound should pass" % [name, field, edge]).not_contains("%s.%s" % [name, field])
			var step: Variant = 1 if is_int else 0.01
			for edge in [bounds.x - step, bounds.y + step]:
				section.set(field, edge)
				assert_str(" ".join(KnobValidator.validate(name, section))).override_failure_message(
						"%s.%s = %s outside its range should fail" % [name, field, edge]).contains("%s.%s" % [name, field])
			section.set(field, original)
