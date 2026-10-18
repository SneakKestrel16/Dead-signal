class_name MapClutter extends RefCounted
## Clutter of the loaded map, built by MapDressing under "Dressing" as child "Clutter" after the props, signs,
## arrows and decals (designer 2026-10-17: "facility needs more detail"; items tools/art/build_dressing.py
## clutter set):
## - Wall items (extinguisher, junction box, low vent, notice board) in the bays between MapTrim's pilasters,
##   picked per bay from a hash of the wall skin and bay, about half the bays filled.
## - Floor clutter (crates, drums, archive boxes) in room corners whose two walls are whole, outside corridors.
## A candidate is dropped when it would sit within CLEAR_M of a passage or marker (and a hide's eject point),
## block the PATH_HALF_M lane between two doorways of its room, overlap a prop, sign, arrow, wall decal, marker
## prop or level blocker, or poke out of its room. The same rules as the hand-placed dressing
## (map_dressing_test); distances are inference, playtest settles them.
## Deterministic: same map, same clutter. Visual only: no collision, nothing gameplay reads.
## Usage: `MapClutter.build(dressing_root, greybox_root, map, queries)` after the rest of the dressing.

const DIR := "res://assets/art/props/dressing/"
const WALL_ITEMS: Array[String] = ["prop_clutter_extinguisher", "prop_clutter_junction_box", "prop_clutter_vent",
		"prop_clutter_notice_board"]
const FLOOR_ITEMS: Array[String] = ["prop_clutter_crates", "prop_clutter_drums", "prop_clutter_boxes"]
## Of every 10 hash buckets: wall bays filled, corners filled (inference: about half; playtest settles it).
const WALL_FILL := 5
const FLOOR_FILL := 9
const CLEAR_M := 1.6 ## covers map_dressing_test's 1.0 m marker band and 1.5 m tall-prop gap from doors and hides
const PATH_HALF_M := 0.6
const NUDGE_M := 0.5 ## a doorway point set this far into its room (as map_dressing_test)
const EJECT_M := 0.6 ## data/knobs/defense.tres hide_eject_offset_m
const BAY_MIN_M := 1.2
const CORNER_IN_M := 0.12 ## off the wall centreline: the skin is 0.1 m
const NO_FLOOR_CLUTTER: Array[StringName] = [&"link"]
const SMALL_RANGE_M := 15.0 ## MapDressing.SMALL_RANGE_M: every clutter item is small


## Adds the clutter under `parent`; returns the "Clutter" node.
static func build(parent: Node3D, greybox: Node3D, map: MapData, queries: MapQueries) -> Node3D:
	var out := Node3D.new()
	out.name = &"Clutter"
	parent.add_child(out)
	var taken: Array[AABB] = []
	for path in [^"Props", ^"Signs", ^"Arrows", ^"Decals"]:
		var n := parent.get_node_or_null(path)
		if n != null:
			for c in n.get_children():
				taken.append(_footprint(greybox, c as Node3D))
	for c in greybox.get_children():
		if String(c.name).begins_with("Prop_"):
			taken.append(_footprint(greybox, c as Node3D))
	for b in greybox.find_children("Blocker*", "StaticBody3D", true, false): ## LOS blockers: their shapes
		var size := ((b.get_node(^"Shape") as CollisionShape3D).shape as BoxShape3D).size
		taken.append(AABB(_footprint_xform(greybox, b as Node3D).origin - size / 2.0, size))
	var keep := _keep_out(map, queries)
	var scenes := {}
	var zones := {}
	for v in map.volumes:
		zones[v.id] = v
	var skins: Array[MeshInstance3D] = []
	for c in greybox.get_children():
		if c is MeshInstance3D and c.get_meta(&"surface", &"") == &"wall":
			skins.append(c)
	for skin in skins:
		_wall_bays(out, greybox, skin, zones[skin.get_meta(&"volume")], map, queries, keep, taken, scenes)
	for v in map.volumes:
		if v.zone not in NO_FLOOR_CLUTTER:
			_corners(out, greybox, v, skins, map, queries, keep, taken, scenes)
	return out


## Points (with clear radii) and doorway lanes per room that clutter keeps off.
static func _keep_out(map: MapData, queries: MapQueries) -> Dictionary:
	var points: Array[Vector3] = []
	for p in map.passages:
		points.append(p.position)
	for m in map.markers:
		points.append(m.position)
		if m.type == &"hiding" and not is_nan(m.yaw_deg):
			points.append(m.position + Basis(Vector3.UP, deg_to_rad(m.yaw_deg)) * Vector3.FORWARD * EJECT_M)
	var lanes := {}
	for r in map.rooms():
		var doors: Array[Vector3] = []
		for p in map.passages:
			for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
				if _room_at(map, queries, p.position + d * NUDGE_M) == r and _room_at(map, queries, p.position - d * NUDGE_M) != r:
					doors.append(p.position + d * NUDGE_M)
		var segs: Array[Vector3] = []
		for i in doors.size():
			for k in range(i + 1, doors.size()):
				segs.append_array([doors[i], doors[k]])
		lanes[r] = segs
	return {&"points": points, &"lanes": lanes}


static func _wall_bays(out: Node3D, greybox: Node3D, skin: MeshInstance3D, v: MapVolume, map: MapData,
		queries: MapQueries, keep: Dictionary, taken: Array[AABB], scenes: Dictionary) -> void:
	var size := (skin.mesh as BoxMesh).size
	var side := String(skin.get_meta(&"side"))
	var axis := 0 if side[0] == "x" else 2
	var along := 2 if axis == 0 else 0
	var inward := -1.0 if side[1] == "+" else 1.0
	var n := Vector3.ZERO
	n[axis] = inward
	var lo: float = skin.position[along] - size[along] / 2.0
	var hi: float = skin.position[along] + size[along] / 2.0
	var count := maxi(1, roundi((hi - lo) / MapTrim.RIB_EVERY_M))
	var bay := (hi - lo) / count
	if bay < BAY_MIN_M:
		return
	for i in count:
		var h := ("%s:%d" % [skin.name, i]).hash()
		if absi(h) % 10 >= WALL_FILL:
			continue
		var at := skin.position
		at[axis] += inward * size[axis] / 2.0 + n[axis] * MapTrim.KICK.y
		at[along] = lo + bay * (i + 0.5)
		at.y = skin.position.y - size.y / 2.0
		var item := WALL_ITEMS[(absi(h) / 10) % WALL_ITEMS.size()]
		_try(out, greybox, item, at, atan2(n.x, n.z) + PI, v.room, map, queries, keep, taken, scenes)


static func _corners(out: Node3D, greybox: Node3D, v: MapVolume, skins: Array[MeshInstance3D], map: MapData,
		queries: MapQueries, keep: Dictionary, taken: Array[AABB], scenes: Dictionary) -> void:
	for cx in [0, 1]:
		for cz in [0, 1]:
			var corner := Vector3(v.box.end.x if cx else v.box.position.x, v.box.position.y, v.box.end.z if cz else v.box.position.z)
			var ix := -1.0 if cx else 1.0 ## inward along x
			var iz := -1.0 if cz else 1.0
			if not (_walled(skins, v, 0, corner, iz) and _walled(skins, v, 2, corner, ix)):
				continue
			var h := ("%s:%d%d" % [v.id, cx, cz]).hash()
			if absi(h) % 10 >= FLOOR_FILL:
				continue
			var at := corner + Vector3(ix, 0.0, iz) * CORNER_IN_M
			## the item grows along its local +X and -Z (Blender +X, +Y): turn so both point into the room
			var yaw := 0.0
			for k in 4:
				var b := Basis(Vector3.UP, k * PI / 2.0)
				var x := b * Vector3.RIGHT
				var f := b * Vector3.FORWARD
				if x.x * ix + x.z * iz > 0.5 and f.x * ix + f.z * iz > 0.5:
					yaw = k * PI / 2.0
			var item := FLOOR_ITEMS[(absi(h) / 10) % FLOOR_ITEMS.size()]
			_try(out, greybox, item, at, yaw, v.room, map, queries, keep, taken, scenes)


## True when volume `v`'s edge on axis `axis` through `corner` is a whole wall for the 1.4 m from the corner
## inward (direction `inward` along the other axis).
static func _walled(skins: Array[MeshInstance3D], v: MapVolume, axis: int, corner: Vector3, inward: float) -> bool:
	var along := 2 if axis == 0 else 0
	var a: float = corner[along]
	var b: float = a + inward * 1.4
	for s in skins:
		if s.get_meta(&"volume") != v.id or String(s.get_meta(&"side"))[0] != ("x" if axis == 0 else "z"):
			continue
		if absf(s.position[axis] - corner[axis]) > MapGreybox.SKIN_T:
			continue
		var size := (s.mesh as BoxMesh).size
		var lo: float = s.position[along] - size[along] / 2.0
		var hi: float = s.position[along] + size[along] / 2.0
		if lo <= minf(a, b) + 1e-3 and hi >= maxf(a, b) - 1e-3:
			return true
	return false


## Places `item` at `at` facing `yaw` unless its footprint breaks a keep-out rule.
static func _try(out: Node3D, greybox: Node3D, item: String, at: Vector3, yaw: float, room: StringName,
		map: MapData, queries: MapQueries, keep: Dictionary, taken: Array[AABB], scenes: Dictionary) -> void:
	if not scenes.has(item):
		scenes[item] = load(DIR + item + ".glb")
	var n := (scenes[item] as PackedScene).instantiate() as Node3D
	n.position = at
	n.rotation.y = yaw
	out.add_child(n)
	var fp := _footprint(greybox, n)
	var ok := true
	for p: Vector3 in keep[&"points"]:
		ok = ok and _dist(fp, p) >= CLEAR_M
	var lanes: Array[Vector3] = keep[&"lanes"].get(room, [] as Array[Vector3])
	for i in range(0, lanes.size(), 2):
		ok = ok and _seg_dist(fp, lanes[i], lanes[i + 1]) >= PATH_HALF_M
	for t in taken:
		ok = ok and not _flat_overlap(fp, t)
	var inner := fp.grow(-0.02)
	for c in [inner.position, Vector3(inner.end.x, 0, inner.position.z), Vector3(inner.position.x, 0, inner.end.z), inner.end]:
		ok = ok and _room_at(map, queries, c) == room
	if not ok:
		n.free()
		return
	taken.append(fp)
	n.name = "Clutter_%s_%d" % [room, out.get_child_count()]
	n.set_meta(&"room", room)
	n.set_meta(&"item", StringName(item))
	for gi: GeometryInstance3D in n.find_children("*", "GeometryInstance3D", true, false):
		gi.visibility_range_end = SMALL_RANGE_M


## AABB of every mesh under `n`, in `root`'s space (works before the tree is entered).
static func _footprint(root: Node3D, n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var meshes: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		meshes.append(n)
	for mi: MeshInstance3D in meshes:
		var b := _footprint_xform(root, mi) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## `n`'s transform in `root`'s space.
static func _footprint_xform(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != root:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


static func _dist(b: AABB, p: Vector3) -> float:
	var dx := maxf(0.0, maxf(b.position.x - p.x, p.x - b.end.x))
	var dz := maxf(0.0, maxf(b.position.z - p.z, p.z - b.end.z))
	return Vector2(dx, dz).length()


static func _seg_dist(fp: AABB, a: Vector3, b: Vector3) -> float:
	var steps := maxi(1, ceili(a.distance_to(b) / 0.05))
	var best := INF
	for i in steps + 1:
		best = minf(best, _dist(fp, a.lerp(b, float(i) / steps)))
	return best


static func _flat_overlap(a: AABB, b: AABB) -> bool:
	return a.position.x < b.end.x and b.position.x < a.end.x and a.position.z < b.end.z and b.position.z < a.end.z


static func _room_at(map: MapData, queries: MapQueries, p: Vector3) -> StringName:
	var id := queries.volume_at(p)
	for v in map.volumes:
		if v.id == id:
			return v.room
	return &""
