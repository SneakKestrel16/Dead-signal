extends SceneTree
## One-off generator: data/maps/research_facility.tres -> assets/levels/research_facility.tscn (facility-map
## story 002). Provenance tool, not a pipeline, like sketch_to_map.py: from now on the scene is the authored
## greybox; edit it in the editor and do not re-run this over hand edits.
## Usage: <godot> --headless --path . -s res://tools/level/greybox_from_map.gd
##
## What it builds (research-facility.md Dimensions and Traversal, ADR-0007 §4-5):
## - One floor box under the whole map, top at y = 0 (large boxes, no seams).
## - Walls on every volume edge, 0.2 m thick and centred on the edge line, except between two volumes of
##   the same room (corridor and spine segments). Every passage cuts a gap of its width_m. Walls are
##   as tall as the taller neighbour (3 m, B1 6 m).
## - Glass partitions where the level doc draws `:` between two rooms (GLASS_ROOMS), on the glass layer only.
## - One StaticBody3D blocker per door, barricadable door and the exit, on the doors layer. Doors start
##   open (shape disabled); the exit starts closed (Exit gating AC 10). The door owner toggles them.
## - LOS blockers the doc names (BLOCKERS) on world: The Core and the rack lanes in B1, the breaker wall
##   in B2. Their sizes and positions are inference read off the sketch; the level designer settles them.
## No steps or ramps: the doc says the map has no jumps and no drops, and the sketch draws no level change.
## Every collider gets a box mesh so the greybox can be walked and screenshotted.

const MAP_PATH := "res://data/maps/research_facility.tres"
const OUT := "res://assets/levels/research_facility.tscn"
const WALL_T := 0.2
const DOOR_LEAF_T := 0.1
## Door leaf height: inference, as in sketch_to_map.py (DOOR_H).
const DOOR_H := 2.0
const FLOOR_T := 1.0
const EPS := 1e-4
## Room pairs separated by a glass partition (`:` in the Overview Map; Visibility sets "glass:" column).
const GLASS_ROOMS: Array[String] = ["A2|A3", "A2|A4", "A4|A7"]
## name, centre (x, z), size (x, y, z). Inference from the sketch (see header).
const BLOCKERS := [
	["Core", Vector2(33.5, 23.0), Vector3(2.5, 6.0, 2.5)],
	["RackWest", Vector2(26.5, 15.0), Vector3(5.0, 2.2, 1.0)],
	["RackEast", Vector2(36.0, 15.0), Vector3(4.0, 2.2, 1.0)],
	["BreakerWall", Vector2(35.5, 4.4), Vector3(5.0, 2.5, 0.4)],
]

var _root: Node3D
var _mats := {}


func _initialize() -> void:
	var map := MapData.load_map(MAP_PATH)
	var errs := map.errors()
	if not errs.is_empty():
		push_error("map has errors: %s" % ", ".join(errs))
		quit(1)
		return
	_root = Node3D.new()
	_root.name = "ResearchFacility"
	_build_floor(map)
	_build_walls(map)
	_build_doors(map)
	for b in BLOCKERS:
		var size: Vector3 = b[2]
		_box("Blocker" + b[0], Vector3(b[1].x, size.y / 2.0, b[1].y), size, PhysicsLayers.WORLD, Color(0.45, 0.35, 0.25))
	var scene := PackedScene.new()
	scene.pack(_root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var err := ResourceSaver.save(scene, OUT)
	print("greybox: %d nodes -> %s (%s)" % [_count(_root), OUT, error_string(err)])
	_root.free()
	quit(0 if err == OK else 1)


func _count(n: Node) -> int:
	var c := 1
	for k in n.get_children():
		c += _count(k)
	return c


func _build_floor(map: MapData) -> void:
	var bounds := map.volumes[0].box
	for v in map.volumes:
		bounds = bounds.merge(v.box)
	var size := Vector3(bounds.size.x, FLOOR_T, bounds.size.z)
	_box("Floor", Vector3(bounds.get_center().x, -FLOOR_T / 2.0, bounds.get_center().z), size, PhysicsLayers.WORLD, Color(0.3, 0.3, 0.32))


## Walls on every edge line. A line is split at every volume and passage boundary; each piece is a wall,
## glass or nothing by the rooms on its two sides, then runs of the same kind are merged into one box.
func _build_walls(map: MapData) -> void:
	for axis in ["x", "z"]: ## "x": vertical lines x = c (walls run along z); "z": horizontal lines z = c
		var lines := {}
		for v in map.volumes:
			var lo := v.box.position.x if axis == "x" else v.box.position.z
			var hi := v.box.end.x if axis == "x" else v.box.end.z
			lines[snappedf(lo, EPS)] = true
			lines[snappedf(hi, EPS)] = true
		for c: float in lines:
			_build_line(map, axis, c)


func _build_line(map: MapData, axis: String, c: float) -> void:
	var cuts: Array[float] = []
	var touching: Array[MapVolume] = []
	for v in map.volumes:
		var lo := v.box.position.x if axis == "x" else v.box.position.z
		var hi := v.box.end.x if axis == "x" else v.box.end.z
		if absf(lo - c) < EPS or absf(hi - c) < EPS:
			touching.append(v)
			cuts.append(_along_lo(v, axis))
			cuts.append(_along_hi(v, axis))
	var gaps: Array[Vector2] = []
	for p in map.passages:
		if absf((p.position.x if axis == "x" else p.position.z) - c) < EPS:
			var mid := p.position.z if axis == "x" else p.position.x
			gaps.append(Vector2(mid - p.width_m / 2.0, mid + p.width_m / 2.0))
			cuts.append(mid - p.width_m / 2.0)
			cuts.append(mid + p.width_m / 2.0)
	cuts.sort()
	var run_kind := ""
	var run_start := 0.0
	var run_h := 0.0
	for i in cuts.size() - 1:
		var a := cuts[i]
		var b := cuts[i + 1]
		if b - a < EPS:
			continue
		var m := (a + b) / 2.0
		var kind := ""
		var h := 0.0
		if not _in_gap(gaps, m):
			var sides := _sides(touching, axis, c, m)
			kind = _kind(sides)
			for v: MapVolume in sides:
				if v != null:
					h = maxf(h, v.box.size.y)
		if kind != run_kind or (kind != "" and absf(h - run_h) > EPS):
			_emit(axis, c, run_kind, run_start, a, run_h)
			run_start = a
			run_kind = kind
			run_h = h
	if cuts.size() > 0:
		_emit(axis, c, run_kind, run_start, cuts[cuts.size() - 1], run_h)


func _in_gap(gaps: Array[Vector2], m: float) -> bool:
	for g in gaps:
		if m > g.x and m < g.y:
			return true
	return false


## [volume on the low side of the line, volume on the high side], either null, covering `m` along it.
func _sides(touching: Array[MapVolume], axis: String, c: float, m: float) -> Array:
	var low: MapVolume = null
	var high: MapVolume = null
	for v in touching:
		if m <= _along_lo(v, axis) or m >= _along_hi(v, axis):
			continue
		var hi := v.box.end.x if axis == "x" else v.box.end.z
		if absf(hi - c) < EPS:
			low = v
		else:
			high = v
	return [low, high]


func _kind(sides: Array) -> String:
	var low: MapVolume = sides[0]
	var high: MapVolume = sides[1]
	if low == null and high == null:
		return ""
	if low != null and high != null:
		if low.room == high.room:
			return ""
		if ("%s|%s" % [low.room, high.room]) in GLASS_ROOMS or ("%s|%s" % [high.room, low.room]) in GLASS_ROOMS:
			return "glass"
	return "wall"


func _along_lo(v: MapVolume, axis: String) -> float:
	return v.box.position.z if axis == "x" else v.box.position.x


func _along_hi(v: MapVolume, axis: String) -> float:
	return v.box.end.z if axis == "x" else v.box.end.x


func _emit(axis: String, c: float, kind: String, a: float, b: float, h: float) -> void:
	if kind == "" or b - a < EPS:
		return
	var mid := (a + b) / 2.0
	var centre := Vector3(c, h / 2.0, mid) if axis == "x" else Vector3(mid, h / 2.0, c)
	var size := Vector3(WALL_T, h, b - a) if axis == "x" else Vector3(b - a, h, WALL_T)
	var glass := kind == "glass"
	var tag := "Glass" if glass else "Wall"
	_box("%s_%s%s_%s_%s" % [tag, axis, _n(c), _n(a), _n(b)], centre, size,
		PhysicsLayers.GLASS if glass else PhysicsLayers.WORLD,
		Color(0.55, 0.8, 0.9, 0.35) if glass else Color(0.7, 0.7, 0.68))


func _n(f: float) -> String:
	return str(snappedf(f, 0.01)).replace(".", "p")


func _build_doors(map: MapData) -> void:
	for p in map.passages:
		if not (p.is_door() or p.kind == MapPassage.EXIT):
			continue
		var vertical := _on_vertical_line(map, p)
		var size := Vector3(DOOR_LEAF_T, DOOR_H, p.width_m) if vertical else Vector3(p.width_m, DOOR_H, DOOR_LEAF_T)
		var body := _box("Door_" + String(p.id), Vector3(p.position.x, DOOR_H / 2.0, p.position.z), size,
			PhysicsLayers.DOORS, Color(0.6, 0.3, 0.2, 0.6) if p.kind == MapPassage.BARRICADABLE else Color(0.5, 0.4, 0.3, 0.6))
		body.set_meta(&"passage", p.id)
		(body.get_child(0) as CollisionShape3D).disabled = p.kind != MapPassage.EXIT ## doors open, exit closed


## A passage on a vertical line (x = const) has a volume edge at its x.
func _on_vertical_line(map: MapData, p: MapPassage) -> bool:
	for v in map.volumes:
		if absf(v.box.position.x - p.position.x) < EPS or absf(v.box.end.x - p.position.x) < EPS:
			if p.position.z >= v.box.position.z and p.position.z <= v.box.end.z:
				return true
	return false


func _box(node_name: String, centre: Vector3, size: Vector3, layer: int, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = layer
	body.collision_mask = PhysicsLayers.NONE
	body.position = centre
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _mat(color)
	mesh.mesh = bm
	body.add_child(mesh)
	_root.add_child(body)
	body.owner = _root
	cs.owner = _root
	mesh.owner = _root
	return body


func _mat(color: Color) -> StandardMaterial3D:
	if not _mats.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats[color] = m
	return _mats[color]
