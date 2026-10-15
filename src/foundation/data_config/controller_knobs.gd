class_name ControllerKnobs extends Resource
## Controller knobs. Owning source: design/gdd/first-person-controller.md (Formulas tables, rows whose Source is 'data file'; the GDD has no Tuning Knobs table) plus values ADR-0002/0008 list.
## Defaults are unset sentinels; values come only from res://data/knobs/controller.tres. Ranges are the GDD Safe Range;
## a knob with no sourced range has a plain @export (unset is still caught). Values the GDD marks proposed ship as proposed.
## Usage: `var k := Knobs.load_all(); var v = k.controller.walk_speed`

## Comparison epsilon for the joint sprint cap (GDD: "compared with a 1e-4 m/s epsilon").
const SPRINT_CAP_EPS := 1e-4

@export_range(3.7, 4.5) var walk_speed: float = NAN
@export_range(1.15, 1.3) var sprint_mult: float = NAN
@export_range(0.4, 0.6) var crouch_speed_mult: float = NAN
@export_range(1.1, 1.2) var monster_sprint_mult: float = NAN
## Range 3.0..10.0 m/s: inference, the GDD joint cap gives only the value 5.4; a movement playtest settles it.
@export_range(3.0, 10.0) var max_survivor_sprint_mps: float = NAN
@export_range(0.1, 0.4) var hold_range_tolerance_m: float = NAN
## Range 100..2000 ms: inference, GDD Formulas gives only the value 500 (proposed); a lag playtest settles it.
@export_range(100, 2000) var intent_timeout_ms: int = KnobUnset.INT
@export_range(0.25, 0.35) var player_radius_m: float = NAN
@export_range(12.0, 25.0) var footstep_radius_sprint_m: float = NAN
@export_range(4.0, 8.0) var footstep_radius_walk_m: float = NAN
@export_range(1.0, 3.0) var footstep_radius_crouch_m: float = NAN
@export_range(1.0, 3.0) var footstep_radius_crawl_m: float = NAN
## Distance covered per footstep event (story controller-interaction/014, Footsteps). Inference: no GDD or
## ADR gives a cadence; 0.9 m is about one step at a brisk walk (4.4 steps/s at walk, 5.6 at sprint). An
## audio playtest settles it. Bounded: below 0.5 m the reliable event channel carries too many steps.
@export_range(0.5, 2.0) var footstep_spacing_m: float = NAN
@export_range(0.0, 0.09) var accel_time_s: float = NAN
@export_range(2.7, 3.5) var interact_ray_max_m: float = NAN
@export_range(0.2, 0.45) var step_height_m: float = NAN
## GDD `capsule_height_m` "1.8 / 1.2" (Core Rule 1, ADR-0007 §2): standing height here, crouched or
## Downed height in capsule_low_height_m (field names chosen 2026-10-14, AD-75). Height includes caps.
## Ranges: inference, ADR-0007 §2 gives only 1.8 / 1.2 and the eye heights must fit inside; a level-geometry pass settles them.
@export_range(1.5, 2.2) var capsule_height_m: float = NAN
@export_range(0.9, 1.5) var capsule_low_height_m: float = NAN
## GDD `eye_height_m` "1.6 / 1.0" (Formulas, interact_ray_max): standing here, crouched in
## eye_low_height_m (named like capsule_low_height_m, AD-75). Read by the ray-reach load check (story 005).
@export_range(1.5, 1.7) var eye_height_m: float = NAN
@export_range(0.9, 1.1) var eye_low_height_m: float = NAN
## ADR-0007 §3 fixed floor settings, "all from data" (controller story 002). floor_max_angle 40.0 blocks
## 41° (the engine accepts about 0.5° above it, Verification 9); snap 0.4 is above the 0.35 m step.
## safe_margin, max_slides, wall_min_slide_angle are the 4.7.2 defaults (Verification 2), set explicitly.
## Ranges: inference, ADR-0007 §3 gives only the values 40 / 0.4 / 0.001 / 6 / 15; a movement playtest settles them.
## Angles are bounded by definition (a floor angle above 90 degrees is a ceiling).
@export_range(0.0, 89.0) var floor_max_angle_deg: float = NAN
@export_range(0.0, 1.0) var floor_snap_length_m: float = NAN
@export_range(0.0001, 0.1) var safe_margin_m: float = NAN
@export_range(1, 16) var max_slides: int = KnobUnset.INT
@export_range(0.0, 90.0) var wall_min_slide_angle_deg: float = NAN
## Interaction pick radius: how far an interactable's point may sit from the view ray and still be a
## candidate (ADR-0007 §10 "a point and radius"; controller story 007). Inference: no GDD or ADR number;
## 0.5 m is half a door's width. The level designer or a playtest settles it.
@export_range(0.05, 1.0) var interact_pick_radius_m: float = NAN


## Cross-knob rules within this section; [] = valid. None are named in its GDD or ADRs yet.
func validate_cross() -> PackedStringArray:
	var errs := PackedStringArray()
	# Source: first-person-controller.md Formulas, Gait speed joint cap (designer decision 2026-10-12):
	# survivor sprint walk_speed x sprint_mult must stay <= max_survivor_sprint_mps (1e-4 m/s epsilon),
	# and true-form sprint must exceed survivor sprint (monster_sprint_mult > 1).
	var v_s := walk_speed * sprint_mult
	if v_s > max_survivor_sprint_mps + SPRINT_CAP_EPS:
		errs.append("joint sprint cap: controller.walk_speed x sprint_mult (%.4f m/s) must be <= controller.max_survivor_sprint_mps (%s) (first-person-controller.md Gait speed joint cap)" % [v_s, max_survivor_sprint_mps])
	# Source: first-person-controller.md Gait speed joint cap: true-form sprint must exceed survivor sprint.
	if monster_sprint_mult <= 1.0:
		errs.append("joint sprint cap: controller.monster_sprint_mult (%s) must be above 1, or true form is not faster (first-person-controller.md Gait speed joint cap)" % monster_sprint_mult)
	return errs
