class_name KnobValidator
## Range and unset validation for knob sections (ADR-0006 rule 4).
## Usage: `var errs := KnobValidator.validate("defense", DefenseKnobs.new())`

## Returns one error per bad script variable of `section`; [] when valid.
## The range is read from the field's @export_range hint, so it is written once.
static func validate(section_name: String, section: Resource) -> PackedStringArray:
	var errs := PackedStringArray()
	for prop in section.get_property_list():
		# Script fields that are saved (exported); a private helper var is not a knob.
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.usage & PROPERTY_USAGE_STORAGE):
			continue
		var field: String = prop.name
		var value: Variant = section.get(field)
		var path := "%s.%s" % [section_name, field]
		if (prop.type == TYPE_FLOAT and is_nan(value)) or (prop.type == TYPE_INT and value == KnobUnset.INT):
			errs.append("%s unset" % path)
			continue
		if prop.hint != PROPERTY_HINT_RANGE:
			continue
		var bounds := parse_range(prop.hint_string)
		if value < bounds.x or value > bounds.y:
			errs.append("%s = %s outside range [%s, %s]" % [path, value, bounds.x, bounds.y])
	return errs


## Parses "min,max[,step,flags...]" into (min, max); trailing entries are ignored.
## Int fields report floats ("1.0,3.0"), so both parse with float().
static func parse_range(hint_string: String) -> Vector2:
	var parts := hint_string.split(",")
	return Vector2(float(parts[0]), float(parts[1]))
