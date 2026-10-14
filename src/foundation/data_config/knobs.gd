class_name Knobs extends RefCounted
## Typed knob sections plus validation and unit conversion (ADR-0006).
## Plain object: the composition root creates it and injects it; never an autoload.
## Usage: `var k := Knobs.new(); k.net = net; k.defense = defense; if k.errors().is_empty(): ...`
## ponytail: file loading (`load_all`), digest and cross rules arrive in stories 002-005.

var net: NetKnobs
var defense: DefenseKnobs


## All range/unset errors across every section; [] = valid. A missing section is an error.
func errors() -> PackedStringArray:
	var errs := PackedStringArray()
	for pair in [["net", net], ["defense", defense]]:
		if pair[1] == null:
			errs.append("%s section missing" % pair[0])
		else:
			errs.append_array(KnobValidator.validate(pair[0], pair[1]))
	return errs


## Converts GDD seconds to sim ticks: roundi(seconds * net.sim_tick_hz).
## Example: 0.5 s at 60 Hz -> 30; 0.0 -> 0. Requires a valid `net` section.
func ticks(seconds: float) -> int:
	return roundi(seconds * net.sim_tick_hz)
