class_name ScareKnobs extends Resource
## Scare knobs. Owning source: design/gdd/scare-events.md.
## Defaults are unset sentinels; values come only from res://data/knobs/scare.tres. Ranges are the GDD Safe Range;
## a knob with no sourced range has a plain @export (unset is still caught). Values the GDD marks proposed ship as proposed.
## Usage: `var k := Knobs.load_all(); var v = k.scare.major_scare_cooldown_s`

@export_range(30.0, 90.0) var major_scare_cooldown_s: float = NAN
@export_range(5.0, 20.0) var minor_scare_cooldown_s: float = NAN
@export_range(60.0, 540.0) var same_scare_repeat_block_s: float = NAN
## Low/Rising/Emergency; GDD range 0..12 each, not enforced (array knob).
@export var phase_budget: PackedInt32Array = PackedInt32Array()
@export_range(0.0, 0.5) var scare_max_control_loss_s: float = NAN
@export var flinch_max_angle_deg: float = NAN
@export_range(0, 4) var hallucination_max_per_client: int = KnobUnset.INT
@export_range(0.0, 9.0) var stinger_max_db_rel: float = NAN
@export_range(1.0, 10.0) var ambush_unseen_s: float = NAN
@export_range(-18.0, -3.0) var duck_db: float = NAN
@export_range(0.02, 0.2) var duck_attack_s: float = NAN
@export_range(0.2, 2.0) var duck_release_s: float = NAN
@export_range(16, 32) var sfx_pool_size: int = KnobUnset.INT
@export_range(600, 4000) var occlusion_lowpass_hz: int = KnobUnset.INT
@export_range(-15.0, 0.0) var occlusion_db: float = NAN
@export_range(0.1, 1.0) var occlusion_recheck_s: float = NAN
@export_range(0.1, 0.5) var occlusion_floor_lift_m: float = NAN


## Cross-knob rules arrive in story data-config/003; none yet.
func validate_cross() -> PackedStringArray:
	return []
