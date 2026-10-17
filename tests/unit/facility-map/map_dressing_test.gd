# ASSET-028..030, 067..076 dressing (research-facility-assets.md; art bible §6): MapDressing adds room callout
# signs at doorways, the corridor floor stripes, dressing props from data/art/dressing_layout.tres, static
# decals and light fixture meshes. Everything is visual only and keeps markers, door swings and paths clear.
extends GdUnitTestSuite

const EPS := 1e-3

var _map: MapData
var _root: Node3D


func before_test() -> void:
	_map = MapData.load_map()
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	_root = MapGreybox.build(holder, _map).get_node(^"Dressing") as Node3D


func _room_box(room: StringName) -> AABB:
	var box := AABB()
	var first := true
	for v in _map.volumes:
		if v.room == room:
			box = v.box if first else box.merge(v.box)
			first = false
	return box


func test_every_room_has_a_callout_sign_showing_its_atlas_cell() -> void:
	var seen := {}
	for s in _root.get_node(^"Signs").get_children():
		var room: StringName = s.get_meta(&"room")
		seen[room] = true
		var k := MapDressing.SIGN_CELLS.find(String(room))
		assert_int(k).override_failure_message("sign for unknown room %s" % room).is_greater_equal(0)
		var mat := (s as MeshInstance3D).material_override as BaseMaterial3D
		assert_vector(mat.uv1_offset).is_equal_approx(Vector3((k % 4) * 0.25, (k / 4) * 0.125, 0.0), Vector3.ONE * EPS)
		assert_vector(mat.uv1_scale).is_equal_approx(Vector3(0.25, 0.125, 1.0), Vector3.ONE * EPS)
		## the sign hangs inside a volume of the room it names, on that room's side of the doorway
		var v := MapQueries.new(_map).volume_at((s as Node3D).position + (s as Node3D).basis.z * 0.2)
		var vol_room := &""
		for vol in _map.volumes:
			if vol.id == v:
				vol_room = vol.room
		assert_str(String(vol_room)).override_failure_message("sign %s not facing into %s" % [s.name, room]).is_not_equal(String(room))
	for r in _map.rooms():
		assert_bool(seen.has(r)).override_failure_message("no sign for room %s" % r).is_true()


func test_corridor_stripes_run_the_centrelines_in_their_materials() -> void:
	for room: StringName in [&"H-N", &"H-S"]:
		var s := _root.get_node(NodePath("Stripes/Stripe_%s" % room)) as MeshInstance3D
		var want := "mat_stripe_hn" if room == &"H-N" else "mat_stripe_hs"
		assert_str(s.material_override.resource_path).contains(want)
		var box := _room_box(room)
		var aabb := s.get_aabb()
		assert_float(s.position.z + aabb.get_center().z).is_equal_approx(box.get_center().z, EPS)
		assert_float(aabb.size.x).is_equal_approx(box.size.x, EPS)
		assert_float(s.position.y + aabb.position.y).is_greater(0.0)


## --- dressing props (ASSET-067..069, data/art/dressing_layout.tres) -------------------------------------

## Art bible §6 prop density table, max props per 10 m^2 (A1, A2 and the corridors have their own rows).
const DENSITY_MAX: Dictionary[StringName, float] = {&"A": 6.0, &"A1": 2.0, &"A2": 1.0, &"B": 3.0, &"C": 2.0,
	&"link": 1.0}
## Clearances, m: a 1.2 m path between doorways (half each side), every marker's interaction footprint
## (inference: a 1.0 m band around a marker; playtest settles it), a capsule radius (0.3) around each door
## swing, and how far props over 1.0 m stay from doors, hides and the exit (art bible §6 "props at 1.0 m and
## below leave door swing areas, hide points and exits clear"; the distance is inference).
const PATH_HALF_M := 0.6
const MARKER_CLEAR_M := 1.0
const SWING_PAD_M := 0.3
const LOW_M := 1.0
const NEAR_M := 1.5
const EJECT_M := 0.6 ## data/knobs/defense.tres hide_eject_offset_m
const NUDGE_M := 0.5 ## doorway point set this far into the room
const CYAN := Color("3FA9D6")
const EXIT_GREEN := Color("4FD18B")


func _props() -> Array[Node3D]:
	var out: Array[Node3D] = []
	out.assign(_root.get_node(^"Props").get_children())
	return out


## World AABB of every mesh under `n`.
func _footprint(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Distance in the floor plane from point `p` to footprint `b`.
func _dist(b: AABB, p: Vector3) -> float:
	var dx := maxf(0.0, maxf(b.position.x - p.x, p.x - b.end.x))
	var dz := maxf(0.0, maxf(b.position.z - p.z, p.z - b.end.z))
	return Vector2(dx, dz).length()


## Floor-plane distance from segment a-b to footprint `fp` (sampled every 5 cm: close enough for a 0.6 m bound).
func _seg_dist(fp: AABB, a: Vector3, b: Vector3) -> float:
	var n := maxi(1, ceili(a.distance_to(b) / 0.05))
	var best := INF
	for i in n + 1:
		best = minf(best, _dist(fp, a.lerp(b, float(i) / n)))
	return best


func _flat_overlap(a: AABB, b: AABB, pad: float) -> bool:
	return a.position.x < b.end.x + pad and b.position.x < a.end.x + pad \
			and a.position.z < b.end.z + pad and b.position.z < a.end.z + pad


func _room_at(p: Vector3) -> StringName:
	var id := MapQueries.new(_map).volume_at(p)
	for v in _map.volumes:
		if v.id == id:
			return v.room
	return &""


## Doorway points of `room`: each passage opening nudged into the room.
func _doorways(room: StringName) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in _map.passages:
		for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
			if _room_at(p.position + d * NUDGE_M) == room and _room_at(p.position - d * NUDGE_M) != room:
				out.append(p.position + d * NUDGE_M)
	return out


## The area kept clear at passage `p`: its swing box, or for an opening with no leaf its width a metre either
## side of the wall.
func _swing(p: MapPassage) -> AABB:
	if p.swing_box.size != Vector3.ZERO:
		return p.swing_box
	var wall_along_x := _room_at(p.position + Vector3.RIGHT * 0.3) == _room_at(p.position - Vector3.RIGHT * 0.3)
	var half := Vector3(p.width_m / 2.0, 0.0, 1.0) if wall_along_x else Vector3(1.0, 0.0, p.width_m / 2.0)
	return AABB(p.position - half, half * 2.0 + Vector3.UP * 2.0)


func test_dressing_is_placed_from_the_layout_deterministically() -> void:
	var want := (load(MapDressing.LAYOUT) as DressingLayout).placements()
	var props := _props()
	assert_int(props.size()).is_equal(want.size())
	assert_int(props.size()).is_greater(100)
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	var again := MapGreybox.build(holder, MapData.load_map()).get_node(^"Dressing/Props").get_children()
	for i in props.size():
		assert_str(String(props[i].name)).is_equal(String(again[i].name))
		assert_bool(props[i].transform.is_equal_approx((again[i] as Node3D).transform)).is_true()
		assert_bool(props[i].transform.is_equal_approx(want[i].xform)).is_true()


func test_dressing_keeps_clear_of_markers_swings_and_paths() -> void:
	var layout := load(MapDressing.LAYOUT) as DressingLayout
	var doors := {}
	for r in _map.rooms():
		doors[r] = _doorways(r)
	for n in _props():
		var fp := _footprint(n)
		var room: StringName = n.get_meta(&"room")
		for m in _map.markers:
			assert_float(_dist(fp, m.position)).override_failure_message("%s near marker %s" % [n.name, m.id]) \
					.is_greater_equal(MARKER_CLEAR_M)
			if m.type == &"hiding":
				var eject := m.position + Basis(Vector3.UP, deg_to_rad(m.yaw_deg)) * Vector3.FORWARD * EJECT_M
				assert_float(_dist(fp, eject)).override_failure_message("%s blocks %s eject" % [n.name, m.id]) \
						.is_greater_equal(MARKER_CLEAR_M)
		for p in _map.passages:
			var pad := SWING_PAD_M if p.swing_box.size != Vector3.ZERO else 0.0
			assert_bool(_flat_overlap(fp, _swing(p), pad)).override_failure_message("%s in the swing of %s" % [n.name, p.id]).is_false()
		var ds: Array[Vector3] = doors[room]
		for i in ds.size():
			for k in range(i + 1, ds.size()):
				assert_float(_seg_dist(fp, ds[i], ds[k])).override_failure_message("%s blocks the path %s-%s" % [n.name, ds[i], ds[k]]) \
						.is_greater_equal(PATH_HALF_M)
		var lines: PackedVector3Array = layout.clear_lines.get(room, PackedVector3Array())
		for i in range(0, lines.size(), 2):
			assert_float(_seg_dist(fp, lines[i], lines[i + 1])).override_failure_message("%s blocks the sightline %s-%s" % [n.name, lines[i], lines[i + 1]]) \
					.is_greater_equal(PATH_HALF_M)


func test_props_over_a_metre_stay_away_from_doors_hides_and_the_exit() -> void:
	var points: Array[Vector3] = []
	for p in _map.passages:
		points.append(p.position)
	for m in _map.markers:
		if m.type == &"hiding":
			points.append(m.position)
	var tall := 0
	for n in _props():
		var fp := _footprint(n)
		if fp.end.y <= LOW_M:
			continue
		tall += 1
		for p in points:
			assert_float(_dist(fp, p)).override_failure_message("%s (%.2f m tall) near %s" % [n.name, fp.end.y, p]) \
					.is_greater_equal(NEAR_M)
	assert_int(tall).is_greater(20)


func test_dressing_stays_in_its_room_off_blockers_and_off_other_floor_props() -> void:
	var blockers: Array[AABB] = []
	for b in _root.get_parent().find_children("Blocker*", "StaticBody3D", true, false):
		var size := ((b.get_node(^"Shape") as CollisionShape3D).shape as BoxShape3D).size
		blockers.append(AABB((b as Node3D).global_position - size / 2.0, size))
	var floor_props: Array[Node3D] = []
	for n in _props():
		var fp := _footprint(n)
		var room: StringName = n.get_meta(&"room")
		var inner := fp.grow(MapGreybox.SKIN_T - 0.02) ## off the wall skins (2 cm float slack)
		for c in [inner.position, Vector3(inner.end.x, 0, inner.position.z), Vector3(inner.position.x, 0, inner.end.z), inner.end]:
			assert_str(String(_room_at(c))).override_failure_message("%s pokes out of %s at %s" % [n.name, room, c]).is_equal(String(room))
		for b in blockers:
			assert_bool(_flat_overlap(fp, b, 0.0)).override_failure_message("%s inside a level blocker" % n.name).is_false()
		if fp.position.y < 0.05:
			for o in floor_props:
				assert_bool(_flat_overlap(fp, _footprint(o), -0.02)).override_failure_message("%s overlaps %s" % [n.name, o.name]).is_false()
			floor_props.append(n)


func test_density_never_exceeds_the_art_bible_table() -> void:
	var count: Dictionary[StringName, int] = {}
	for n in _props():
		var r: StringName = n.get_meta(&"room")
		count[r] = count.get(r, 0) + 1
	for r in _map.rooms():
		var area := 0.0
		var zone := &""
		for v in _map.volumes:
			if v.room == r:
				area += v.box.size.x * v.box.size.z
				zone = v.zone
		var cap: float = DENSITY_MAX.get(r, DENSITY_MAX[zone])
		var per10: float = count.get(r, 0) / (area / 10.0)
		assert_float(per10).override_failure_message("%s: %.2f props per 10 m^2 over %.1f" % [r, per10, cap]).is_less_equal(cap)


func test_corridor_dressing_is_wall_mounted_overhead() -> void:
	var n_corridor := 0
	for n in _props():
		if n.get_meta(&"room") in [&"H-N", &"H-S"]:
			n_corridor += 1
			assert_float(_footprint(n).position.y).override_failure_message("%s on the corridor floor" % n.name).is_greater(1.8)
	assert_int(n_corridor).is_greater(0)


func test_no_dressing_uses_objective_cyan_or_exit_green_and_none_collides() -> void:
	var meshes := _root.find_children("*", "MeshInstance3D", true, false)
	for b in _root.get_parent().find_children("BlockerRack*", "StaticBody3D", true, false):
		meshes.append_array(b.get_node(^"Prop").find_children("*", "MeshInstance3D", true, false))
	assert_int(meshes.size()).is_greater(100)
	for mi: MeshInstance3D in meshes:
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i) as BaseMaterial3D
			if mat == null:
				continue
			var cols: Array[Color] = [mat.albedo_color]
			if mat.emission_enabled:
				cols.append(mat.emission)
			for c in cols:
				for bad: Color in [CYAN, EXIT_GREEN]:
					var near := absf(c.r - bad.r) < 0.1 and absf(c.g - bad.g) < 0.1 and absf(c.b - bad.b) < 0.1
					assert_bool(near).override_failure_message("%s uses a reserved colour %s" % [mi.name, c]).is_false()
	assert_array(_root.find_children("*", "CollisionObject3D", true, false)).is_empty()


func test_b1_rack_blockers_are_dressed_as_rack_rows() -> void:
	for blocker in [&"BlockerRackWest", &"BlockerRackEast"]:
		var body := _root.get_parent().find_child(String(blocker), true, false) as StaticBody3D
		assert_bool((body.get_node(^"Mesh") as MeshInstance3D).visible).is_false()
		assert_str((body.get_node(^"Prop") as Node3D).scene_file_path).contains("prop_server_rack_row")


## --- decals (ASSET-028) ---------------------------------------------------------------------------------

func test_each_zone_has_a_handful_of_decals_in_their_rooms_on_floor_or_wall() -> void:
	var per_zone: Dictionary[StringName, int] = {}
	var decals := _root.get_node(^"Decals").get_children()
	for d: MeshInstance3D in decals:
		var room: StringName = d.get_meta(&"room")
		var cell: int = d.get_meta(&"cell")
		assert_str(String(_room_at(d.position))).override_failure_message("%s outside %s" % [d.name, room]).is_equal(String(room))
		var mat := d.material_override as BaseMaterial3D
		assert_str(mat.albedo_texture.resource_path).contains("tex_decal_set")
		assert_vector(mat.uv1_offset).is_equal_approx(Vector3((cell % 4) * 0.25, (cell / 4) * 0.25, 0.0), Vector3.ONE * EPS)
		var normal := d.global_basis.z
		if normal.y > 0.99: ## floor: above the stripes
			assert_float(d.position.y).is_greater(MapDressing.STRIPE_Y)
		else: ## wall: the room in front, a wall (not this room) just behind
			assert_float(absf(normal.y)).is_less(EPS)
			assert_str(String(_room_at(d.position + normal * 0.2))).is_equal(String(room))
			assert_str(String(_room_at(d.position - normal * 0.2))).override_failure_message("%s not on a wall" % d.name).is_not_equal(String(room))
		for v in _map.volumes:
			if v.room == room:
				per_zone[v.zone] = per_zone.get(v.zone, 0) + 1
				break
	for z: StringName in [&"A", &"B", &"C", &"link"]:
		assert_int(per_zone.get(z, 0)).override_failure_message("zone %s decals" % z).is_between(3, 10)


## --- light fixtures (ASSET-070..076) --------------------------------------------------------------------

func _fixtures(prefix: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for f in _root.get_node(^"Fixtures").get_children():
		if String(f.name).begins_with(prefix):
			out.append(f)
	return out


## True when some node in `nodes` sits at `p` in the floor plane.
func _at(nodes: Array[Node3D], p: Vector3) -> bool:
	for n in nodes:
		if Vector2(n.global_position.x - p.x, n.global_position.z - p.z).length() < EPS:
			return true
	return false


func test_fixtures_sit_where_the_lighting_presenter_puts_its_lights() -> void:
	var lights: LightingPresenter = auto_free(LightingPresenter.new(_map, LightingPresets.load_shipped()))
	add_child(lights)
	var overhead := _fixtures("Overhead_")
	var strips := _fixtures("Strip_")
	var n_lights := 0
	for v in _map.volumes:
		var vol := lights.get_node(NodePath(String(v.id)))
		for l: Node3D in vol.get_node(^"overhead").get_children():
			n_lights += 1
			assert_bool(_at(overhead, l.global_position)).override_failure_message("no fixture over %s light" % v.id).is_true()
		for o: Node3D in vol.get_node(^"emergency_strip").get_children():
			assert_bool(_at(strips, o.global_position)).override_failure_message("no strip under %s" % v.id).is_true()
	assert_int(overhead.size()).is_equal(n_lights)
	assert_int(strips.size()).is_equal(n_lights)
	for f in overhead:
		var v := _map.volumes.filter(func(x: MapVolume) -> bool: return x.contains(f.global_position))[0] as MapVolume
		assert_float(f.global_position.y).is_equal_approx(v.box.end.y, EPS)
		var want := "prop_light_cage" if v.zone in [&"B", &"C"] else "prop_light_panel"
		assert_str(String(f.get_meta(&"fixture"))).is_equal(want)


func test_each_beacon_volume_has_a_beacon_and_strobe_red_in_c4() -> void:
	var presets := LightingPresets.load_shipped()
	var beacons := _fixtures("Beacon_")
	assert_int(beacons.size()).is_equal(presets.beacon_volumes.size())
	assert_int(_fixtures("Strobe_").size()).is_equal(presets.beacon_volumes.size())
	for b in beacons:
		var want := "prop_beacon_red" if b.name == &"Beacon_C4" else "prop_beacon"
		assert_str(String(b.get_meta(&"fixture"))).is_equal(want)


# Art bible §6 wayfinding, research-facility.md Evacuation "along H-N, H-S and C2 toward C4": evacuation arrow
# plates (signage atlas row 5) on the walls of those rooms, each pointing at its room's way on toward C4.
const ARROW_TARGET: Dictionary[StringName, StringName] = {&"H-N": &"H-N-C1", &"H-S": &"C3-H-S", &"C2": &"C2-C4"}


func test_evacuation_arrows_in_h_n_h_s_and_c2_point_toward_c4() -> void:
	var per_room := {}
	for a: Node3D in _root.get_node(^"Arrows").get_children():
		var room: StringName = a.get_meta(&"room")
		var cell: int = a.get_meta(&"cell")
		per_room[room] = per_room.get(room, 0) + 1
		assert_bool(ARROW_TARGET.has(room)).override_failure_message("arrow in %s" % room).is_true()
		assert_int(cell).is_between(20, 21) ## left or right: plates on walls point along them
		var mat := (a as MeshInstance3D).material_override as BaseMaterial3D
		assert_vector(mat.uv1_offset).is_equal_approx(Vector3((cell % 4) * 0.25, (cell / 4) * 0.125, 0.0), Vector3.ONE * EPS)
		## the QuadMesh shows +X to the right of a viewer facing it, so `>` points along basis.x
		var dir := a.basis.x * (1.0 if cell == 21 else -1.0)
		var target := Vector3.ZERO
		for p in _map.passages:
			if p.id == ARROW_TARGET[room]:
				target = p.position
		assert_float(dir.dot(target - a.position)).override_failure_message("%s points away from C4" % a.name).is_greater(0.0)
		## on a wall of its room, facing into it, under the ceiling and above the doorway signs (SIGN_Y)
		var box := _room_box(room)
		assert_bool(box.grow(0.01).has_point(a.position)).override_failure_message("%s outside %s" % [a.name, room]).is_true()
		assert_bool(box.has_point(a.position + a.basis.z * 0.3)).override_failure_message("%s faces out" % a.name).is_true()
		assert_float(a.position.y).is_between(2.2, box.end.y - 0.2)
	for room in ARROW_TARGET:
		assert_int(per_room.get(room, 0)).override_failure_message("arrows in %s" % room).is_greater_equal(2)


# ASSET-062 backup controls panel (C5, research-facility.md Rooms; dressing until its function is decided) and
# ASSET-066 PA speakers (Recording scare speakers, scare-events.md rule 16) high on the walls of H-N, H-S and C2.
func test_c5_has_the_backup_panel_and_pa_speakers_hang_high_facing_into_their_rooms() -> void:
	var panels: Array[StringName] = []
	var speakers: Array[StringName] = []
	for n in _props():
		var item: StringName = n.get_meta(&"item")
		var room: StringName = n.get_meta(&"room")
		if item == &"backup_panel":
			panels.append(room)
		elif item == &"pa_speaker":
			speakers.append(room)
			assert_float(n.position.y).is_greater(2.0)
		else:
			continue
		## front (-Z of the prop, MapMarker yaw convention) faces into the room
		assert_bool(_room_box(room).has_point(n.position - n.basis.z * 1.0 + Vector3.UP * 0.1)) \
				.override_failure_message("%s faces out of %s" % [n.name, room]).is_true()
	assert_array(panels).contains_exactly([&"C5"])
	assert_array(speakers).contains_exactly_in_any_order([&"H-N", &"H-S", &"C2"])


# The wall pipe run (tools/art/build_dressing.py cooling_pipes: 3 m along the wall, pipes at 2.2-2.6 m) hid three
# evacuation arrows and the H-N PA speaker hung inside one: nothing else on a wall may sit in a run's band.
const PIPE_HALF_RUN_M := 1.5
const PIPE_BAND := Vector2(2.2, 2.6)
const WALL_CLEAR_M := 0.35


func test_arrows_and_pa_speakers_hang_clear_of_wall_pipes() -> void:
	var hung: Array[Node3D] = []
	hung.append_array(_root.get_node(^"Arrows").get_children())
	for n in _props():
		if n.get_meta(&"item") == &"pa_speaker":
			hung.append(n)
	for pipe in _props():
		if pipe.get_meta(&"item") != &"pipes":
			continue
		for n in hung:
			var d := n.position - pipe.position
			var on_wall := absf(d.dot(pipe.basis.z)) < 0.5
			var in_run := absf(d.dot(pipe.basis.x)) < PIPE_HALF_RUN_M + WALL_CLEAR_M
			var in_band := n.position.y > PIPE_BAND.x - WALL_CLEAR_M and n.position.y < PIPE_BAND.y + WALL_CLEAR_M
			assert_bool(on_wall and in_run and in_band) 					.override_failure_message("%s behind %s" % [n.name, pipe.name]).is_false()

