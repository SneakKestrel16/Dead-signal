class_name FacilityKnobs extends Resource
## Facility knobs. Owning source: ADR-0009/0010/0015 (no GDD).
## Defaults are unset sentinels; values come only from res://data/knobs/facility.tres. Ranges are the GDD Safe Range;
## a knob with no sourced range has a plain @export (unset is still caught). Values the GDD marks proposed ship as proposed.
## Usage: `var k := Knobs.load_all(); var v = k.facility.max_flashes_per_s`
## NOT SOURCEABLE (no number in ADR-0009/0010): light_fade_s, max_shadowed_omni, max_shadowed_spot,
## max_shadowed_flashlights, feed_resolution (set by the ADR-0009 spike). Add each when its number is decided.

## Range 0..3: scare-events.md rule 25 caps luminance flashes at 3 per second (proposed); 0 disables flashes.
@export_range(0, 3) var max_flashes_per_s: int = KnobUnset.INT


## Cross-knob rules within this section; [] = valid. None are named in its GDD or ADRs yet.
func validate_cross() -> PackedStringArray:
	return []
