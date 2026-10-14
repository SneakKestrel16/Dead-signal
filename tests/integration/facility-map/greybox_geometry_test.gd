# Story facility-map/002: greybox geometry and collision (research-facility.md Dimensions and Traversal,
# Geometry limits; ADR-0007 §4-5). Loads the authored greybox scene with the map data and measures it
# with physics queries, so a hand edit to the scene that breaks a limit fails here.
extends GdUnitTestSuite

const SCENE := "res://assets/levels/research_facility.tscn"
const MIN_CLEAR_M := 0.8 ## research-facility.md Geometry limits
const WALL_T := 0.2 ## greybox wall thickness (tools/level/greybox_from_map.gd)
const MAX_SLOPE_DEG := 40.0 ## ADR-0007 §3 floor_max_angle
const EYE_Y := 1.6
const PROBE_Y := 1.0 ## clear-width rays run at waist height, under the 2.0 m door leaf
const RAY_MAX_M := 6.0
const STEP_RESTS_M := 0.01 ## a box whose bottom is within this of the floor rests on it
## A floor-resting box this low is a step (anything taller is a wall or a prop, not something to climb).
const STEP_TOP_MAX_M := 1.0
const RAMP_TOUCH_M := 0.05
const SLOPE_SAMPLES := 8
const LOADS := 10
## Room pairs the level doc draws glass between (`:` in the Overview Map), each with a point on the
## partition clear of its door (x, z) and the direction across it.
const GLASS_PROBES := [
	["A2|A3", Vector2(10.0, 24.0), Vector3.RIGHT],
	["A2|A4", Vector2(13.0, 17.0), Vector3.RIGHT],
	["A4|A7", Vector2(18.0, 14.0), Vector3.BACK],
]

var _knobs: Knobs
var _map: MapData
var _level: Node3D


func before_test() -> void:
	_knobs = Knobs.load_all()
	_map = MapData.load_map()
	_level = auto_free(load(SCENE).instantiate())
	add_child(_level)
	await get_tree().physics_frame
	await get_tree().physics_frame


func _space() -> PhysicsDirectSpaceState3D:
	return _level.get_world_3d().direct_space_state


func _ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	q.collide_with_areas = false
	return _space().intersect_ray(q)


## Distance to the first world or glass hit from `from` along `dir`, or INF.
func _reach(from: Vector3, dir: Vector3) -> float:
	var hit := _ray(from, from + dir * RAY_MAX_M, PhysicsLayers.WORLD | PhysicsLayers.GLASS)
	return from.distance_to(hit.position) if not hit.is_empty() else INF


## Clear width of a passage: the opening is the axis where both sides end in a wall close by.
func _clear_width(p: MapPassage) -> float:
	var c := Vector3(p.position.x, PROBE_Y, p.position.z)
	var best := INF
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		best = minf(best, _reach(c, axis) + _reach(c, -axis))
	return best


func _bodies(root: Node) -> Array[CollisionObject3D]:
	var out: Array[CollisionObject3D] = []
	for n in root.find_children("*", "CollisionObject3D", true, false):
		out.append(n)
	return out


func _world_box(body: StaticBody3D) -> AABB:
	var cs := body.get_node("Shape") as CollisionShape3D
	var size := (cs.shape as BoxShape3D).size
	return AABB(body.global_position - size / 2.0, size)


func _points_aabb(points: PackedVector3Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for p in points:
		box = box.expand(p)
	return box


## Steepest walkable surface of `body` in degrees, from the physics hit normals of a grid of downward
## rays over `bounds`. (A convex debug mesh is drawn as lines, so its "faces" are not triangles: code
## review 2026-10-14.)
func _slope_deg(body: CollisionObject3D, bounds: AABB) -> float:
	var steepest := 0.0
	for i in SLOPE_SAMPLES:
		for j in SLOPE_SAMPLES:
			# Cell centres: a ray on the footprint's edge grazes a vertical side and reads 90 degrees.
			var x := bounds.position.x + bounds.size.x * (i + 0.5) / SLOPE_SAMPLES
			var z := bounds.position.z + bounds.size.z * (j + 0.5) / SLOPE_SAMPLES
			var hit := _ray(Vector3(x, bounds.end.y + 1.0, z), Vector3(x, bounds.position.y - 1.0, z), PhysicsLayers.WORLD)
			if not hit.is_empty() and hit.collider == body:
				steepest = maxf(steepest, rad_to_deg(acos(clampf(hit.normal.y, -1.0, 1.0))))
	return steepest


## AC1 steps and ramps: problems under `root`. A step is a floor-resting world box no taller than
## STEP_TOP_MAX_M; it must be at most step_height_m and touch a ramp; every ramp is at most 40°.
## Waits a physics frame so bodies added this frame are in the space.
func _step_ramp_problems(root: Node) -> PackedStringArray:
	await get_tree().physics_frame
	var out := PackedStringArray()
	var ramps: Array[AABB] = []
	for body in _bodies(root):
		for cs: CollisionShape3D in body.find_children("*", "CollisionShape3D", false, false):
			if body.collision_layer & PhysicsLayers.WORLD and cs.shape is ConvexPolygonShape3D:
				var bounds := cs.global_transform * _points_aabb((cs.shape as ConvexPolygonShape3D).points)
				var slope := _slope_deg(body, bounds)
				if slope > MAX_SLOPE_DEG + 0.01:
					out.append("%s: ramp %.1f° > %.0f°" % [body.name, slope, MAX_SLOPE_DEG])
				ramps.append(bounds)
	for body in _bodies(root):
		if not (body is StaticBody3D and body.collision_layer & PhysicsLayers.WORLD and body.get_node_or_null("Shape") is CollisionShape3D \
				and (body.get_node("Shape") as CollisionShape3D).shape is BoxShape3D):
			continue
		var box := _world_box(body)
		if absf(box.position.y) > STEP_RESTS_M or box.end.y > STEP_TOP_MAX_M or box.end.y <= STEP_RESTS_M:
			continue
		if box.end.y > _knobs.controller.step_height_m + 1e-4:
			out.append("%s: step %.2f m > %.2f m" % [body.name, box.end.y, _knobs.controller.step_height_m])
		elif not ramps.any(func(r: AABB) -> bool: return r.intersects(box.grow(RAMP_TOUCH_M))):
			out.append("%s: step %.2f m has no ramp collider" % [body.name, box.end.y])
	return out


func _add_box(parent: Node3D, node_name: String, centre: Vector3, size: Vector3) -> void:
	var b := TestMoveStep.add_box(parent, centre, size)
	b.name = node_name
	b.collision_layer = PhysicsLayers.WORLD
	b.get_child(0).name = "Shape"


# --- AC1 ----------------------------------------------------------------------

func test_every_doorway_archway_and_exit_is_at_least_0_8_m_clear() -> void:
	assert_int(_map.passages.size()).is_greater(0)
	for p in _map.passages:
		var w := _clear_width(p)
		# Finite: an opening with no wall on either side would read INF and pass the minimum unmeasured.
		assert_float(w).override_failure_message("%s: no jambs found" % p.id).is_less(RAY_MAX_M * 2.0)
		assert_float(w).override_failure_message("%s: %.2f m clear" % [p.id, w]).is_greater_equal(MIN_CLEAR_M)
		# Within one wall thickness of the data: never wider (a missing jamb), narrower only where the
		# opening ends at a perpendicular wall whose half thickness eats into it (A1-H-S 1.9 m, A2 junctions 2.8 m).
		assert_float(w).override_failure_message("%s: %.2f m clear, data says %.2f" % [p.id, w, p.width_m]) \
			.is_between(p.width_m - WALL_T - 0.01, p.width_m + 0.01)


func test_greybox_has_no_step_or_ramp_beyond_the_controller_limits() -> void:
	assert_array(await _step_ramp_problems(_level)).is_empty()


func test_step_and_ramp_check_fails_on_bad_geometry() -> void:
	# Proves the check above can fail: a bare 0.3 m step, a 0.36 m step, a 41° ramp. Far from the level.
	var bad: Node3D = auto_free(Node3D.new())
	bad.position = Vector3(200, 0, 200)
	add_child(bad)
	_add_box(bad, "LowStep", Vector3(205, 0.15, 205), Vector3(1, 0.3, 1))
	_add_box(bad, "HighStep", Vector3(210, 0.18, 210), Vector3(1, 0.36, 1))
	var steep := TestMoveStep.add_wedge(bad, 20.0, 41.0, 0.3)
	steep.collision_layer = PhysicsLayers.WORLD
	var problems := " ".join(await _step_ramp_problems(bad))
	assert_str(problems).contains("LowStep: step 0.30 m has no ramp").contains("HighStep: step 0.36 m").contains("41.0°")
	# A 0.35 m step (the limit) with a 40° ramp against it passes.
	var ok: Node3D = auto_free(Node3D.new())
	ok.position = Vector3(300, 0, 300)
	add_child(ok)
	var depth := 0.35 / tan(deg_to_rad(40.0))
	_add_box(ok, "Step", Vector3(300, 0.175, 300 + 2.0 + depth + 0.5), Vector3(4, 0.35, 1))
	TestMoveStep.add_wedge(ok, 2.0, 40.0, 0.35).collision_layer = PhysicsLayers.WORLD
	assert_array(await _step_ramp_problems(ok)).is_empty()


# --- AC2 ----------------------------------------------------------------------

func test_every_collider_is_on_world_glass_or_doors_and_glass_only_on_glass() -> void:
	var allowed := [PhysicsLayers.WORLD, PhysicsLayers.GLASS, PhysicsLayers.DOORS]
	for body in _bodies(_level):
		assert_bool(body.collision_layer in allowed).override_failure_message("%s: layer %d" % [body.name, body.collision_layer]).is_true()
		for cs: CollisionShape3D in body.find_children("*", "CollisionShape3D", false, false):
			assert_bool(cs.shape is WorldBoundaryShape3D).override_failure_message(body.name).is_false()
	# Every glass partition the doc draws is on the glass layer only: SIGHT passes it, PROJECTILE stops
	# at a glass-layer body. Found by geometry, not by node name.
	for g in GLASS_PROBES:
		var at: Vector2 = g[1]
		var dir: Vector3 = g[2]
		var c := Vector3(at.x, EYE_Y, at.y)
		assert_dict(_ray(c - dir, c + dir, PhysicsLayers.SIGHT)).override_failure_message("%s: SIGHT blocked" % g[0]).is_empty()
		var hit := _ray(c - dir, c + dir, PhysicsLayers.PROJECTILE)
		assert_bool(not hit.is_empty() and (hit.collider as CollisionObject3D).collision_layer == PhysicsLayers.GLASS) \
			.override_failure_message("%s: no glass-only body" % g[0]).is_true()


func test_one_door_blocker_per_door_doors_open_and_the_exit_closed() -> void:
	var blockers := {}
	for body in _bodies(_level):
		if body.has_meta(&"passage"):
			var id: StringName = body.get_meta(&"passage")
			assert_int(body.collision_layer).is_equal(PhysicsLayers.DOORS)
			assert_bool(blockers.has(id)).override_failure_message("two blockers for %s" % id).is_false()
			blockers[id] = body
	for p in _map.passages:
		var want := p.is_door() or p.kind == MapPassage.EXIT
		assert_bool(blockers.has(p.id)).override_failure_message(String(p.id)).is_equal(want)
		if want:
			var shape := (blockers[p.id] as Node).get_node("Shape") as CollisionShape3D
			# Doors start open (the door owner closes them); exit E stays closed until activation (AC 10).
			assert_bool(shape.disabled).override_failure_message(String(p.id)).is_equal(p.kind != MapPassage.EXIT)


# --- AC3 ----------------------------------------------------------------------

func test_sight_rays_stop_at_three_named_los_blockers() -> void:
	var cases := [
		["BlockerCore", Vector3(28.0, EYE_Y, 23.0), Vector3(39.0, EYE_Y, 23.0)],
		["BlockerRackWest", Vector3(26.5, EYE_Y, 12.5), Vector3(26.5, EYE_Y, 18.0)],
		["BlockerRackEast", Vector3(36.0, EYE_Y, 12.5), Vector3(36.0, EYE_Y, 18.0)],
	]
	for c in cases:
		var hit := _ray(c[1], c[2], PhysicsLayers.SIGHT)
		assert_bool(not hit.is_empty() and (hit.collider as Node).name == c[0]).override_failure_message("SIGHT ray did not stop at %s" % c[0]).is_true()


func test_blockers_leave_every_marker_and_door_swing_clear() -> void:
	var r := _knobs.controller.player_radius_m
	for body in _bodies(_level):
		if not body.name.begins_with("Blocker"):
			continue
		var box := _world_box(body as StaticBody3D).grow(r)
		for m in _map.markers:
			var at := Vector3(m.position.x, box.get_center().y, m.position.z)
			assert_bool(box.has_point(at)).override_failure_message("%s covers marker %s" % [body.name, m.id]).is_false()
		for p in _map.passages:
			assert_bool(p.swing_box.size != Vector3.ZERO and box.intersects(p.swing_box)).override_failure_message("%s in swing of %s" % [body.name, p.id]).is_false()


# --- AC4 (geometry half; the walk-through screenshot is the other) ------------

func test_a_standing_capsule_fits_through_every_passage() -> void:
	var cap := CapsuleShape3D.new()
	cap.radius = _knobs.controller.player_radius_m
	cap.height = _knobs.controller.capsule_height_m
	for p in _map.passages:
		if p.kind == MapPassage.EXIT:
			continue ## closed until activation
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.GLASS ## doors start open
		q.transform = Transform3D(Basis(), Vector3(p.position.x, cap.height / 2.0 + 0.01, p.position.z))
		var hits := _space().intersect_shape(q, 4)
		assert_array(hits).override_failure_message("%s blocked by %s" % [p.id, hits.map(func(h: Dictionary) -> String: return (h.collider as Node).name)]).is_empty()


# --- FM-1 AC2 (geometry node count half) ---------------------------------------

func test_geometry_node_count_is_identical_across_loads() -> void:
	var counts: Array[int] = []
	for i in LOADS:
		var n: Node = load(SCENE).instantiate()
		counts.append(n.find_children("*", "", true, false).size())
		n.free()
	assert_int(counts.min()).is_equal(counts.max())
	assert_int(counts[0]).is_greater(0)
