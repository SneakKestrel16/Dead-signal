class_name ControllerKnobs extends Resource
## Controller knobs. Owning source: design/gdd/first-person-controller.md (Formulas tables, rows whose Source is 'data file'; the GDD has no Tuning Knobs table) plus values ADR-0002/0008 list.
## Defaults are unset sentinels; values come only from res://data/knobs/controller.tres. Ranges are the GDD Safe Range;
## a knob with no sourced range has a plain @export (unset is still caught). Values the GDD marks proposed ship as proposed.
## Usage: `var k := Knobs.load_all(); var v = k.controller.walk_speed`

@export_range(3.7, 4.5) var walk_speed: float = NAN
@export_range(1.15, 1.3) var sprint_mult: float = NAN
@export_range(0.4, 0.6) var crouch_speed_mult: float = NAN
@export_range(1.1, 1.2) var monster_sprint_mult: float = NAN
@export var max_survivor_sprint_mps: float = NAN
@export_range(0.1, 0.4) var hold_range_tolerance_m: float = NAN
@export var intent_timeout_ms: int = KnobUnset.INT
@export_range(0.25, 0.35) var player_radius_m: float = NAN
@export_range(12.0, 25.0) var footstep_radius_sprint_m: float = NAN
@export_range(4.0, 8.0) var footstep_radius_walk_m: float = NAN
@export_range(1.0, 3.0) var footstep_radius_crouch_m: float = NAN
@export_range(1.0, 3.0) var footstep_radius_crawl_m: float = NAN
@export_range(0.0, 0.09) var accel_time_s: float = NAN
@export_range(2.7, 3.5) var interact_ray_max_m: float = NAN
@export_range(0.2, 0.45) var step_height_m: float = NAN
## GDD `capsule_height_m` "1.8 / 1.2" (Core Rule 1, ADR-0007 §2): standing height here, crouched or
## Downed height in capsule_low_height_m (field names chosen 2026-10-14, AD-75). Height includes caps.
@export var capsule_height_m: float = NAN
@export var capsule_low_height_m: float = NAN


## Cross-knob rules within this section; [] = valid. None are named in its GDD or ADRs yet.
func validate_cross() -> PackedStringArray:
	return []
