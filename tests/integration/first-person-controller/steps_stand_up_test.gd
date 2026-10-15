# Story controller-interaction/004: steps, slopes and the stand-up check (first-person-controller.md
# Body and gaits, Edge Cases; ADR-0007 §2-4, §6a). Integration: real Jolt bodies (PlayerBody) moved by
# the real MovementStep inside the physics frame, over geometry built here with large box floors.
# AC4 (no jump action in the InputMap) is view_direction_test.gd
# test_input_map_holds_exactly_the_eleven_actions_and_no_jump (story 005).
extends GdUnitTestSuite

## Walking forward (-Z) for this long covers every course below at walk speed.
const WALK_TICKS := 240
## Step and slope courses start this far ahead of the body.
const FACE_Z := -3.0
const LOW_CEILING_Y := 1.5 ## above the 1.2 m low capsule, below the 1.8 m standing one
const CEILING_END_Z := -5.0

var _knobs: Knobs
var _world: Node3D


func before_test() -> void:
	_knobs = Knobs.load_all()
	_world = Node3D.new()
	add_child(_world)
	_box(Vector3(0, -0.5, -30), Vector3(10, 1, 80)) ## floor


func after_test() -> void:
	_world.free()


func _box(center: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = PhysicsLayers.WORLD
	b.collision_mask = PhysicsLayers.NONE
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	(cs.shape as BoxShape3D).size = size
	b.add_child(cs)
	_world.add_child(b)
	b.global_position = center


## A wedge rising toward -Z from `z_low` (floor level) to `height` at angle `deg`; returns its far z.
func _wedge(z_low: float, deg: float, height: float) -> float:
	var depth := height / tan(deg_to_rad(deg))
	var b := StaticBody3D.new()
	b.collision_layer = PhysicsLayers.WORLD
	b.collision_mask = PhysicsLayers.NONE
	var cs := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	var z_high := z_low - depth
	shape.points = PackedVector3Array([
		Vector3(-2, 0, z_low), Vector3(2, 0, z_low), Vector3(-2, 0, z_high), Vector3(2, 0, z_high),
		Vector3(-2, height, z_high), Vector3(2, height, z_high)])
	cs.shape = shape
	b.add_child(cs)
	_world.add_child(b)
	return z_high


## A step of `height` whose face is at FACE_Z, 40 m deep (longer than the walk), with a ramp collider
## at `ramp_deg` ending at the face (0 = no ramp).
func _step(height: float, ramp_deg: float) -> void:
	_box(Vector3(0, height / 2.0, FACE_Z - 20.0), Vector3(4, height, 40))
	if ramp_deg > 0.0:
		_wedge(FACE_Z + height / tan(deg_to_rad(ramp_deg)), ramp_deg, height)


## A ramp at `deg` starting at FACE_Z, rising 1.5 m, then a plateau at that height.
func _ramp(deg: float) -> void:
	var top := _wedge(FACE_Z, deg, 1.5)
	_box(Vector3(0, 0.75, top - 20.0), Vector3(4, 1.5, 40))


func _body(pos: Vector3) -> PlayerBody:
	var b := PlayerBody.new()
	b.setup(_knobs, PhysicsLayers.MOVE_SERVER)
	_world.add_child(b)
	b.global_position = pos
	return b


func _forward() -> InputFrame:
	var f := InputFrame.new()
	f.move = Vector2(0, 1)
	return f


## Walks `b` forward for `ticks` physics frames with the real MovementStep; returns the highest y.
func _walk(b: PlayerBody, ticks: int) -> float:
	await get_tree().physics_frame
	await get_tree().physics_frame ## in the broadphase before the first step
	var state := MovementStep.MoveState.new()
	var top := b.global_position.y
	for t in ticks:
		await get_tree().physics_frame
		MovementStep.step(b, _forward(), state, _knobs)
		top = maxf(top, b.global_position.y)
	return top


# --- AC1: steps and slopes -------------------------------------------------------------

## Climbs the step: past its face and standing on its top.
func _climbs(height: float, ramp_deg: float) -> void:
	_step(height, ramp_deg)
	var b := _body(Vector3.ZERO)
	await _walk(b, WALK_TICKS)
	assert_float(b.global_position.z).is_less(FACE_Z - 2.0)
	assert_float(b.global_position.y).is_equal_approx(height, 0.05)


## ADR-0007 §4: step ramp colliders are no steeper than 40°; each step is climbed at 35° and at 40°.
func test_a_018_step_with_a_35_degree_ramp_is_climbed() -> void:
	await _climbs(0.18, 35.0)


func test_a_018_step_with_a_40_degree_ramp_is_climbed() -> void:
	await _climbs(0.18, 40.0)


func test_a_035_step_with_a_35_degree_ramp_is_climbed() -> void:
	await _climbs(0.35, 35.0)


func test_a_035_step_with_a_40_degree_ramp_is_climbed() -> void:
	await _climbs(0.35, 40.0)


func test_a_040_step_blocks() -> void:
	_step(0.40, 0.0) ## ADR-0007 §4: ramp colliders only for steps up to 0.35 m
	var b := _body(Vector3.ZERO)
	var top := await _walk(b, WALK_TICKS)
	assert_float(b.global_position.z).is_greater(FACE_Z) ## stopped at the face
	assert_float(top).is_less(0.05) ## never stepped up: no step-up code


func test_a_40_degree_ramp_is_climbed() -> void:
	_ramp(40.0)
	var b := _body(Vector3.ZERO)
	await _walk(b, WALK_TICKS)
	assert_float(b.global_position.y).is_equal_approx(1.5, 0.05)


func test_a_41_degree_ramp_blocks() -> void:
	_ramp(41.0)
	var b := _body(Vector3.ZERO)
	var top := await _walk(b, WALK_TICKS)
	assert_float(top).is_less(0.3) ## a wall: floor_max_angle 40 lets about 40.5 climb (verification 9)


# --- AC2: crouched under a low ceiling ----------------------------------------------------

## Crouch held, then released under a 1.5 m ceiling that ends at CEILING_END_Z. Each tick the body asks
## to stand (set_low with the crouch input) before it moves. It stays at 1.2 m while any of the standing
## capsule would be under the ceiling, and stands on the tick after it is past the ceiling edge by its
## radius.
func test_released_crouch_under_a_ceiling_stands_within_1_tick_of_open_floor() -> void:
	_box(Vector3(0, LOW_CEILING_Y + 0.5, (CEILING_END_Z + 2.0) / 2.0), Vector3(4, 1, 2.0 - CEILING_END_Z))
	var b := _body(Vector3.ZERO)
	assert_bool(b.set_low(true)).is_true()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var r := _knobs.controller.player_radius_m
	var state := MovementStep.MoveState.new()
	var clear_tick := -1
	var stood_tick := -1
	for t in WALK_TICKS:
		await get_tree().physics_frame
		b.set_low(false) ## crouch released
		# The shape stores float32 (1.8 reads 1.79999995): compare against the midpoint of the two heights.
		state.crouched = b.capsule().height < (_knobs.controller.capsule_height_m + _knobs.controller.capsule_low_height_m) / 2.0
		if b.global_position.z > CEILING_END_Z - r + 0.001: ## some of the standing capsule is under the ceiling
			assert_bool(state.crouched).override_failure_message("stood at z %.3f" % b.global_position.z).is_true()
		if not state.crouched and stood_tick == -1:
			stood_tick = t
		MovementStep.step(b, _forward(), state, _knobs)
		if clear_tick == -1 and b.global_position.z < CEILING_END_Z - r:
			clear_tick = t
	assert_int(clear_tick).is_greater(0)
	# The probe clears a float hair before END - r (margin 0), so the stand may land one tick before
	# clear_tick; standing any earlier fails the per-tick check above.
	assert_int(stood_tick).is_between(clear_tick - 1, clear_tick + 1)


# --- AC3: head room blocked by another player only -----------------------------------------

## The other player is a real body standing 0.4 m away (closer than two radii), but the space probe
## does not test players (mask world | glass | doors): with no analytic input the player stands. Only
## the analytic test at the other's current-tick position keeps it crouched, until that body walks away.
func test_another_players_capsule_keeps_the_player_crouched_until_it_leaves() -> void:
	var b := _body(Vector3.ZERO)
	var other := _body(Vector3(0.4, 0, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(b.set_low(true)).is_true()
	assert_bool(b.set_low(false)).override_failure_message("the space probe saw a player").is_true()
	assert_bool(b.set_low(true)).is_true()
	assert_bool(b.set_low(false, _capsules([other]))).is_false()
	assert_float(b.capsule().height).is_equal_approx(_knobs.controller.capsule_low_height_m, 0.0001)
	other.global_position = Vector3(1.0, 0, 0) ## it walks away
	await get_tree().physics_frame
	assert_bool(b.set_low(false, _capsules([other]))).is_true()
	assert_float(b.capsule().height).is_equal_approx(_knobs.controller.capsule_height_m, 0.0001)


## Other players' capsules at their current positions, as the server will take them from history.
func _capsules(bodies: Array[PlayerBody]) -> Array[Vector4]:
	var out: Array[Vector4] = []
	for o in bodies:
		out.append(Vector4(o.global_position.x, o.global_position.y, o.global_position.z, o.capsule().height))
	return out


## ADR-0003 §6 capsule maths at the boundaries: side by side at two radii touches (no overlap); a
## capsule wholly above the other's head is clear; a downed (low) capsule beside still overlaps.
func test_capsule_overlap_boundaries() -> void:
	var r := _knobs.controller.player_radius_m
	var h := _knobs.controller.capsule_height_m
	var low := _knobs.controller.capsule_low_height_m
	assert_bool(PlayerBody.capsules_overlap(Vector3.ZERO, h, Vector3(2.0 * r - 0.001, 0, 0), h, r)).is_true()
	## Exactly two radii apart touches; 0.25 is exact in binary, so the boundary is not lost to rounding.
	assert_bool(PlayerBody.capsules_overlap(Vector3.ZERO, h, Vector3(0.5, 0, 0), h, 0.25)).is_false()
	assert_bool(PlayerBody.capsules_overlap(Vector3.ZERO, h, Vector3(0, h + 0.001, 0), h, r)).is_false()
	assert_bool(PlayerBody.capsules_overlap(Vector3.ZERO, h, Vector3(0, h - 0.01, 0), h, r)).is_true()
	assert_bool(PlayerBody.capsules_overlap(Vector3.ZERO, h, Vector3(0.5, 0, 0), low, r)).is_true()
	## Stacked: a low capsule whose feet are just above / just below a standing one's head.
	assert_bool(PlayerBody.capsules_overlap(Vector3.ZERO, h, Vector3(0, h + 0.001, 0), low, r)).is_false()
	assert_bool(PlayerBody.capsules_overlap(Vector3.ZERO, h, Vector3(0, h - 0.05, 0), low, r)).is_true()
	## A capsule shorter than two radii is a sphere: its segment is clamped to a point.
	assert_bool(PlayerBody.capsules_overlap(Vector3.ZERO, 0.4, Vector3(0, 0.55, 0), 0.4, 0.3)).is_true()
