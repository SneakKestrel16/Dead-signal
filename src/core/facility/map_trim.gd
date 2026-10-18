class_name MapTrim extends RefCounted
## Architectural trim of the loaded map, built by MapDressing under "Dressing" as child "Trim" (designer
## 2026-10-17: "facility needs more detail"; trim sheets assets/art/materials/README.md "Trim strip layout"):
## - Walls: a kick plate along the foot of every wall skin, a rail on top of the painted 1.2 m band (zones whose
##   walls are painted block, not B's steel), and a riveted pilaster at each end of a skin and every RIB_EVERY_M
##   between, so doorways read framed and long walls break up.
## - Ceilings: beams across each volume's shorter side on the overhead light grid's thirds, never over a cell
##   centre where LightingPresets puts the fixture.
## - Doorways (door, barricadable, archway): a header from DOOR_HEAD_M up to the lower ceiling of the two rooms,
##   closing the bare gap over the 2 m leaves, and a hazard-edge threshold on the floor.
## - Corridors (zone `link`): a cable tray along one wall and two pipes along the other, above the wall pipe
##   runs' band (map_dressing_test PIPE_BAND) and under the beams.
## One mesh per trim sheet (metal, markings, concrete), merged with SurfaceTool: three draw calls for the map.
## Visual only: no collision, nothing gameplay reads. Sizes are inference (no source gives them; playtest
## settles them), except DOOR_HEAD_M, which clears the 2.4 m true form (art bible §5).
## Usage: `MapTrim.build(dressing_root, greybox_root, map)` after MapGreybox has added the wall skins.

const METAL := "res://assets/art/materials/mat_trim_metal.tres"
const MARKINGS := "res://assets/art/materials/mat_trim_markings.tres"
const CONCRETE := "res://assets/art/materials/mat_trim_concrete.tres"
## Trim sheet strips as [top, bottom] rows of 2048 (README "Trim strip layout"); U runs 8 m per sheet width.
const SHEET_PX := 2048.0
const SHEET_M := 8.0
const STRIP_FLAT_BAR := Vector2(0, 64)
const STRIP_ROUND_RAIL := Vector2(64, 128)
const STRIP_JAMB := Vector2(640, 896)
const STRIP_RIVETED := Vector2(896, 1408)
const STRIP_WIDE_PLATE := Vector2(1408, 2048)
const STRIP_HAZARD := Vector2(0, 64)
const STRIP_PIPE := Vector2(640, 896)
const STRIP_TRAY := Vector2(896, 1408)
const STRIP_KICK := Vector2(640, 896)
## Zones whose walls are steel plate (no painted band, so no rail).
const STEEL_ZONES: Array[StringName] = [&"B"]
const KICK := Vector2(0.18, 0.025) ## height, depth off the wall face, m
const RAIL_Y := 1.2 ## top of the painted band (README: lower 1.2 m)
const RAIL := Vector2(0.06, 0.035)
const RIB := Vector2(0.24, 0.05) ## width, depth
const RIB_EVERY_M := 3.0
const BEAM := Vector2(0.2, 0.22) ## width, depth below the ceiling
const DOOR_HEAD_M := 2.5
const JAMB := Vector2(0.1, 0.06) ## width beside the opening, depth proud of each wall face
const THRESHOLD_W := 0.2
const THRESHOLD_Y := 0.007 ## between the stripes (MapDressing.STRIPE_Y) and the decals (DECAL_FLOOR_Y)
const TRAY := Vector3(0.3, 0.08, 2.66) ## depth off the wall, height, bottom y
const PIPE_R := 0.06
const PIPE_Y: Array[float] = [2.7, 2.86]
const PIPE_OFF := 0.09 ## pipe axis off the wall face beyond its radius
const DOOR_KINDS: Array[StringName] = [MapPassage.DOOR, MapPassage.BARRICADABLE, MapPassage.ARCHWAY]


## Adds the trim under `parent` from the wall skins under `greybox` (MapGreybox._skin); returns the "Trim" node.
static func build(parent: Node3D, greybox: Node3D, map: MapData) -> Node3D:
	var out := Node3D.new()
	out.name = &"Trim"
	parent.add_child(out)
	var tools := {}
	for key in [METAL, MARKINGS, CONCRETE]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[key] = st
	var zones := {}
	for v in map.volumes:
		zones[v.id] = v.zone
	for n in greybox.get_children():
		if n is MeshInstance3D and n.get_meta(&"surface", &"") == &"wall":
			_wall(tools, n as MeshInstance3D, zones.get(n.get_meta(&"volume"), &""), map)
	for v in map.volumes:
		_beams(tools[METAL], v)
	for p in map.passages:
		if p.kind in DOOR_KINDS:
			_doorway(tools, p, map)
	for key in tools:
		var st := tools[key] as SurfaceTool
		st.generate_tangents()
		var mi := MeshInstance3D.new()
		mi.name = String(key).get_file().get_basename()
		mi.mesh = st.commit()
		mi.material_override = load(key)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		out.add_child(mi)
	return out


## Kick plate, rail, pilasters and (corridors) tray or pipes on one wall skin.
static func _wall(tools: Dictionary, skin: MeshInstance3D, zone: StringName, map: MapData) -> void:
	var size := (skin.mesh as BoxMesh).size
	var side := String(skin.get_meta(&"side"))
	var axis := 0 if side[0] == "x" else 2
	var along := 2 if axis == 0 else 0
	var inward := -1.0 if side[1] == "+" else 1.0 ## "+": the room lies on the low side (MapGreybox._skin)
	var n := Vector3.ZERO
	n[axis] = inward
	var face := skin.position
	face[axis] += inward * size[axis] / 2.0
	var lo: float = skin.position[along] - size[along] / 2.0
	var hi: float = skin.position[along] + size[along] / 2.0
	var floor_y := skin.position.y - size.y / 2.0
	var top_y := skin.position.y + size.y / 2.0
	var metal := tools[METAL] as SurfaceTool
	_strip(tools[CONCRETE], face, n, along, lo, hi, floor_y, floor_y + KICK.x, KICK.y, STRIP_KICK)
	if zone not in STEEL_ZONES:
		_strip(metal, face, n, along, lo, hi, floor_y + RAIL_Y - RAIL.x / 2.0, floor_y + RAIL_Y + RAIL.x / 2.0, RAIL.y,
				STRIP_ROUND_RAIL)
	var count := maxi(1, roundi((hi - lo) / RIB_EVERY_M))
	for i in count + 1:
		var c := clampf(lo + (hi - lo) * i / count, lo + RIB.x / 2.0, hi - RIB.x / 2.0)
		if hi - lo < RIB.x:
			break
		_strip(metal, face, n, along, c - RIB.x / 2.0, c + RIB.x / 2.0, floor_y, top_y, RIB.y, STRIP_RIVETED, true)
	if zone == &"link":
		var mk := tools[MARKINGS] as SurfaceTool
		if side[1] == "+":
			_strip(mk, face, n, along, lo, hi, floor_y + TRAY.z, floor_y + TRAY.z + TRAY.y, TRAY.x, STRIP_TRAY)
		else:
			for y in PIPE_Y:
				var at := face + n * (RIB.y + PIPE_OFF)
				at.y = floor_y + y
				var a := at
				var b := at
				a[along] = lo
				b[along] = hi
				_pipe(mk, a, b, PIPE_R, STRIP_PIPE)


## Beams across the shorter horizontal side of volume `v`, on thirds of the overhead light cells along the longer.
static func _beams(st: SurfaceTool, v: MapVolume) -> void:
	var cell_m := LightingPresets.load_shipped().overhead_cell_m
	var long_axis := 0 if v.box.size.x >= v.box.size.z else 2
	var short_axis := 2 if long_axis == 0 else 0
	var cells := maxi(1, ceili(v.box.size[long_axis] / cell_m))
	var step: float = v.box.size[long_axis] / cells / 3.0
	var top := v.box.end.y
	for j in range(1, cells * 3): ## thirds of a cell never land on its centre
		var c: float = v.box.position[long_axis] + step * j
		var lo := Vector3(0.0, top - BEAM.y, 0.0)
		var hi := Vector3(0.0, top, 0.0)
		lo[long_axis] = c - BEAM.x / 2.0
		hi[long_axis] = c + BEAM.x / 2.0
		lo[short_axis] = v.box.position[short_axis]
		hi[short_axis] = v.box.end[short_axis]
		_box(st, lo, hi, short_axis, STRIP_WIDE_PLATE)


## Header over the opening, jambs on both faces and a threshold on the floor.
static func _doorway(tools: Dictionary, p: MapPassage, map: MapData) -> void:
	var ceiling := INF
	var axis := -1 ## the wall's normal axis: the one along which the two sides lie in different volumes
	for v in map.volumes:
		for ax in [0, 2]:
			var probe := p.position + Vector3.UP * 0.5
			for s in [-0.3, 0.3]:
				var q := probe
				q[ax] += s
				var other := probe
				other[ax] -= s
				if v.box.has_point(q) and not v.box.has_point(other):
					axis = ax
					ceiling = minf(ceiling, v.box.end.y)
	if axis < 0 or ceiling == INF:
		return
	var along := 2 if axis == 0 else 0
	var half := p.width_m / 2.0
	var t := MapGreybox.SKIN_T
	var metal := tools[METAL] as SurfaceTool
	var lo := p.position
	var hi := p.position
	lo[axis] -= t
	hi[axis] += t
	lo[along] -= half
	hi[along] += half
	lo.y = p.position.y + DOOR_HEAD_M
	hi.y = ceiling
	if hi.y > lo.y:
		_box(metal, lo, hi, along, STRIP_RIVETED)
	for s in [-1.0, 1.0]: ## jambs: the opening's edges, proud of both faces, up to the header
		var j0 := p.position
		var j1 := p.position
		j0[axis] -= t + JAMB.y
		j1[axis] += t + JAMB.y
		var edge: float = p.position[along] + s * half
		j0[along] = minf(edge, edge + s * JAMB.x)
		j1[along] = maxf(edge, edge + s * JAMB.x)
		j1.y = p.position.y + DOOR_HEAD_M
		_box(metal, j0, j1, 1, STRIP_JAMB)
	var h0 := lo
	var h1 := hi ## lintel trim under the header
	h0[axis] -= JAMB.y
	h1[axis] += JAMB.y
	h0[along] -= JAMB.x
	h1[along] += JAMB.x
	h0.y = p.position.y + DOOR_HEAD_M - 0.1
	h1.y = p.position.y + DOOR_HEAD_M
	_box(metal, h0, h1, along, STRIP_JAMB)
	var f0 := p.position
	var f1 := p.position
	f0[axis] -= THRESHOLD_W / 2.0
	f1[axis] += THRESHOLD_W / 2.0
	f0[along] -= half
	f1[along] += half
	f0.y = p.position.y
	f1.y = p.position.y + THRESHOLD_Y
	_box(tools[MARKINGS], f0, f1, along, STRIP_HAZARD)


## A slab on wall face `face` (normal `n`) from `a` to `b` along axis `along`, y0 to y1, `depth` proud of the
## face. `vertical`: the strip's U runs up the wall (pilasters) instead of along it.
static func _strip(st: SurfaceTool, face: Vector3, n: Vector3, along: int, a: float, b: float, y0: float, y1: float,
		depth: float, rows: Vector2, vertical := false) -> void:
	var lo := face
	var hi := face + n * depth
	lo[along] = a
	hi[along] = b
	lo.y = y0
	hi.y = y1
	_box(st, Vector3(minf(lo.x, hi.x), lo.y, minf(lo.z, hi.z)), Vector3(maxf(lo.x, hi.x), hi.y, maxf(lo.z, hi.z)),
			1 if vertical else along, rows)


## An axis-aligned box from `lo` to `hi`. U runs along axis `u_axis` at SHEET_M per sheet; each face's other
## extent spans strip `rows` in V.
static func _box(st: SurfaceTool, lo: Vector3, hi: Vector3, u_axis: int, rows: Vector2) -> void:
	for ax in 3:
		for s in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[ax] = s
			var others: Array[int] = [0, 1, 2]
			others.erase(ax)
			var u_ax: int = u_axis if ax != u_axis else others[0] ## an end cap takes either
			var v_axis: int = others[0] if others[1] == u_ax else others[1]
			var corners: Array[Vector3] = []
			for k in 4:
				var c := Vector3()
				c[ax] = hi[ax] if s > 0.0 else lo[ax]
				var cu := k == 1 or k == 2
				var cv := k >= 2
				c[u_ax] = hi[u_ax] if cu else lo[u_ax]
				c[v_axis] = hi[v_axis] if cv else lo[v_axis]
				corners.append(c)
			var uvs: Array[Vector2] = []
			for c in corners:
				var vt := 0.0 if is_equal_approx(c[v_axis], lo[v_axis]) else 1.0
				uvs.append(Vector2(c[u_ax] / SHEET_M, lerpf(rows.y, rows.x, vt) / SHEET_PX))
			## wind so the face points along n
			var e1 := corners[1] - corners[0]
			var e2 := corners[2] - corners[0]
			var order := [0, 1, 2, 0, 2, 3] if e1.cross(e2).dot(n) < 0.0 else [0, 2, 1, 0, 3, 2]
			for i in order:
				st.set_normal(n)
				st.set_uv(uvs[i])
				st.add_vertex(corners[i])


## A capped-off cylinder from `a` to `b` (horizontal), U along it, V around it over strip `rows`.
static func _pipe(st: SurfaceTool, a: Vector3, b: Vector3, r: float, rows: Vector2) -> void:
	const SEGS := 10
	var d := (b - a).normalized()
	var e1 := d.cross(Vector3.UP).normalized()
	var e2 := d.cross(e1)
	var ua := a.dot(d) / SHEET_M
	var ub := b.dot(d) / SHEET_M
	for i in SEGS:
		var t0 := TAU * i / SEGS
		var t1 := TAU * (i + 1) / SEGS
		var n0 := e1 * cos(t0) + e2 * sin(t0)
		var n1 := e1 * cos(t1) + e2 * sin(t1)
		var v0 := lerpf(rows.x, rows.y, float(i) / SEGS) / SHEET_PX
		var v1 := lerpf(rows.x, rows.y, float(i + 1) / SEGS) / SHEET_PX
		var quad := [[a + n0 * r, n0, Vector2(ua, v0)], [b + n0 * r, n0, Vector2(ub, v0)],
				[b + n1 * r, n1, Vector2(ub, v1)], [a + n1 * r, n1, Vector2(ua, v1)]]
		var order := [0, 1, 2, 0, 2, 3] if (quad[1][0] - quad[0][0]).cross(quad[2][0] - quad[0][0]).dot(n0) < 0.0 \
				else [0, 2, 1, 0, 3, 2]
		for k in order:
			st.set_normal(quad[k][1])
			st.set_uv(quad[k][2])
			st.add_vertex(quad[k][0])
