# Facility detail pass (designer 2026-10-17, "facility needs more detail"): MapTrim adds kick plates, rails,
# pilasters, ceiling beams, doorway headers, jambs and thresholds, and corridor trays and pipes as three merged
# meshes on the trim sheets. Visual only; it must leave every doorway walkable for the 2.4 m true form and keep
# clear of the ceiling light fixtures.
extends GdUnitTestSuite

const EPS := 1e-3
const TRUE_FORM_M := 2.4

var _map: MapData
var _dressing: Node3D


func before_test() -> void:
	_map = MapData.load_map()
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	_dressing = MapGreybox.build(holder, _map).get_node(^"Dressing") as Node3D


func _vertices() -> PackedVector3Array:
	var out := PackedVector3Array()
	for mi in _dressing.get_node(^"Trim").get_children():
		out.append_array((mi as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	return out


func test_trim_is_one_mesh_per_trim_sheet() -> void:
	var paths := []
	for mi in _dressing.get_node(^"Trim").get_children():
		var m := mi as MeshInstance3D
		assert_int(m.mesh.get_surface_count()).is_equal(1)
		assert_int(m.mesh.surface_get_array_len(0)).is_greater(0)
		paths.append(m.material_override.resource_path)
	assert_array(paths).contains_exactly_in_any_order([MapTrim.METAL, MapTrim.MARKINGS, MapTrim.CONCRETE])


func test_no_trim_inside_a_doorway_below_the_header() -> void:
	var queries := MapQueries.new(_map)
	var verts := _vertices()
	for p in _map.passages:
		if p.kind not in MapTrim.DOOR_KINDS:
			continue
		var across := Vector3.RIGHT
		if queries.volume_at(p.position + Vector3(0.3, 0.5, 0.0)) == queries.volume_at(p.position + Vector3(-0.3, 0.5, 0.0)):
			across = Vector3.BACK
		var along := Vector3(across.z, 0.0, across.x)
		## the clear opening: an opening at a room's corner counts the meeting wall's half-thickness in its width,
		## and that wall's face keeps its own kick plate and rail (A1-H-S)
		var half := across.abs() * MapGreybox.SKIN_T + along.abs() * (p.width_m / 2.0 - MapGreybox.SKIN_T - MapTrim.RIB.y)
		var y0 := MapTrim.THRESHOLD_Y + EPS
		var y1 := MapTrim.DOOR_HEAD_M - 0.1 - EPS
		var lane := AABB(p.position - Vector3(half.x, 0.0, half.z) + Vector3.UP * y0, Vector3(half.x * 2.0, y1 - y0, half.z * 2.0))
		for i in range(0, verts.size(), 3): ## each triangle's bounds: a box spans the lane with its corners outside it
			var tri := AABB(verts[i], Vector3.ZERO).expand(verts[i + 1]).expand(verts[i + 2])
			assert_bool(tri.intersects(lane)).override_failure_message("trim triangle at %s in doorway %s" % [verts[i], p.id]).is_false()


func test_headers_clear_the_true_form() -> void:
	## the lintel trim hangs 0.1 m under DOOR_HEAD_M; the true form is about 2.4 m tall (art bible §5)
	assert_float(MapTrim.DOOR_HEAD_M - 0.1).is_greater_equal(TRUE_FORM_M)


func test_beams_stay_clear_of_ceiling_fixtures() -> void:
	var verts := _vertices()
	for f in _dressing.get_node(^"Fixtures").get_children():
		if not String(f.name).begins_with("Overhead_"):
			continue
		var at := (f as Node3D).position
		for v in verts:
			var near := Vector2(v.x - at.x, v.z - at.z).length() < 0.5 and v.y > at.y - 0.3 and v.y < at.y + EPS
			assert_bool(near).override_failure_message("trim at %s over fixture %s" % [v, f.name]).is_false()
