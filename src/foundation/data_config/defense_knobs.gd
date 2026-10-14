class_name DefenseKnobs extends Resource
## Defense knobs. Owning source: design/gdd/survivor-defense.md.
## Defaults are unset sentinels; values come only from res://data/knobs/defense.tres. Ranges are the GDD Safe Range;
## a knob with no sourced range has a plain @export (unset is still caught). Values the GDD marks proposed ship as proposed.
## Usage: `var k := Knobs.load_all(); var v = k.defense.stun_item_charges`

@export_range(1, 3) var stun_item_charges: int = KnobUnset.INT
@export_range(1.0, 3.0) var stun_duration_s: float = NAN
@export_range(0.5, 2.0) var stun_root_s: float = NAN
@export_range(0.3, 0.8) var stun_slow_mult: float = NAN
@export_range(0.5, 2.0) var stun_item_reuse_s: float = NAN
@export_range(4.0, 10.0) var stun_immunity_s: float = NAN
@export_range(3.0, 7.0) var stun_range_m: float = NAN
@export_range(0.0, 20.0) var stun_aim_tolerance_deg: float = NAN
@export_range(0.0, 0.5) var stun_use_delay_s: float = NAN
@export_range(0.5, 2.0) var hide_transition_s: float = NAN
@export_range(4.0, 15.0) var hide_noise_radius_m: float = NAN
@export_range(10.0, 40.0) var hide_quiet_s: float = NAN
@export_range(3.0, 10.0) var hide_cue_interval_s: float = NAN
@export_range(0.5, 3.0) var search_duration_s: float = NAN
@export_range(2.0, 5.0) var barricade_duration_s: float = NAN
@export_range(0.5, 2.0) var barricade_remove_s: float = NAN
@export_range(3.0, 10.0) var barricade_break_s: float = NAN
@export_range(15.0, 60.0) var rebarricade_lockout_s: float = NAN


## Cross-knob rules arrive in story data-config/003; none yet.
func validate_cross() -> PackedStringArray:
	return []
