class_name PingKnobs extends Resource
## Ping knobs. Owning source: design/gdd/pings-and-callouts.md.
## Defaults are unset sentinels; values come only from res://data/knobs/ping.tres. Ranges are the GDD Safe Range;
## a knob with no sourced range has a plain @export (unset is still caught). Values the GDD marks proposed ship as proposed.
## Usage: `var k := Knobs.load_all(); var v = k.ping.ping_lifetime_s`

@export_range(4.0, 15.0) var ping_lifetime_s: float = NAN
@export_range(20.0, 60.0) var ping_max_range_m: float = NAN
@export_range(1, 4) var ping_max_active: int = KnobUnset.INT
@export_range(2, 5) var ping_bucket_size: int = KnobUnset.INT
@export_range(1.0, 4.0) var ping_refill_s: float = NAN
@export_range(2.0, 6.0) var callout_global_cooldown_s: float = NAN
@export_range(5.0, 15.0) var callout_repeat_block_s: float = NAN
@export_range(15.0, 40.0) var callout_range_m: float = NAN
@export_range(25.0, 60.0) var rescue_callout_range_m: float = NAN
@export_range(10.0, 35.0) var voice_range_m: float = NAN


## Cross-knob rules within this section; [] = valid. None are named in its GDD or ADRs yet.
func validate_cross() -> PackedStringArray:
	return []
