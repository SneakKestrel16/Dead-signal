# AD-249: the runtime level geometry (MapGreybox.build) the host and every client stand in: walls on every
# volume side, open passages, glass where the level doc draws it, zone surface materials, the same build
# every time, and no marker or passage centre inside a wall.
extends GdUnitTestSuite

const PROBE_Y := 1.0 ## waist height, under the door lintel
const EYE_Y := 1.6
const EPS := 1e-3
## Room pairs the level doc draws glass between (`:` in the Overview Map): a point on the partition clear of
## its door (x, z) and the direction across it. Same probes as tests/integration/facility-map/greybox_geometry_test.gd.
const GLASS_PROBES := [
	["A2|A3", Vector2(10.0, 24.0), Vector3.RIGHT],
	["A2|A4", Vector2(13.0, 17.0), Vector3.RIGHT],
	["A4|A7", Vector2(18.0, 14.0), Vector3.BACK],
]

var _map: MapData
var _knobs: Knobs
var _mats: SurfaceMaterials
var _root: Node3D


func before_test() -> void:
	_map = MapData.load_map()
	_knobs = Knobs.load_all()
	_mats = load(MapGreybox.SURFACES) as SurfaceMaterials
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	_root = MapGreybox.build(holder, _map)
	await get_tree().physics_frame
	await get_tree().physics_frame


func _ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	return _root.get_world_3d().direct_space_state.intersect_ray(q)


func _skins() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in _root.find_children("Skin_*", "MeshInstance3D", true, false):
		out.append(n)
	return out


## A passage on a vertical line (x = const) has a volume edge at its x (tools/level/greybox_from_map.gd).
func _on_vertical_line(p: MapPassage) -> bool:
	for v in _map.volumes:
		if absf(v.box.position.x - p.position.x) < EPS or absf(v.box.end.x - p.position.x) < EPS:
			if p.position.z >= v.box.position.z and p.position.z <= v.box.end.z:
				return true
	return false


## Length of `v`'s side `axis`/`high` that needs no wall skin: shared with a volume of the same room, cut by a
## passage on that line, or a glass partition of the authored scene.
func _covered(v: MapVolume, axis: int, high: bool) -> float:
	var along := 2 if axis == 0 else 0
	var c: float = v.box.end[axis] if high else v.box.position[axis]
	var lo: float = v.box.position[along]
	var hi: float = v.box.end[along]
	var spans: Array[Vector2] = []
	for o in _map.volumes:
		var oc: float = o.box.position[axis] if high else o.box.end[axis]
		if o != v and o.room == v.room and absf(oc - c) < EPS:
			spans.append(Vector2(o.box.position[along], o.box.end[along]))
	for p in _map.passages:
		if absf(p.position[axis] - c) < EPS:
			spans.append(Vector2(p.position[along] - p.width_m / 2.0, p.position[along] + p.width_m / 2.0))
	for g: Node3D in _root.find_children("Glass_*", "StaticBody3D", true, false):
		var size: Vector3 = ((g.get_node("Shape") as CollisionShape3D).shape as BoxShape3D).size
		if absf(g.position[axis] - c) < EPS and size[axis] < size[along]:
			spans.append(Vector2(g.position[along] - size[along] / 2.0, g.position[along] + size[along] / 2.0))
	var cover := 0.0
	for s in spans:
		cover += maxf(0.0, minf(hi, s.y) - maxf(lo, s.x))
	return cover


func test_every_volume_side_has_a_wall_unless_it_opens_into_its_own_room() -> void:
	var have := {}
	for s in _skins():
		have["%s|%s" % [s.get_meta(&"volume"), s.get_meta(&"side")]] = true
	for v in _map.volumes:
		for axis in [0, 2]:
			for high in [false, true]:
				var side := "%s%s" % ["x" if axis == 0 else "z", "+" if high else "-"]
				var along := 2 if axis == 0 else 0
				var open := _covered(v, axis, high) >= v.box.size[along] - EPS
				assert_bool(have.has("%s|%s" % [v.id, side]) or open) \
					.override_failure_message("%s side %s has no wall" % [v.id, side]).is_true()


func test_a_ray_across_every_wall_skin_hits_world() -> void:
	assert_int(_skins().size()).is_greater(0)
	for s in _skins():
		var n := Vector3.RIGHT if String(s.get_meta(&"side")).begins_with("x") else Vector3.BACK
		var c := Vector3(s.position.x, PROBE_Y, s.position.z)
		var hit := _ray(c - n * 0.5, c + n * 0.5, PhysicsLayers.WORLD)
		assert_bool(not hit.is_empty()).override_failure_message("%s: no WORLD collider" % s.name).is_true()


## BUG-0018: the exit's blocker stays closed until Exit Open (research-facility.md AC 10); doors start open.
func test_a_ray_through_every_passage_at_1_m_is_clear_but_the_closed_exit() -> void:
	for p in _map.passages:
		var n := Vector3.RIGHT if _on_vertical_line(p) else Vector3.BACK
		var c := Vector3(p.position.x, PROBE_Y, p.position.z)
		var hit := _ray(c - n * 0.6, c + n * 0.6, PhysicsLayers.MOVE_PREDICT)
		if p.kind == MapPassage.EXIT:
			assert_int((hit.get("collider") as CollisionObject3D).collision_layer).is_equal(PhysicsLayers.DOORS)
			continue
		assert_dict(hit).override_failure_message("%s blocked by %s" % [p.id, hit.get("collider")]).is_empty()


func test_glass_partitions_block_movement_not_sight_and_use_the_glass_material() -> void:
	for g in GLASS_PROBES:
		var at: Vector2 = g[1]
		var dir: Vector3 = g[2]
		var c := Vector3(at.x, EYE_Y, at.y)
		assert_dict(_ray(c - dir, c + dir, PhysicsLayers.SIGHT)).override_failure_message("%s: sight blocked" % g[0]).is_empty()
		var hit := _ray(c - dir, c + dir, PhysicsLayers.MOVE_SERVER)
		assert_bool(not hit.is_empty() and (hit.collider as CollisionObject3D).collision_layer == PhysicsLayers.GLASS) \
			.override_failure_message("%s: no glass" % g[0]).is_true()
		var mesh := (hit.collider as Node).get_node("Mesh") as MeshInstance3D
		assert_object(mesh.material_override).override_failure_message("%s: glass material" % g[0]).is_same(_mats.glass)


func test_every_surface_mesh_uses_a_surface_material_of_its_zone() -> void:
	var zone_of := {}
	for v in _map.volumes:
		zone_of[v.id] = v.zone
	var count := 0
	for m: MeshInstance3D in _root.find_children("*", "MeshInstance3D", true, false):
		if not m.has_meta(&"volume"):
			continue
		count += 1
		var z: StringName = zone_of[m.get_meta(&"volume")]
		var want: Material = {&"floor": _mats.floors, &"wall": _mats.walls, &"ceiling": _mats.ceilings}[m.get_meta(&"surface")][z]
		assert_object(m.material_override).override_failure_message(String(m.name)).is_same(want)
	# floor + ceiling per volume, plus the wall skins
	assert_int(count).is_greater_equal(_map.volumes.size() * 2 + _skins().size())


func test_no_marker_or_passage_centre_is_within_a_body_radius_of_a_wall() -> void:
	var cap := CapsuleShape3D.new()
	cap.radius = _knobs.controller.player_radius_m
	cap.height = _knobs.controller.capsule_height_m
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.GLASS ## walls; door and exit blockers fill their own opening
	var bad: Array[String] = []
	var points: Array = []
	for m in _map.markers:
		points.append([m.id, m.position])
	for p in _map.passages:
		points.append([p.id, p.position])
	var space := _root.get_world_3d().direct_space_state
	for pt in points:
		var at: Vector3 = pt[1]
		q.transform = Transform3D(Basis(), Vector3(at.x, cap.height / 2.0 + 0.01, at.z))
		var hits := space.intersect_shape(q, 4)
		if not hits.is_empty():
			bad.append("%s in %s" % [pt[0], ", ".join(hits.map(func(h: Dictionary) -> String: return String((h.collider as Node).name)))])
	assert_array(bad).is_empty()


func test_two_builds_produce_identical_transforms() -> void:
	var other: Node3D = auto_free(Node3D.new())
	add_child(other)
	var second := MapGreybox.build(other, _map)
	assert_array(_layout(second)).is_equal(_layout(_root))


func _layout(root: Node3D) -> Array:
	var out := []
	for n: Node3D in root.find_children("*", "Node3D", true, false):
		out.append([n.get_class(), n.transform])
	return out
