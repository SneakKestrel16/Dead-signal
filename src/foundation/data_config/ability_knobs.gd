class_name AbilityKnobs extends Resource
## Ability knobs. Owning source: design/gdd/monster-abilities.md.
## Defaults are unset sentinels; values come only from res://data/knobs/ability.tres. Ranges are the GDD Safe Range;
## a knob with no sourced range has a plain @export (unset is still caught). Values the GDD marks proposed ship as proposed.
## Usage: `var k := Knobs.load_all(); var v = k.ability.lunge_cooldown_s`

@export_range(6.0, 20.0) var lunge_cooldown_s: float = NAN
@export_range(0.4, 1.0) var lunge_windup_s: float = NAN
@export_range(0.0, 17.0) var lunge_windup_turn_deg_s: float = NAN
@export_range(2.0, 6.0) var lunge_distance_m: float = NAN
@export_range(0.2, 0.5) var lunge_dash_s: float = NAN
@export_range(0.0, 30.0) var lunge_dash_turn_deg_s: float = NAN
@export_range(15.0, 30.0) var lunge_cue_radius_m: float = NAN
@export_range(0.8, 1.25) var lunge_hit_radius_m: float = NAN
@export_range(40.0, 69.0) var lunge_cone_deg: float = NAN
@export_range(0.3, 0.8) var miss_slow_multiplier: float = NAN
@export_range(0.5, 3.0) var miss_slow_s: float = NAN
## Lunge hit-stop, seconds (monster-abilities.md Impact Moments: 80 ms, "Configurable? Yes"; story 007).
## Presentation only. No Safe Range in the GDD, so a plain export.
@export var lunge_hit_stop_s: float = NAN
@export_range(0, 250) var max_rewind_ms: int = KnobUnset.INT
@export_range(15.0, 60.0) var false_signal_cooldown_s: float = NAN
@export_range(10.0, 30.0) var false_signal_range_m: float = NAN
@export_range(2.0, 5.0) var false_signal_footstep_duration_s: float = NAN
@export_range(3.0, 10.0) var blackout_duration_s: float = NAN
@export_range(8.0, 25.0) var blackout_range_m: float = NAN
@export_range(30.0, 90.0) var blackout_cooldown_s: float = NAN
@export_range(0.5, 3.0) var backup_switch_hold_s: float = NAN
@export_range(1.5, 2.3) var backup_switch_range_m: float = NAN


## Cross-knob rules within this section; [] = valid. None are named in its GDD or ADRs yet.
func validate_cross() -> PackedStringArray:
	return []
