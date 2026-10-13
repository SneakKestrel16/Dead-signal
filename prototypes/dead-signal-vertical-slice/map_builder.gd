# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: does one networked greybox round deliver "you can't be sure the person next to you is a person"?
# Date: 2026-10-13
class_name MapBuilder
extends RefCounted
## Builds the Research Facility greybox from the sketch in res://data/facility.txt
## (design/levels/research-facility.md Overview Map and Placement overlay).
## One sketch column = 1 m (x), one row = 2 m (z), as the level doc states.
## Legend: + - | walls, : glass, D/B doors (barricades are out of slice scope),
## O archway, E exit. Room-name letters are told apart from doors by their neighbours.

const CELL_X := 1.0
const CELL_Z := 2.0
const WALL_H := 3.0
const THICK := 0.2
const DOOR_THICK := 0.12
const V_DOOR_W := 1.2
const H_CTX := "-+:DBOE"
const V_CTX := "|+:DBOE"

## Collision layer bits (ADR-0007 names: world, glass, doors, players).
const L_WORLD := 1
const L_GLASS := 2
const L_DOORS := 4
const L_PLAYERS := 8

var lines: PackedStringArray = []
var overlay: PackedStringArray = []
var root: Node3D
## Array of {body: StaticBody3D, mesh: MeshInstance3D, center: Vector3, size: Vector3, exit: bool}
var doors: Array = []
## token ("d1", "T2", "S1", "M3") -> Vector3 floor position
var points: Dictionary = {}
var exit_area := AABB()
var size := Vector2.ZERO

var _mat_wall: StandardMaterial3D
var _mat_glass: StandardMaterial3D
var _mat_door: StandardMaterial3D
var _mat_exit: StandardMaterial3D
var _mat_floor: StandardMaterial3D


func build(parent: Node3D) -> void:
	root = Node3D.new()
	root.name = "Facility"
	parent.add_child(root)
	var text := FileAccess.get_file_as_string("res://data/facility.txt")
	var parts := text.split("\n---\n")
	lines = parts[0].split("\n")
	overlay = parts[1].split("\n") if parts.size() > 1 else PackedStringArray()
	size = Vector2(lines[0].length() * CELL_X, lines.size() * CELL_Z)
	_materials()
	_floor_and_ceiling()
	_walls()
	_points()
	_lights()


func _ch(r: int, c: int) -> String:
	if r < 0 or r >= lines.size() or c < 0 or c >= lines[r].length():
		return " "
	return lines[r][c]


## Returns "" for open floor or a label letter, else kind + "_h"/"_v" or "post".
func cell_kind(r: int, c: int) -> String:
	var x := _ch(r, c)
	match x:
		"+":
			return "post"
		"|":
			return "wall_v"
		"-":
			return "wall_h" if (_ch(r, c - 1) in H_CTX or _ch(r, c + 1) in H_CTX) else ""
		":":
			var horiz := _ch(r, c - 1) in "-+:" or _ch(r, c + 1) in "-+:"
			return "glass_h" if horiz else "glass_v"
		"D", "B", "O", "E":
			var kind := {"D": "door", "B": "door", "O": "arch", "E": "exit"}[x] as String
			if _ch(r, c - 1) in H_CTX and _ch(r, c + 1) in H_CTX:
				return kind + "_h"
			if _ch(r - 1, c) in V_CTX and _ch(r + 1, c) in V_CTX:
				return kind + "_v"
	return ""


func _is_h(k: String) -> bool:
	return k.ends_with("_h") or k == "post"


func _is_v(k: String) -> bool:
	return k.ends_with("_v") or k == "post"


func _walls() -> void:
	var segs: Array = []  # [Vector2 a, Vector2 b, type]
	for r in lines.size():
		for c in lines[r].length():
			var k := cell_kind(r, c)
			if k == "":
				continue
			var cx := (c + 0.5) * CELL_X
			var cz := (r + 0.5) * CELL_Z
			if k == "post":
				if _is_h(cell_kind(r, c + 1)):
					segs.append([Vector2(cx, cz), Vector2((c + 1) * CELL_X, cz), "wall"])
				if _is_h(cell_kind(r, c - 1)):
					segs.append([Vector2(c * CELL_X, cz), Vector2(cx, cz), "wall"])
				if _is_v(cell_kind(r + 1, c)):
					segs.append([Vector2(cx, cz), Vector2(cx, (r + 1) * CELL_Z), "wall"])
				if _is_v(cell_kind(r - 1, c)):
					segs.append([Vector2(cx, r * CELL_Z), Vector2(cx, cz), "wall"])
				_box(Vector3(cx, WALL_H / 2.0, cz), Vector3(THICK, WALL_H, THICK), _mat_wall, L_WORLD)
				continue
			var base := k.left(k.length() - 2)
			var horizontal := k.ends_with("_h")
			var a := Vector2(c * CELL_X, cz) if horizontal else Vector2(cx, r * CELL_Z)
			var b := Vector2((c + 1) * CELL_X, cz) if horizontal else Vector2(cx, (r + 1) * CELL_Z)
			match base:
				"wall":
					segs.append([a, b, "wall"])
				"glass":
					segs.append([a, b, "glass"])
				"arch":
					pass
				"door", "exit":
					var exit := base == "exit"
					if horizontal or exit:
						_door(a, b, exit)
					else:
						var mid := (a + b) / 2.0
						var half := Vector2(0, V_DOOR_W / 2.0)
						segs.append([a, mid - half, "wall"])
						segs.append([mid + half, b, "wall"])
						_door(mid - half, mid + half, false)
	for seg in _merge(segs):
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var glass: bool = seg[2] == "glass"
		var center := Vector3((a.x + b.x) / 2.0, WALL_H / 2.0, (a.y + b.y) / 2.0)
		var sz := Vector3(maxf(absf(b.x - a.x), THICK), WALL_H, maxf(absf(b.y - a.y), THICK))
		_box(center, sz, _mat_glass if glass else _mat_wall, L_GLASS if glass else L_WORLD)


## Joins touching collinear segments of the same type into one box (fewer seams for Jolt).
func _merge(segs: Array) -> Array:
	var groups := {}
	for s in segs:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var horiz := is_equal_approx(a.y, b.y)
		var key := "%s|%s|%.2f" % [s[2], "h" if horiz else "v", a.y if horiz else a.x]
		if not groups.has(key):
			groups[key] = []
		var lo := minf(a.x, b.x) if horiz else minf(a.y, b.y)
		var hi := maxf(a.x, b.x) if horiz else maxf(a.y, b.y)
		groups[key].append([lo, hi, horiz, a.y if horiz else a.x, s[2]])
	var out: Array = []
	for key in groups:
		var g: Array = groups[key]
		g.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
		var cur: Array = g[0].duplicate()
		for k in range(1, g.size()):
			if g[k][0] <= cur[1] + 0.001:
				cur[1] = maxf(cur[1], g[k][1])
			else:
				out.append(_seg_from(cur))
				cur = g[k].duplicate()
		out.append(_seg_from(cur))
	return out


func _seg_from(m: Array) -> Array:
	if m[2]:
		return [Vector2(m[0], m[3]), Vector2(m[1], m[3]), m[4]]
	return [Vector2(m[3], m[0]), Vector2(m[3], m[1]), m[4]]


func _door(a: Vector2, b: Vector2, exit: bool) -> void:
	var center := Vector3((a.x + b.x) / 2.0, WALL_H / 2.0 - 0.25, (a.y + b.y) / 2.0)
	var sz := Vector3(maxf(absf(b.x - a.x), DOOR_THICK), WALL_H - 0.5, maxf(absf(b.y - a.y), DOOR_THICK))
	var body := _box(center, sz, _mat_exit if exit else _mat_door, L_DOORS)
	doors.append({"body": body, "center": center, "size": sz, "exit": exit})
	if exit:
		var p := Vector3(center.x + 1.5, 0.0, center.z)
		exit_area = exit_area.merge(AABB(Vector3(center.x + 0.6, 0.0, center.z - 1.2), Vector3(5.0, 3.0, 2.4))) if exit_area.size != Vector3.ZERO else AABB(Vector3(center.x + 0.6, 0.0, center.z - 1.2), Vector3(5.0, 3.0, 2.4))
		points["exit"] = p


func _floor_and_ceiling() -> void:
	_box(Vector3(size.x / 2.0, -0.1, size.y / 2.0), Vector3(size.x, 0.2, size.y), _mat_floor, L_WORLD)
	_box(Vector3(size.x / 2.0, WALL_H + 0.1, size.y / 2.0), Vector3(size.x, 0.2, size.y), _mat_wall, L_WORLD)
	# Outside pad past the exit (C4 east wall, sketch rows 9-10), walled on three sides.
	var z0 := 16.0
	var z1 := 24.0
	_box(Vector3(size.x + 3.0, -0.1, (z0 + z1) / 2.0), Vector3(6.0, 0.2, z1 - z0), _mat_floor, L_WORLD)
	_box(Vector3(size.x + 6.0, WALL_H / 2.0, (z0 + z1) / 2.0), Vector3(THICK, WALL_H, z1 - z0), _mat_wall, L_WORLD)
	_box(Vector3(size.x + 3.0, WALL_H / 2.0, z0), Vector3(6.0, WALL_H, THICK), _mat_wall, L_WORLD)
	_box(Vector3(size.x + 3.0, WALL_H / 2.0, z1), Vector3(6.0, WALL_H, THICK), _mat_wall, L_WORLD)
	# Corridor floor stripes: blue H-N (sketch row 1), orange H-S (row 19).
	_stripe(Vector3(24.0, 0.01, 3.0), Vector3(46.0, 0.02, 0.3), Color(0.15, 0.35, 0.9))
	_stripe(Vector3(35.0, 0.01, 39.0), Vector3(48.0, 0.02, 0.3), Color(0.95, 0.5, 0.1))


func _stripe(center: Vector3, sz: Vector3, color: Color) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color * 0.25
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = m
	root.add_child(mi)
	mi.position = center


func _points() -> void:
	var re := RegEx.new()
	re.compile("\\b([dTSM][1-6])\\b")
	for r in overlay.size():
		for m in re.search_all(overlay[r]):
			var c := m.get_start(1)
			points[m.get_string(1)] = Vector3((c + 1.0) * CELL_X, 0.0, (r + 0.5) * CELL_Z)


func _lights() -> void:
	for gx in range(4, int(size.x), 8):
		for gz in range(3, int(size.y), 6):
			var c := gx
			var r := int(gz / CELL_Z)
			if cell_kind(r, c) != "":
				continue
			var l := OmniLight3D.new()
			l.omni_range = 7.0
			l.light_energy = 0.22
			l.light_color = Color(0.6, 0.7, 0.85) if gx < 22 else (Color(0.9, 0.7, 0.45) if gx < 40 else Color(0.85, 0.45, 0.4))
			root.add_child(l)
			l.position = Vector3(gx + 0.5, WALL_H - 0.4, gz)


func _box(center: Vector3, sz: Vector3, mat: Material, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = sz
	shape.shape = bs
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	root.add_child(body)
	body.position = center
	return body


func _materials() -> void:
	_mat_wall = StandardMaterial3D.new()
	_mat_wall.albedo_color = Color(0.32, 0.33, 0.35)
	_mat_wall.roughness = 0.95
	_mat_floor = StandardMaterial3D.new()
	_mat_floor.albedo_color = Color(0.18, 0.18, 0.2)
	_mat_floor.roughness = 0.8
	_mat_glass = StandardMaterial3D.new()
	_mat_glass.albedo_color = Color(0.5, 0.7, 0.9, 0.12)
	_mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_glass.metallic = 0.3
	_mat_glass.roughness = 0.05
	_mat_door = StandardMaterial3D.new()
	_mat_door.albedo_color = Color(0.4, 0.27, 0.16)
	_mat_exit = StandardMaterial3D.new()
	_mat_exit.albedo_color = Color(0.6, 0.08, 0.06)
	_mat_exit.emission_enabled = true
	_mat_exit.emission = Color(0.4, 0.02, 0.02)
