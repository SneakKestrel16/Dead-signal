class_name TestControllerKnobs extends RefCounted
## Fixture for the controller load-time checks (controller story 005): sets, on a Knobs built from
## .new() sections, every field those rules read, at the shipped values (data/knobs/*.tres). Each test
## then moves one value. Creates a missing controller, ability, objectives or downing section.

const WALK := 4.0
const SPRINT_MULT := 1.25
const SPRINT_CAP := 5.4
const MONSTER_MULT := 1.15
const RADIUS := 0.3
const RAY_MAX := 3.0
const EYE := 1.6
const EYE_LOW := 1.0
const CAPSULE := 1.8
const CAPSULE_LOW := 1.2
const LUNGE_DISTANCE := 4.0
const LUNGE_HIT_RADIUS := 1.2
const LUNGE_WINDUP := 0.6
const LUNGE_DASH := 0.3
const INTERACT_RANGE := 2.0
const RESCUE_RANGE := 1.5
const SWITCH_RANGE := 2.0


static func set_shipped(k: Knobs) -> void:
	if k.controller == null:
		k.controller = ControllerKnobs.new()
	if k.ability == null:
		k.ability = AbilityKnobs.new()
	if k.objectives == null:
		k.objectives = ObjectivesKnobs.new()
	if k.downing == null:
		k.downing = DowningKnobs.new()
	var c := k.controller
	c.walk_speed = WALK
	c.sprint_mult = SPRINT_MULT
	c.max_survivor_sprint_mps = SPRINT_CAP
	c.monster_sprint_mult = MONSTER_MULT
	c.player_radius_m = RADIUS
	c.interact_ray_max_m = RAY_MAX
	c.eye_height_m = EYE
	c.eye_low_height_m = EYE_LOW
	c.capsule_height_m = CAPSULE
	c.capsule_low_height_m = CAPSULE_LOW
	k.ability.lunge_distance_m = LUNGE_DISTANCE
	k.ability.lunge_hit_radius_m = LUNGE_HIT_RADIUS
	k.ability.lunge_windup_s = LUNGE_WINDUP
	k.ability.lunge_dash_s = LUNGE_DASH
	k.ability.backup_switch_range_m = SWITCH_RANGE
	k.objectives.interact_range_m = INTERACT_RANGE
	k.downing.rescue_range_m = RESCUE_RANGE
