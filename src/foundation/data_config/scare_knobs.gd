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


## Phase count of phase_budget: Low, Rising, Emergency (scare-events.md Formulas).
const PHASES := 3
## Per-phase budget range (scare-events.md Tuning Knobs: 0-12 each).
const PHASE_BUDGET_MAX := 12


## Cross-knob rules within this section; [] = valid. Knobs.errors() runs it only when every field is set.
func validate_cross() -> PackedStringArray:
	var errs := PackedStringArray()
	# Source: scare-events.md Formulas and Tuning Knobs: one budget per phase (Low/Rising/Emergency),
	# each 0-12. The array knob has no @export_range, so its size and range are checked here.
	if phase_budget.size() != PHASES:
		errs.append("scare.phase_budget has %d entries, needs %d (Low/Rising/Emergency, scare-events.md)" % [phase_budget.size(), PHASES])
	# Source: scare-events.md Tuning Knobs: phase_budget "0-12 each".
	for i in phase_budget.size():
		if phase_budget[i] < 0 or phase_budget[i] > PHASE_BUDGET_MAX:
			errs.append("scare.phase_budget[%d] = %d outside range [0, %d] (scare-events.md)" % [i, phase_budget[i], PHASE_BUDGET_MAX])
	return errs
