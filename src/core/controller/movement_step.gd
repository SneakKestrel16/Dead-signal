class_name MovementStep
## The one movement step, run by the server and by the owning client's prediction (ADR-0007 §3,
## ADR-0002 apply_move; first-person-controller.md Formulas: gait_speed, effective_speed).
## Horizontal velocity moves toward input_dir × effective_speed and reaches it in accel_time_s from
## rest; vertical velocity is gravity off the floor and zero on it; one move_and_slide. No jump.
## MovementModifiers.turn_cap clamps the frame's yaw; a Lunge dash (dash_speed) replaces all of the
## above with one move_and_collide along the facing.
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
	## The hold roots its actor (Interactable.roots_actor, HoldService.hold_of().roots): speed 0.
	var hold_roots := false
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


## The posture `body` should take this tick: the crouch input, except while Holding, when crouch is
## ignored and the posture stays as it is (ADR-0008 §7). The caller passes it to PlayerBody.set_low.
static func wants_low(frame: InputFrame, state: MoveState, low_now: bool) -> bool:
	return low_now if state.holding else frame.crouch


## One tick for `body`: sets its velocity and calls move_and_slide().
static func step(body: CharacterBody3D, frame: InputFrame, state: MoveState, knobs: Knobs) -> void:
	var dt := 1.0 / Engine.physics_ticks_per_second
	var mods := state.modifiers
	# Turn cap (monster-abilities.md rules 5-6): the frame is the server's copy, so clamping it here is
	# what ViewState, the snapshot and the dash all read.
	if mods.turn_cap < INF and is_finite(mods.facing):
		var turn := mods.turn_cap * dt
		frame.yaw = wrapf(mods.facing + clampf(angle_difference(mods.facing, frame.yaw), -turn, turn), -PI, PI)
	mods.facing = frame.yaw
	if mods.dash_speed > 0.0 and not (mods.rooted or mods.locked):
		_dash(body, frame.yaw, mods, dt)
		return
	var move := frame.move.limit_length(1.0) ## move_input is capped at 1: a diagonal is never faster
	var full := gait_speed(gait(frame, state), state, knobs)
	var rooted := state.modifiers.rooted or state.modifiers.locked or (state.holding and state.hold_roots)
	var speed := 0.0 if rooted else full * move.length() * state.modifiers.effective_scale()
	var dir := Basis(Vector3.UP, frame.yaw) * Vector3(move.x, 0.0, -move.y)
	var target := dir.normalized() * speed if speed > 0.0 else Vector3.ZERO
	var h := Vector2(body.velocity.x, body.velocity.z)
	var to := Vector2(target.x, target.z)
	var accel := knobs.controller.accel_time_s
	if accel <= 0.0 or rooted:
		h = to ## rooted, locked or a rooting hold "moves at 0" at once (GDD effective_speed example); no ramp
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


## The Lunge dash: dash_speed along `yaw`, stopping at the first body on the body's mask (walls, glass,
## door blockers, other players: monster-abilities.md rule 6). Once blocked it stays put until the
## owner removes the dash. ponytail: no gravity or slide during the 0.3 s dash, so a ramp or step on the
## path also stops it; add a floor-following sweep if level design puts slopes in lunge range.
static func _dash(body: CharacterBody3D, yaw: float, mods: MovementModifiers, dt: float) -> void:
	body.velocity = Vector3.ZERO
	if mods.dash_blocked:
		return
	var v := Basis(Vector3.UP, yaw) * Vector3.FORWARD * mods.dash_speed
	if body.move_and_collide(v * dt) != null:
		mods.dash_blocked = true
	else:
		body.velocity = v


static func _in_sprint_cone(move: Vector2) -> bool:
	if move.is_zero_approx():
		return false
	return absf(rad_to_deg(atan2(move.x, move.y))) <= SPRINT_CONE_DEG + SPRINT_CONE_EPS_DEG
