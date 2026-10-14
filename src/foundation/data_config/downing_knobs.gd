class_name DowningKnobs extends Resource
## Downing knobs. Owning source: design/gdd/downing-and-rescue.md.
## Defaults are unset sentinels; values come only from res://data/knobs/downing.tres. Ranges are the GDD Safe Range;
## a knob with no sourced range has a plain @export (unset is still caught). Values the GDD marks proposed ship as proposed.
## Usage: `var k := Knobs.load_all(); var v = k.downing.downs_to_eliminate`

@export_range(2, 2) var downs_to_eliminate: int = KnobUnset.INT
@export_range(4.0, 8.0) var rescue_duration_s: float = NAN
@export_range(0.8, 2.5) var takedown_commit_s: float = NAN
@export_range(1.0, 4.0) var post_release_grace_s: float = NAN
@export_range(1.0, 5.0) var post_rescue_grace_s: float = NAN
@export_range(0.0, 1.0) var rescue_decay_rate: float = NAN
@export_range(1.0, 2.5) var rescue_range_m: float = NAN
@export_range(0.15, 0.4) var crawl_speed_mult: float = NAN
@export_range(30.0, 120.0) var bleedout_s: float = NAN
@export_range(5.0, 20.0) var camp_slow_radius_m: float = NAN
@export_range(0.0, 0.5) var camp_slow_mult: float = NAN


## Cross-knob rules within this section; [] = valid. None are named in its GDD or ADRs yet.
func validate_cross() -> PackedStringArray:
	return []
