# Story controller-interaction/012: doors toggle instantly and refuse a close through a player
# (first-person-controller.md rule 18 and the lunge edge case; ADR-0007 §5, §8; ADR-0008 §2).
# Integration: a fixture door on the real HoldService, real Jolt PlayerBody capsules and door blockers.
# The client's prediction world is a SubViewport with its own World3D whose blocker is driven only by
# a copy of the server's door state (what replication delivers).
extends GdUnitTestSuite

const A := 1 ## the player who toggles the door; stands clear of the swing area
const B := 2
const DOOR := 0 ## net id: the fixture map's only interactable
const DOOR_ID := &"d"
## Fixture door in a wall along x at z = 0: 1 m opening; the leaf sweeps 1 m to either side.
const SWING := AABB(Vector3(-0.5, 0.0, -1.0), Vector3(1.0, 2.0, 2.0))
const LEAF := Vector3(1.0, 2.0, 0.1)
const A_FEET := Vector3(1.2, 0.0, 1.0) ## 1.56 m from the door point, capsule x >= 0.9: clear
const WALK_MPS := 4.0

var _knobs: Knobs
var _world: Node3D
var _client: SubViewport
var _map: MapData
var _holds: HoldService
var _doors: Doors
var _registry: StateRegistry
var _bodies: Dictionary = {} ## actor -> PlayerBody
var _feed: Dictionary = {}
var _tick := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_world = Node3D.new()
	add_child(_world)
	_client = SubViewport.new()
	_client.own_world_3d = true
	add_child(_client)
	var door := MapPassage.new()
	door.id = DOOR_ID
	door.kind = MapPassage.DOOR
	door.position = Vector3.ZERO
	door.width_m = 1.0
	door.swing_box = SWING
	_map = MapData.new()
	_map.passages.append(door)
	_bodies = {}
	_feed = {}
	_tick = 0
	_holds = HoldService.new(_knobs, func() -> Array: return _bodies.keys(),
		func(actor: int) -> Array: return _feed.get(actor, []),
		func(actor: int) -> Vector3: return _feet(actor) + Vector3.UP * _bodies[actor].capsule().height / 2.0,
		func(_actor: int, _i: Interactable) -> bool: return true,
		func(_actor: int) -> int: return DOOR)
	_doors = Doors.new(_holds, _map, _capsules)
	_registry = StateRegistry.new()
	_doors.setup(null, null, _registry, _knobs)
	_blocker(_world)
	_doors.blockers = DoorBlockers.new(_world, _map)
	_body(A, A_FEET)


func after_test() -> void:
	_registry.clear()
	_world.free()
	_client.free()


func _feet(actor: int) -> Vector3:
	return (_bodies[actor] as PlayerBody).global_position


## Every player capsule, Vector4(feet x, y, z, height): the Doors capsules source.
func _capsules() -> Array[Vector4]:
	var out: Array[Vector4] = []
	for actor: int in _bodies:
		var f := _feet(actor)
		out.append(Vector4(f.x, f.y, f.z, (_bodies[actor] as PlayerBody).capsule().height))
	return out


## The greybox's door blocker (tools/level/greybox_from_map.gd): doors layer, starts open.
func _blocker(parent: Node) -> CollisionShape3D:
	var b := StaticBody3D.new()
	b.collision_layer = PhysicsLayers.DOORS
	b.collision_mask = PhysicsLayers.NONE
	b.set_meta(&"passage", DOOR_ID)
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	cs.shape.size = LEAF
	cs.disabled = true
	b.add_child(cs)
	parent.add_child(b)
	b.global_position = Vector3(0.0, LEAF.y / 2.0, 0.0)
	return cs


func _body(actor: int, feet: Vector3, parent: Node = null, mask := PhysicsLayers.MOVE_SERVER) -> PlayerBody:
	var b := PlayerBody.new()
	b.setup(_knobs, mask)
	(parent if parent else _world).add_child(b)
	b.global_position = feet
	if actor > 0:
		_bodies[actor] = b
	return b


func _f(interact: bool) -> InputFrame:
	var f := InputFrame.new()
	f.interact = interact
	f.interact_target = DOOR
	return f


## A releases, then presses on the next tick: the toggle (or its rejection) happens on that tick.
func _toggle() -> void:
	for down in [false, true]:
		_feed[A] = [_f(down)]
		_holds.server_tick(_tick)
		_tick += 1


func _shape(parent: Node) -> CollisionShape3D:
	for n in parent.get_children():
		if n is StaticBody3D:
			return n.get_child(0)
	return null


## Moves `body` along +z at `mps` for `ticks` physics frames.
func _move(body: PlayerBody, mps: float, ticks: int) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame ## in the broadphase before the first step
	for t in ticks:
		await get_tree().physics_frame
		body.velocity = Vector3(0.0, 0.0, mps)
		body.move_and_slide()


# --- AC1: close rejected through a capsule; toggles on the same tick when clear ----------------

func test_close_is_rejected_while_a_capsule_overlaps_the_swing_area() -> void:
	_body(B, Vector3(0.0, 0.0, 0.5))
	_toggle()
	assert_bool(_doors.is_closed(DOOR)).is_false()


func test_with_the_area_clear_the_door_toggles_on_the_press_tick() -> void:
	var b := _body(B, Vector3(0.0, 0.0, 0.5))
	_toggle()
	b.global_position = Vector3(0.0, 0.0, 3.0)
	_feed[A] = [_f(false)]
	_holds.server_tick(_tick)
	_tick += 1
	assert_bool(_doors.is_closed(DOOR)).is_false()
	_feed[A] = [_f(true)]
	_holds.server_tick(_tick) ## the press tick itself
	assert_bool(_doors.is_closed(DOOR)).is_true()


func test_opening_is_never_blocked_by_a_capsule() -> void:
	_toggle()
	_body(B, Vector3(0.0, 0.0, 0.5))
	_toggle()
	assert_bool(_doors.is_closed(DOOR)).is_false()


func test_a_capsule_just_outside_the_swing_box_lets_the_door_close() -> void:
	var r := _knobs.controller.player_radius_m
	var b := _body(B, Vector3(0.0, 0.0, SWING.end.z + r - 0.01))
	_toggle()
	assert_bool(_doors.is_closed(DOOR)).is_false()
	b.global_position = Vector3(0.0, 0.0, SWING.end.z + r + 0.01)
	_toggle()
	assert_bool(_doors.is_closed(DOOR)).is_true()


func test_capsule_overlaps_swing_corner_and_height() -> void:
	var q := MapQueries.new(_map)
	var r := 0.3
	var h := 1.8
	var corner := Vector3(SWING.end.x, 0.0, SWING.end.z)
	var diag := Vector3(1.0, 0.0, 1.0).normalized()
	## A corner is a circle, not the box's square bound.
	assert_bool(q.capsule_overlaps_swing(DOOR_ID, corner + diag * (r - 0.01) + Vector3.UP * h / 2.0, h, r)).is_true()
	assert_bool(q.capsule_overlaps_swing(DOOR_ID, corner + diag * (r + 0.01) + Vector3.UP * h / 2.0, h, r)).is_false()
	## A capsule above the swing box's top does not overlap it.
	var above := Vector3(0.0, SWING.end.y + 0.01 + h / 2.0, 0.0)
	assert_bool(q.capsule_overlaps_swing(DOOR_ID, above, h, r)).is_false()
	## Exactly r from the box (values exact in float): touching is not overlap.
	assert_bool(q.capsule_overlaps_swing(DOOR_ID, Vector3(0.0, 1.0, SWING.end.z + 0.25), 2.0, 0.25)).is_false()
	assert_bool(q.capsule_overlaps_swing(DOOR_ID, Vector3(0.0, 1.0, SWING.end.z + 0.125), 2.0, 0.25)).is_true()
	assert_bool(q.capsule_overlaps_swing(&"nope", Vector3(0.0, h / 2.0, 0.0), h, r)).is_false()


# --- AC2: a lunge dash (stub dash mover) --------------------------------------------------------

func _dash_mps() -> float:
	return _knobs.ability.lunge_distance_m / _knobs.ability.lunge_dash_s


func _dash_ticks() -> int:
	return _knobs.ticks(_knobs.ability.lunge_dash_s)


func test_dasher_not_yet_in_the_swing_area_does_not_stop_the_close_and_is_stopped() -> void:
	var dasher := _body(B, Vector3(0.0, 0.0, SWING.position.z - 0.31))
	_toggle()
	assert_bool(_doors.is_closed(DOOR)).is_true()
	await _move(dasher, _dash_mps(), _dash_ticks())
	assert_float(dasher.global_position.z).is_less(-LEAF.z / 2.0) ## the dash stops at the leaf


func test_dasher_already_in_the_swing_area_rejects_the_close_and_passes() -> void:
	var dasher := _body(B, Vector3(0.0, 0.0, SWING.position.z - 0.29))
	_toggle()
	assert_bool(_doors.is_closed(DOOR)).is_false()
	await _move(dasher, _dash_mps(), _dash_ticks())
	assert_float(dasher.global_position.z).is_greater(SWING.end.z)


# --- AC3: blocker enabled exactly while closed; server and prediction both collide -------------

func test_blocker_shape_is_enabled_exactly_while_closed() -> void:
	var shape := _shape(_world)
	assert_bool(shape.disabled).is_true()
	for i in 4:
		_toggle()
		assert_bool(shape.disabled).is_equal(not _doors.is_closed(DOOR))
	var view := _registry.view(StateKeys.DOOR_STATE, Doors.DoorStateView) as Doors.DoorStateView
	assert_bool(view.is_closed(DOOR)).is_equal(_doors.is_closed(DOOR))


func test_server_movement_and_client_prediction_collide_from_door_state() -> void:
	var client_shape := _blocker(_client)
	var client_blockers := DoorBlockers.new(_client, _map)
	var server := _body(0, Vector3(-0.2, 0.0, -2.0)) ## not a player of the hold: no capsule in the swing
	var predicted := _body(0, Vector3(-0.2, 0.0, -2.0), _client, PhysicsLayers.MOVE_PREDICT)
	_toggle()
	assert_bool(_doors.is_closed(DOOR)).is_true()
	client_blockers.apply(_doors.closed_states()) ## the replicated copy
	assert_bool(client_shape.disabled).is_false()
	await _move(server, WALK_MPS, 60)
	await _move(predicted, WALK_MPS, 60)
	assert_float(server.global_position.z).is_less(0.0)
	assert_float(predicted.global_position.z).is_less(0.0)
	_toggle()
	client_blockers.apply(_doors.closed_states())
	assert_bool(client_shape.disabled).is_true()
	await _move(server, WALK_MPS, 60)
	await _move(predicted, WALK_MPS, 60)
	assert_float(server.global_position.z).is_greater(1.0)
	assert_float(predicted.global_position.z).is_greater(1.0)
