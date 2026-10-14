class_name CoreKnobs extends Resource
## Core knobs. Owning source: ADR-0005/0008 (no GDD); hold_range_tolerance_m and interact_ray_max_m live in ControllerKnobs.
## Defaults are unset sentinels; values come only from res://data/knobs/core.tres. Ranges are the GDD Safe Range;
## a knob with no sourced range has a plain @export (unset is still caught). Values the GDD marks proposed ship as proposed.
## Usage: `var k := Knobs.load_all(); var v = k.core.max_flush_rounds`

@export var max_flush_rounds: int = KnobUnset.INT


## Cross-knob rules within this section; [] = valid. None are named in its GDD or ADRs yet.
func validate_cross() -> PackedStringArray:
	return []
