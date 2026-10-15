class_name PlayerBody extends CharacterBody3D
## One player's body in every form (survivor, disguised or true-form shapeshifter): a grounded
## CharacterBody3D with its own two CapsuleShape3D resources, built with .new() so no two players share
## a shape (ADR-0007 §2). Sizes come from ControllerKnobs. State changes are made directly from
## TickRunner phases and network handlers (never set_deferred outside physics callbacks).
## - Low (crouched or Downed): the low capsule; the shape sits at y = height / 2.
## - Downed: low capsule and no `players` bit in the layer, so upright movers pass through.
## - Out (Eliminated, Escaped): layer, mask 0 and the shape disabled; the caller also stops its movement
##   with ServerMovement.set_frozen() (Foundation cannot read this Core class).
## Hidden survivors (layer and mask 0 at a hide point) belong to the Survivor Defense epic.
## Usage:
##   var body := PlayerBody.new(); body.setup(knobs, PhysicsLayers.MOVE_SERVER); parent.add_child(body)
##   body.set_downed(true)

## ADR-0007 §2: the stand-up probe is lifted this far so a body resting on the floor is not "inside" it.
const STAND_CHECK_LIFT_M := 0.01

var _standing: CapsuleShape3D
var _low_shape: CapsuleShape3D
var _shape_node: CollisionShape3D
var _mask: int
var _low := false
var _downed := false
var _out := false


## Builds the capsules and the collision shape. `mask` is the movement mask from PhysicsLayers
## (MOVE_SERVER on the server, MOVE_PREDICT on the owning client).
func setup(knobs: Knobs, mask: int) -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	# ADR-0007 §3: floor and slide settings from data; the three flags are the ADR's fixed choices.
	var c := knobs.controller
	floor_max_angle = deg_to_rad(c.floor_max_angle_deg)
	floor_snap_length = c.floor_snap_length_m
	safe_margin = c.safe_margin_m
	max_slides = c.max_slides
	wall_min_slide_angle = deg_to_rad(c.wall_min_slide_angle_deg)
	floor_stop_on_slope = true
	floor_constant_speed = true
	floor_block_on_wall = true
	_mask = mask
	_standing = CapsuleShape3D.new()
	_standing.radius = knobs.controller.player_radius_m
	_standing.height = knobs.controller.capsule_height_m
	_low_shape = CapsuleShape3D.new()
	_low_shape.radius = knobs.controller.player_radius_m
	_low_shape.height = knobs.controller.capsule_low_height_m
	_shape_node = CollisionShape3D.new()
	add_child(_shape_node)
	_apply()


## The capsule in use now (standing or low).
func capsule() -> CapsuleShape3D:
	return _shape_node.shape


## Crouch (true) or stand (false). Standing is refused while the standing capsule would overlap world,
## glass or doors, or one of `others`: other players' capsules at their current-tick positions, each
## Vector4(feet x, y, z, capsule height), tested analytically (ADR-0007 §6a; the physics space does not
## have this tick's positions yet). Returns false then and the body stays low. Call it every tick with
## the crouch input, so a released crouch stands up on the first tick there is head room (story 004).
## Ignored while Downed or Out (returns false).
func set_low(low: bool, others: Array[Vector4] = []) -> bool:
	if _downed or _out:
		return false
	if not low and _low and (_standing_blocked() or _player_blocks(others)):
		return false
	_low = low
	_apply()
	return true


## Downed: low capsule, no `players` layer bit. Leaving Downed stands the body up when the standing
## capsule fits (the same probe as set_low), else it stays low as if crouched.
func set_downed(downed: bool) -> void:
	_downed = downed
	_low = downed or _standing_blocked()
	_apply()


## Out (Eliminated or Escaped): no collision at all and no movement. One-way for the round.
func set_out() -> void:
	_out = true
	velocity = Vector3.ZERO
	_apply()


func is_out() -> bool:
	return _out


func is_downed() -> bool:
	return _downed


func _apply() -> void:
	_shape_node.shape = _low_shape if _low else _standing
	_shape_node.position = Vector3(0.0, capsule().height / 2.0, 0.0)
	_shape_node.disabled = _out
	if _out:
		collision_layer = PhysicsLayers.NONE
		collision_mask = PhysicsLayers.NONE
	elif _downed:
		collision_layer = PhysicsLayers.NONE
		collision_mask = _mask & ~PhysicsLayers.PLAYERS
	else:
		collision_layer = PhysicsLayers.PLAYERS
		collision_mask = _mask


## True when the standing capsule, raised like the space probe, overlaps one of `others` (Vector4 feet
## and height, the same radius: every player's capsule uses player_radius_m).
func _player_blocks(others: Array[Vector4]) -> bool:
	var feet := global_position + Vector3(0.0, STAND_CHECK_LIFT_M, 0.0)
	for o in others:
		if capsules_overlap(feet, _standing.height, Vector3(o.x, o.y, o.z), o.w, _standing.radius):
			return true
	return false


## ADR-0003 §6 capsule maths: two upright capsules of radius `r`, standing on `a_feet` and `b_feet` with
## heights `a_h` and `b_h`, overlap when their axis segments (half-length height / 2 - r, centred at
## half height) come closer than 2r. Touching is not overlap. A capsule shorter than 2r is a sphere:
## its segment is clamped to a point.
static func capsules_overlap(a_feet: Vector3, a_h: float, b_feet: Vector3, b_h: float, r: float) -> bool:
	var a0 := a_feet.y + r
	var a1 := maxf(a0, a_feet.y + a_h - r)
	var b0 := b_feet.y + r
	var b1 := maxf(b0, b_feet.y + b_h - r)
	var gap := maxf(0.0, maxf(a0, b0) - minf(a1, b1))
	var flat := Vector2(a_feet.x - b_feet.x, a_feet.z - b_feet.z).length()
	return flat * flat + gap * gap < 4.0 * r * r


## ADR-0007 §2: the standing capsule raised 0.01 m, margin 0, own RID excluded, world | glass | doors.
func _standing_blocked() -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _standing
	q.margin = 0.0
	q.collision_mask = PhysicsLayers.MOVE_PREDICT
	q.exclude = [get_rid()]
	q.transform = global_transform.translated(Vector3(0.0, _standing.height / 2.0 + STAND_CHECK_LIFT_M, 0.0))
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

