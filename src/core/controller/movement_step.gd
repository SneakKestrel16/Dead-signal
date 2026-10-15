class_name MovementStep
## The one movement step, run by the server and by the owning client's prediction (ADR-0007 §3,
## ADR-0002 apply_move; first-person-controller.md Formulas: gait_speed, effective_speed).
## Horizontal velocity moves toward input_dir × effective_speed and reaches it in accel_time_s from
## rest; vertical velocity is gravity off the floor and zero on it; one move_and_slide. No jump.
## The only place a player's velocity is set. Floor and slide settings live on the body (PlayerBody.setup).
## Usage:
##   var state := MovementStep.MoveState.new(); state.crouched = true
##   MovementStep.step(body, frame, state, knobs)   # once per tick

## Half-angle of the sprint cone around facing: a constant by designer decision (GDD Formulas,
## sprint_cone_deg). Inputs within SPRINT_CONE_EPS_DEG beyond it still count as inside.
const SPRINT_CONE_DEG := 45.0
const SPRINT_CONE_EPS_DEG := 1e-4

enum Gait { WALK, SPRINT, CROUCH, CRAWL }


## What the gait choice reads besides the input frame. Owners: Downing (downed), story 004 (crouched:
## the body is low, including a blocked stand-up), Holds (holding), Borrowed Face (transforming, true_form).
class MoveState extends RefCounted:
	var downed := false
	var crouched := false
	var holding := false
	var transforming := false
	## True-form shapeshifter: sprint gets monster_sprint_mult.
	var true_form := false
	## The per-owner speed modifier set (story 003): lock > root > lowest slow.
	var modifiers := MovementModifiers.new()


## Gait order (GDD): crawl if Downed; crouch if crouched; walk while Holding or Transforming; sprint
## if sprint is held and the move input is within the sprint cone; walk otherwise.
static func gait(frame: InputFrame, state: MoveState) -> Gait:
	if state.downed:
		return Gait.CRAWL
	if state.crouched:
		return Gait.CROUCH
	if state.holding or state.transforming:
		return Gait.WALK
	if frame.sprint and _in_sprint_cone(frame.move):
		return Gait.SPRINT
	return Gait.WALK


## gait_speed = walk_speed × gait_mult[gait] × form_mult, in m/s.
static func gait_speed(g: Gait, state: MoveState, knobs: Knobs) -> float:
	var c := knobs.controller
	match g:
		Gait.SPRINT:
			return c.walk_speed * c.sprint_mult * (c.monster_sprint_mult if state.true_form else 1.0)
		Gait.CROUCH:
			return c.walk_speed * c.crouch_speed_mult
		Gait.CRAWL:
			return c.walk_speed * knobs.downing.crawl_speed_mult
	return c.walk_speed


## One tick for `body`: sets its velocity and calls move_and_slide().
static func step(body: CharacterBody3D, frame: InputFrame, state: MoveState, knobs: Knobs) -> void:
	var dt := 1.0 / Engine.physics_ticks_per_second
	var move := frame.move.limit_length(1.0) ## move_input is capped at 1: a diagonal is never faster
	var full := gait_speed(gait(frame, state), state, knobs)
	var speed := full * move.length() * state.modifiers.effective_scale()
	var dir := Basis(Vector3.UP, frame.yaw) * Vector3(move.x, 0.0, -move.y)
	var target := dir.normalized() * speed if speed > 0.0 else Vector3.ZERO
	var h := Vector2(body.velocity.x, body.velocity.z)
	var to := Vector2(target.x, target.z)
	var accel := knobs.controller.accel_time_s
	if accel <= 0.0 or state.modifiers.rooted or state.modifiers.locked:
		h = to ## rooted or locked "moves at 0" at once (GDD effective_speed example); no ramp
	else:
		# A fixed rate per tick: the gait's full speed (or the target, if faster) over accel_time_s, so
		# full speed is reached in accel_time_s from rest and a stop is linear. A rate taken from the
		# current speed would shrink as the body slows and never quite stop (caught by the decel test).
		h = h.move_toward(to, maxf(to.length(), full) / accel * dt)
	body.velocity.x = h.x
	body.velocity.z = h.y
	if body.is_on_floor():
		body.velocity.y = 0.0
		if body.velocity.is_zero_approx():
			return ## resting: a zero-motion move_and_slide can still shift the body inside its safe margin
	else:
		body.velocity.y += body.get_gravity().y * dt
	body.move_and_slide()


static func _in_sprint_cone(move: Vector2) -> bool:
	if move.is_zero_approx():
		return false
	return absf(rad_to_deg(atan2(move.x, move.y))) <= SPRINT_CONE_DEG + SPRINT_CONE_EPS_DEG
