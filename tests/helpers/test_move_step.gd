class_name TestMoveStep extends RefCounted
## Stand-in for the controller's movement step (controller epic owns the real one) plus test geometry.
## Ideas copied from prototypes/adr-verification/lib.gd (make_player, step, add_wedge, add_box):
## capsule r 0.30 h 1.8, floor settings of ADR-0007, accel over ACCEL_S, gravity off the floor,
## one move_and_slide. Test bodies collide with the WORLD layer only (players do not block each other).
## Forward at yaw 0 is -Z. Usage: `TestMoveStep.apply` is the Callable(body, frame, modifiers).

const WORLD := 1 << 0
const PLAYERS := 1 << 3
const WALK_SPEED := 4.0
const ACCEL_S := 0.05
const FLOOR_MAX_ANGLE_DEG := 40.0
const FLOOR_SNAP_M := 0.4
const CAPSULE_RADIUS := 0.30
const CAPSULE_HEIGHT := 1.8


## The shared step: same function for the server body and the owner's body.
static func apply(body: CharacterBody3D, frame: InputFrame, modifiers: MovementModifiers) -> void:
	var dt := 1.0 / Engine.physics_ticks_per_second
	var move := Vector2.ZERO if modifiers.rooted or modifiers.locked else frame.move
	var dir := Basis(Vector3.UP, frame.yaw) * Vector3(move.x, 0.0, -move.y)
	var target := dir * WALK_SPEED * modifiers.speed_scale
	var rate := WALK_SPEED / ACCEL_S * dt
	body.velocity.x = move_toward(body.velocity.x, target.x, rate)
	body.velocity.z = move_toward(body.velocity.z, target.z, rate)
	if body.is_on_floor():
		body.velocity.y = 0.0
		if body.velocity.is_zero_approx():
			return ## resting: a zero-motion move_and_slide can still shift the body inside its safe margin
	else:
		body.velocity.y += body.get_gravity().y * dt
	body.move_and_slide()


static func make_body(parent: Node, pos: Vector3) -> CharacterBody3D:
	var p := CharacterBody3D.new()
	p.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	p.collision_layer = PLAYERS
	p.collision_mask = WORLD
	p.floor_max_angle = deg_to_rad(FLOOR_MAX_ANGLE_DEG)
	p.floor_snap_length = FLOOR_SNAP_M
	p.floor_stop_on_slope = true
	p.floor_constant_speed = true
	p.floor_block_on_wall = true
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = CAPSULE_RADIUS
	cap.height = CAPSULE_HEIGHT
	cs.shape = cap
	cs.position.y = CAPSULE_HEIGHT / 2.0
	p.add_child(cs)
	parent.add_child(p)
	p.global_position = pos
	return p


## A box whose centre is `pos`.
static func add_box(parent: Node, pos: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = WORLD
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	b.add_child(cs)
	parent.add_child(b)
	b.global_position = pos
	return b


## Wedge rising along +Z from z0 (height 0) to z0 + depth (height), 4 m wide.
static func add_wedge(parent: Node, z0: float, angle_deg: float, height: float) -> StaticBody3D:
	var depth := height / tan(deg_to_rad(angle_deg))
	var b := StaticBody3D.new()
	b.collision_layer = WORLD
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3(-2, 0, z0), Vector3(2, 0, z0),
		Vector3(-2, 0, z0 + depth), Vector3(2, 0, z0 + depth),
		Vector3(-2, height, z0 + depth), Vector3(2, height, z0 + depth),
	])
	cs.shape = shape
	b.add_child(cs)
	parent.add_child(b)
	return b
