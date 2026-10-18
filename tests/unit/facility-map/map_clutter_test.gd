# Facility detail pass (designer 2026-10-17, "facility needs more detail"): MapClutter adds wall items between
# the pilasters and floor clutter in room corners, by rule. It must keep the hand-placed dressing's rules
# (map_dressing_test): off markers, hide eject points, door swings and doorway lanes, off other dressing, and
# inside its room.
extends GdUnitTestSuite

const MARKER_CLEAR_M := 1.0 ## map_dressing_test MARKER_CLEAR_M
const NEAR_M := 1.5 ## map_dressing_test NEAR_M: anything over LOW_M stays this far from doors and hides
const LOW_M := 1.0
const PATH_HALF_M := 0.6
const NUDGE_M := 0.5
const EJECT_M := 0.6

var _map: MapData
var _dressing: Node3D


func before_test() -> void:
	_map = MapData.load_map()
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	_dressing = MapGreybox.build(holder, _map).get_node(^"Dressing") as Node3D


func _clutter() -> Array[Node3D]:
	var out: Array[Node3D] = []
	out.assign(_dressing.get_node(^"Clutter").get_children())
	return out


func _footprint(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _dist(b: AABB, p: Vector3) -> float:
	var dx := maxf(0.0, maxf(b.position.x - p.x, p.x - b.end.x))
	var dz := maxf(0.0, maxf(b.position.z - p.z, p.z - b.end.z))
	return Vector2(dx, dz).length()


func _room_at(p: Vector3) -> StringName:
	var id := MapQueries.new(_map).volume_at(p)
	for v in _map.volumes:
		if v.id == id:
			return v.room
	return &""


func test_clutter_fills_walls_and_corners_of_every_zone() -> void:
	var walls := 0
	var floors := 0
	var rooms := {}
	for n in _clutter():
		var item := String(n.get_meta(&"item"))
		if item in MapClutter.WALL_ITEMS:
			walls += 1
		elif item in MapClutter.FLOOR_ITEMS:
			floors += 1
		rooms[n.get_meta(&"room")] = true
	assert_int(walls).is_greater(30)
	assert_int(floors).is_greater(8)
	assert_int(rooms.size()).is_greater(10)


func test_clutter_is_deterministic() -> void:
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	var again := MapGreybox.build(holder, MapData.load_map()).get_node(^"Dressing/Clutter").get_children()
	var first := _clutter()
	assert_int(again.size()).is_equal(first.size())
	for i in first.size():
		assert_str(String(again[i].name)).is_equal(String(first[i].name))
		assert_bool((again[i] as Node3D).transform.is_equal_approx(first[i].transform)).is_true()


func test_clutter_keeps_clear_of_markers_doors_and_lanes() -> void:
	for n in _clutter():
		var fp := _footprint(n)
		for m in _map.markers:
			assert_float(_dist(fp, m.position)).override_failure_message("%s near marker %s" % [n.name, m.id]) \
					.is_greater_equal(MARKER_CLEAR_M if fp.end.y <= LOW_M or m.type != &"hiding" else NEAR_M)
			if m.type == &"hiding":
				var eject := m.position + Basis(Vector3.UP, deg_to_rad(m.yaw_deg)) * Vector3.FORWARD * EJECT_M
				assert_float(_dist(fp, eject)).override_failure_message("%s blocks %s eject" % [n.name, m.id]) \
						.is_greater_equal(MARKER_CLEAR_M)
		for p in _map.passages:
			assert_float(_dist(fp, p.position)).override_failure_message("%s near passage %s" % [n.name, p.id]) \
					.is_greater_equal(NEAR_M)
		var room: StringName = n.get_meta(&"room")
		var doors: Array[Vector3] = []
		for p in _map.passages:
			for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
				if _room_at(p.position + d * NUDGE_M) == room and _room_at(p.position - d * NUDGE_M) != room:
					doors.append(p.position + d * NUDGE_M)
		for i in doors.size():
			for k in range(i + 1, doors.size()):
				var steps := maxi(1, ceili(doors[i].distance_to(doors[k]) / 0.05))
				for s in steps + 1:
					assert_float(_dist(fp, doors[i].lerp(doors[k], float(s) / steps))) \
							.override_failure_message("%s blocks the path %s-%s" % [n.name, doors[i], doors[k]]) \
							.is_greater_equal(PATH_HALF_M)


func test_clutter_stays_in_its_room_and_off_other_dressing() -> void:
	var others: Array[AABB] = []
	for path in [^"Props", ^"Signs", ^"Arrows"]:
		for c in _dressing.get_node(path).get_children():
			others.append(_footprint(c as Node3D))
	var placed: Array[AABB] = []
	for n in _clutter():
		var fp := _footprint(n)
		var room: StringName = n.get_meta(&"room")
		var inner := fp.grow(-0.02)
		for c in [inner.position, Vector3(inner.end.x, 0, inner.position.z), Vector3(inner.position.x, 0, inner.end.z), inner.end]:
			assert_str(String(_room_at(c))).override_failure_message("%s pokes out of %s" % [n.name, room]).is_equal(String(room))
		for o in others + placed:
			var overlap := fp.position.x < o.end.x and o.position.x < fp.end.x and fp.position.z < o.end.z and o.position.z < fp.end.z
			assert_bool(overlap).override_failure_message("%s overlaps dressing at %s" % [n.name, o]).is_false()
		placed.append(fp)
