# Story controller-interaction/007: interaction targeting (first-person-controller.md rule 12;
# ADR-0007 §10, ADR-0008 §2). A hand-built MapData and a few static boxes in this suite's world:
# MapQueries.interactable_on_ray returns the net id the view ray picks, or -1.
extends GdUnitTestSuite

const EYE := Vector3(0.0, 1.6, 0.0)
const CENTRE := Vector3(0.0, 0.9, 0.0)
const RANGE_M := 2.0
const RAY_MAX_M := 3.0
const POINT_H := 0.9

var _root: Node3D


func before_test() -> void:
	_root = auto_free(Node3D.new())
	add_child(_root)


func _rules(pick_radius: float = 0.5, door_closed: Callable = Callable()) -> MapQueries.InteractRules:
	var r := MapQueries.InteractRules.new()
	r.ray_max_m = RAY_MAX_M
	r.pick_radius_m = pick_radius
	r.point_height_m = POINT_H
	r.range_by_type = {&"terminal": RANGE_M, &"switch": 0.5}
	r.door_range_m = RANGE_M
	r.door_closed = door_closed
	return r


## A marker whose interaction point (POINT_H above its floor position) is `point`.
func _marker(type: StringName, point: Vector3) -> MapMarker:
	var m := MapMarker.new()
	m.id = StringName("m%d" % point.length_squared())
	m.type = type
	m.position = point - Vector3.UP * POINT_H
	return m


func _map(markers: Array[MapMarker], passages: Array[MapPassage] = []) -> MapQueries:
	var map := MapData.new()
	map.markers.assign(markers)
	map.passages.assign(passages)
	return MapQueries.new(map)


## A thin box across the -Z axis at `z`, on `layer`.
func _wall(z: float, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 0.1)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0.0, 1.0, z)
	_root.add_child(body)
	return body


func _space() -> PhysicsDirectSpaceState3D:
	return _root.get_world_3d().direct_space_state


func _aim(q: MapQueries, point: Vector3, rules: MapQueries.InteractRules = _rules(), exclude: Array[RID] = []) -> int:
	return q.interactable_on_ray(EYE, point - EYE, CENTRE, rules, _space(), exclude)


# --- AC1 ----------------------------------------------------------------------

func test_point_at_range_from_capsule_centre_resolves() -> void:
	var q := _map([_marker(&"terminal", Vector3(0.0, POINT_H, -RANGE_M))])
	assert_int(_aim(q, Vector3(0.0, POINT_H, -RANGE_M))).is_equal(0)


func test_point_just_past_range_does_not_resolve() -> void:
	var p := Vector3(0.0, POINT_H, -2.05)
	assert_int(_aim(_map([_marker(&"terminal", p)]), p)).is_equal(-1)


func test_point_off_the_ray_by_more_than_pick_radius_does_not_resolve() -> void:
	var q := _map([_marker(&"terminal", Vector3(0.6, POINT_H, -1.5))])
	assert_int(_aim(q, Vector3(0.0, POINT_H, -1.5))).is_equal(-1)


# --- AC2 ----------------------------------------------------------------------

func test_in_range_target_behind_an_out_of_range_one_wins() -> void:
	var dir := Vector3(0.0, -0.7, -1.7).normalized()
	var near := EYE + dir * 1.0 ## switch, range 0.5: out of range from the centre
	var far := EYE + dir * 1.8 ## terminal, range 2.0: in range
	assert_float(CENTRE.distance_to(near)).is_greater(0.5)
	assert_float(CENTRE.distance_to(far)).is_less(RANGE_M)
	var q := _map([_marker(&"switch", near), _marker(&"terminal", far)])
	assert_int(_aim(q, far)).is_equal(1)


func test_nearest_in_range_target_wins() -> void:
	var dir := Vector3(0.0, -0.7, -1.7).normalized()
	var q := _map([_marker(&"terminal", EYE + dir * 1.8), _marker(&"terminal", EYE + dir * 1.2)])
	assert_int(_aim(q, EYE + dir * 1.8)).is_equal(1)


func test_equal_distance_picks_the_lowest_net_id() -> void:
	var p := Vector3(0.0, POINT_H, -1.5)
	var q := _map([_marker(&"terminal", p), _marker(&"terminal", p)])
	assert_int(_aim(q, p)).is_equal(0)


# --- AC3 ----------------------------------------------------------------------

func test_wall_between_eye_and_point_blocks() -> void:
	var p := Vector3(0.0, POINT_H, -1.8)
	_wall(-1.0, PhysicsLayers.WORLD)
	await get_tree().physics_frame
	assert_int(_aim(_map([_marker(&"terminal", p)]), p)).is_equal(-1)


func test_glass_between_eye_and_point_blocks() -> void:
	var p := Vector3(0.0, POINT_H, -1.8)
	_wall(-1.0, PhysicsLayers.GLASS)
	await get_tree().physics_frame
	assert_int(_aim(_map([_marker(&"terminal", p)]), p)).is_equal(-1)


func test_wall_behind_the_point_does_not_block() -> void:
	var p := Vector3(0.0, POINT_H, -1.5)
	_wall(-1.8, PhysicsLayers.WORLD)
	await get_tree().physics_frame
	assert_int(_aim(_map([_marker(&"terminal", p)]), p)).is_equal(0)


func test_the_actors_own_body_is_excluded() -> void:
	var p := Vector3(0.0, POINT_H, -1.8)
	var own := _wall(-0.2, PhysicsLayers.WORLD)
	await get_tree().physics_frame
	var q := _map([_marker(&"terminal", p)])
	assert_int(_aim(q, p)).is_equal(-1)
	assert_int(_aim(q, p, _rules(), [own.get_rid()])).is_equal(0)


## A door across the ray at z = -1, its own point off the ray (pick radius 0.1), a terminal behind.
func _door_case(closed: bool) -> int:
	var door := MapPassage.new()
	door.id = &"d"
	door.kind = MapPassage.DOOR
	door.position = Vector3(0.0, 0.0, -1.0)
	door.width_m = 1.0
	door.swing_box = AABB(Vector3(-0.5, 0.0, -2.0), Vector3(1.0, 2.0, 2.0))
	var p := Vector3(0.0, POINT_H, -1.8)
	var q := _map([_marker(&"terminal", p)], [door])
	return _aim(q, p, _rules(0.1, func(id: int) -> bool: return closed and id == 0))


func test_closed_door_between_eye_and_point_blocks() -> void:
	assert_int(_door_case(true)).is_equal(-1)


func test_open_door_does_not_block() -> void:
	assert_int(_door_case(false)).is_equal(1) ## net id 1: doors come first


# --- AC4 ----------------------------------------------------------------------

## The function takes one direction; the server passes ViewState.server_dir. A client claim aimed
## elsewhere targets nothing, so only the server's yaw and pitch decide.
func test_target_follows_the_server_view_direction() -> void:
	var p := Vector3(0.0, POINT_H, -1.5)
	var q := _map([_marker(&"terminal", p)])
	var to := p - EYE
	var server_dir := ViewState.direction(0.0, atan2(to.y, -to.z))
	var client_dir := ViewState.direction(PI / 2.0, 0.0)
	assert_int(q.interactable_on_ray(EYE, server_dir, CENTRE, _rules(), _space())).is_equal(0)
	assert_int(q.interactable_on_ray(EYE, client_dir, CENTRE, _rules(), _space())).is_equal(-1)


func test_from_knobs_reads_shipped_ranges() -> void:
	var k := Knobs.load_all()
	var r := MapQueries.InteractRules.from_knobs(k)
	assert_float(r.ray_max_m).is_equal(k.controller.interact_ray_max_m)
	assert_float(r.range_by_type[&"switch"]).is_equal(k.ability.backup_switch_range_m)
	assert_float(r.door_range_m).is_equal(k.objectives.interact_range_m)
	assert_float(r.point_height_m).is_equal(k.controller.capsule_height_m / 2.0)


# --- Code review 2026-10-14: edges the first pass left untested ------------------

func test_point_past_ray_max_does_not_resolve_even_in_range() -> void:
	var r := _rules()
	r.range_by_type[&"terminal"] = 5.0
	var p := EYE + Vector3.FORWARD * (RAY_MAX_M + 0.05)
	assert_int(_aim(_map([_marker(&"terminal", p)]), p, r)).is_equal(-1)


func test_unknown_marker_type_never_resolves() -> void:
	var p := Vector3(0.0, POINT_H, -1.5)
	assert_int(_aim(_map([_marker(&"camera", p)]), p)).is_equal(-1)


func test_point_behind_the_eye_does_not_resolve() -> void:
	var q := _map([_marker(&"terminal", Vector3(0.0, POINT_H, 0.5))])
	assert_int(q.interactable_on_ray(EYE, Vector3.FORWARD, CENTRE, _rules(), _space())).is_equal(-1)


func test_an_area_on_the_projectile_layers_does_not_block() -> void:
	var p := Vector3(0.0, POINT_H, -1.8)
	var area := Area3D.new()
	area.collision_layer = PhysicsLayers.PROJECTILE
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(4.0, 4.0, 0.1)
	area.add_child(shape)
	area.position = Vector3(0.0, 1.0, -1.0)
	_root.add_child(area)
	await get_tree().physics_frame
	assert_int(_aim(_map([_marker(&"terminal", p)]), p)).is_equal(0)


func test_a_closed_door_is_itself_a_target() -> void:
	var door := MapPassage.new()
	door.kind = MapPassage.DOOR
	door.position = Vector3(0.0, 0.0, -1.0)
	door.width_m = 1.0
	door.swing_box = AABB(Vector3(-0.5, 0.0, -2.0), Vector3(1.0, 2.0, 2.0))
	var q := _map([], [door])
	assert_int(_aim(q, Vector3(0.0, POINT_H, -1.0), _rules(0.5, func(_id: int) -> bool: return true))).is_equal(0)


## The analytic leaf of every shipped door matches the greybox scene's door blocker in x and z, so the
## closed-door test blocks where the closed door's collider does.
func test_shipped_door_leaves_match_the_greybox_blockers() -> void:
	var map := MapData.load_map()
	var level: Node3D = auto_free(load("res://assets/levels/research_facility.tscn").instantiate())
	var checked := 0
	for p in map.passages:
		if not p.is_door():
			continue
		var body := level.find_child("Door_" + String(p.id), true, false) as StaticBody3D
		assert_object(body).override_failure_message("no blocker for %s" % p.id).is_not_null()
		var size := ((body.get_child(0) as CollisionShape3D).shape as BoxShape3D).size
		var leaf := MapQueries._leaf(p)
		assert_vector(Vector2(leaf.size.x, leaf.size.z)).override_failure_message(String(p.id)) \
			.is_equal_approx(Vector2(size.x, size.z), Vector2(1e-4, 1e-4))
		assert_vector(Vector2(leaf.get_center().x, leaf.get_center().z)) \
			.is_equal_approx(Vector2(body.position.x, body.position.z), Vector2(1e-4, 1e-4))
		checked += 1
	assert_int(checked).is_greater(0)
