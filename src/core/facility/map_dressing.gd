class_name MapDressing extends RefCounted
## Set dressing of the loaded map, built by MapGreybox.build under its root as child "Dressing"
## (research-facility-assets.md ASSET-028..030 signage, decals, stripes; art bible §6 wayfinding):
## - Signs: at each doorway, on each room's side, a callout plate naming the room behind it (mat_signage atlas
##   cell, assets/art/materials/README.md). A plate goes beside the opening at eye height, on whichever side of
##   it is still a wall of that room (inference: the level doc places no signs; playtest settles it).
## - Stripes: one floor stripe along each service corridor's centreline, H-N solid blue, H-S dashed orange.
## - Props: the dressing sets (ASSET-067..069) at the hand-authored placements of data/art/dressing_layout.tres
##   (DressingLayout), named Dress_<room>_<n>, each fading out past its visibility range (art bible §8 LOD by
##   visibility range). The layout keeps markers, door swings and the paths between doorways clear
##   (map_dressing_test checks it).
## - Decals: static stains, cracks, scuffs and notes from the layout's `decals`, as alpha quads on mat_decal_set
##   with the atlas cell picked by uv1 offset/scale. Quads, not Decal nodes: Decal has no UV region and an
##   AtlasTexture on a Decal is unverified (assets/art/materials/README.md); a quad renders headless and in game.
## - Fixtures (ASSET-070..076): a ceiling fixture over each overhead light and a floor strip under each emergency
##   light, on the LightingPresenter's grid (LightingPresets.overhead_cell_m), and a beacon plus an alarm strobe
##   on the ceiling of each beacon volume (red with the triangle cap in C4). Meshes only, unlit diffusers: the
##   lights stay the presenter's and ScareVisuals', so counts and energies are unchanged; the strips glow faintly
##   as they are always on. Zone A and corridors take the panel, B and C the cage (inference: the spec names
##   no fixture for B or the corridors).
## Visual only: no collision, nothing gameplay reads.
## Usage: `MapDressing.build(greybox_root, map, MapQueries.new(map))`

const LAYOUT := "res://data/art/dressing_layout.tres"
## Visibility range ends, m: props whose longest side is under SMALL_M fade sooner (inference: no source gives
## ranges; profiling settles them).
const SMALL_M := 0.6
const SMALL_RANGE_M := 15.0
const RANGE_M := 40.0
const DECALS := "res://assets/art/materials/mat_decal_set.tres"
const DECAL_FLOOR_Y := 0.008 ## above the stripes (STRIPE_Y) so they never z-fight
const DIR := "res://assets/art/props/dressing/"
## Ceiling fixture per zone (fallback panel), and the beacon of each beacon volume (fallback amber).
const CEILING_FIXTURE: Dictionary[StringName, String] = {&"B": "prop_light_cage", &"C": "prop_light_cage"}
const BEACON_FIXTURE: Dictionary[StringName, String] = {&"C4": "prop_beacon_red"}
const STROBE_OFFSET := Vector3(0.35, 0.0, 0.0) ## beside its beacon
const SIGNAGE := "res://assets/art/materials/mat_signage.tres"
const STRIPES: Dictionary[StringName, String] = {
	&"H-N": "res://assets/art/materials/mat_stripe_hn.tres",
	&"H-S": "res://assets/art/materials/mat_stripe_hs.tres",
}
## Signage atlas cells in row-major order, 4 columns x 8 rows (tools/art/build_textures.py signage()).
const SIGN_CELLS: PackedStringArray = ["A1", "A2", "A3", "A4", "A5", "A6", "A7", "B1", "B2", "B3",
	"C1", "C2", "C3", "C4", "C5", "H-N", "H-S"]
## Plate size (the atlas cell is 2:1), its centre height, gap off the wall and off the opening's edge, m.
const SIGN_SIZE := Vector2(0.5, 0.25)
const SIGN_Y := 1.7
const SIGN_OFF_WALL := 0.12 ## clears the wall skin (MapGreybox.SKIN_T) plus a few mm
const SIGN_OFF_EDGE := 0.45
## Stripe width and height above the floor, m (inference: no source gives a width).
const STRIPE_W := 0.2
const STRIPE_Y := 0.005


## Adds the dressing under `root`; returns the new "Dressing" node.
static func build(root: Node3D, map: MapData, queries: MapQueries) -> Node3D:
	var out := _child(root, &"Dressing")
	_signs(_child(out, &"Signs"), map, queries)
	_stripes(_child(out, &"Stripes"), map)
	var layout := load(LAYOUT) as DressingLayout
	_props(_child(out, &"Props"), layout)
	_decals(_child(out, &"Decals"), layout)
	_fixtures(_child(out, &"Fixtures"), map, LightingPresets.load_shipped())
	return out


static func _child(parent: Node3D, n: StringName) -> Node3D:
	var c := Node3D.new()
	c.name = n
	parent.add_child(c)
	return c


## Room of the volume at `p`, or &"" outside every volume.
static func _room_at(map: MapData, queries: MapQueries, p: Vector3) -> StringName:
	var id := queries.volume_at(p)
	for v in map.volumes:
		if v.id == id:
			return v.room
	return &""


static func _signs(parent: Node3D, map: MapData, queries: MapQueries) -> void:
	var base := load(SIGNAGE) as BaseMaterial3D
	var mats := {}
	var mesh := QuadMesh.new()
	mesh.size = SIGN_SIZE
	for p in map.passages:
		## the wall normal: the horizontal axis along which the opening's two sides lie in different rooms
		var n := Vector3.RIGHT
		if _room_at(map, queries, p.position + Vector3.RIGHT * 0.3) == _room_at(map, queries, p.position - Vector3.RIGHT * 0.3):
			n = Vector3.BACK
		var along := Vector3(n.z, 0.0, n.x)
		for dir in [n, -n]:
			var side := _room_at(map, queries, p.position + dir * 0.3)
			var named: StringName = p.b if side == p.a else p.a
			if side == &"" or named == side or not SIGN_CELLS.has(String(named)):
				continue
			for s in [1.0, -1.0]:
				var at: Vector3 = p.position + along * s * (p.width_m / 2.0 + SIGN_OFF_EDGE + SIGN_SIZE.x / 2.0)
				var room_beyond := _room_at(map, queries, at + dir * 0.3)
				var other_side := _room_at(map, queries, at - dir * 0.3)
				if room_beyond != side or other_side == side: ## not on a wall of this room
					continue
				if not mats.has(named):
					var k := SIGN_CELLS.find(String(named))
					var m := base.duplicate() as BaseMaterial3D
					m.uv1_scale = Vector3(0.25, 0.125, 1.0)
					m.uv1_offset = Vector3((k % 4) * 0.25, (k / 4) * 0.125, 0.0)
					mats[named] = m
				var mi := MeshInstance3D.new()
				mi.mesh = mesh
				mi.material_override = mats[named]
				mi.name = "Sign_%s_%s" % [p.id, side]
				mi.set_meta(&"room", named)
				parent.add_child(mi)
				mi.position = at + dir * SIGN_OFF_WALL + Vector3.UP * SIGN_Y
				mi.rotation.y = atan2(dir.x, dir.z) ## QuadMesh faces +Z
				break


## Floor quad along each corridor's merged box: U across, V along at 1 V per metre (the stripe textures'
## 256 px = 1 m), so the H-S dashes keep their 0.6 m / 0.4 m rhythm.
static func _stripes(parent: Node3D, map: MapData) -> void:
	for room: StringName in STRIPES:
		var box := AABB()
		var first := true
		for v in map.volumes:
			if v.room == room:
				box = v.box if first else box.merge(v.box)
				first = false
		if first:
			continue
		var length := box.size.x
		var w := STRIPE_W / 2.0
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_normal(Vector3.UP)
		var corners := [Vector3(-length / 2.0, 0.0, -w), Vector3(length / 2.0, 0.0, -w),
			Vector3(length / 2.0, 0.0, w), Vector3(-length / 2.0, 0.0, w)]
		var uvs := [Vector2(0.0, 0.0), Vector2(0.0, length), Vector2(1.0, length), Vector2(1.0, 0.0)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[i])
			st.add_vertex(corners[i])
		st.generate_tangents()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = load(STRIPES[room])
		mi.name = "Stripe_%s" % room
		parent.add_child(mi)
		mi.position = Vector3(box.get_center().x, box.position.y + STRIPE_Y, box.get_center().z)


static func _props(parent: Node3D, layout: DressingLayout) -> void:
	var counts: Dictionary[StringName, int] = {}
	for p in layout.placements():
		var n := (layout.items[p.item] as PackedScene).instantiate() as Node3D
		var room: StringName = p.room
		counts[room] = counts.get(room, 0) + 1
		n.name = "Dress_%s_%d" % [room, counts[room]]
		n.set_meta(&"room", room)
		n.set_meta(&"item", p.item)
		parent.add_child(n)
		n.transform = p.xform
		for gi: GeometryInstance3D in n.find_children("*", "GeometryInstance3D", true, false):
			var size := gi.get_aabb().size if gi is MeshInstance3D else Vector3.ONE
			gi.visibility_range_end = SMALL_RANGE_M if maxf(size.x, maxf(size.y, size.z)) < SMALL_M else RANGE_M


static func _decals(parent: Node3D, layout: DressingLayout) -> void:
	var base := load(DECALS) as BaseMaterial3D
	var mats := {}
	for room: StringName in layout.decals:
		var i := 0
		for line in layout.decals[room]:
			var f := line.split(" ", false)
			if f.size() < 6:
				push_error("DressingLayout: bad decal line '%s' in %s" % [line, room])
				continue
			var cell := f[0].to_int()
			if not mats.has(cell):
				var m := base.duplicate() as BaseMaterial3D
				m.uv1_scale = Vector3(0.25, 0.25, 1.0)
				m.uv1_offset = Vector3((cell % 4) * 0.25, (cell / 4) * 0.25, 0.0)
				mats[cell] = m
			var mesh := QuadMesh.new()
			mesh.size = Vector2.ONE * f[4].to_float()
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = mats[cell]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			i += 1
			mi.name = "Decal_%s_%d" % [room, i]
			mi.set_meta(&"room", room)
			mi.set_meta(&"cell", cell)
			parent.add_child(mi)
			var y := f[5].to_float()
			var yaw := deg_to_rad(f[3].to_float())
			mi.position = Vector3(f[1].to_float(), y if y > 0.0 else DECAL_FLOOR_Y, f[2].to_float())
			if y > 0.0: ## on a wall, facing yaw: the QuadMesh faces +Z, so turn it half round
				mi.rotation.y = yaw + PI
			else: ## on the floor, face up, turned by yaw
				mi.rotation = Vector3(-PI / 2.0, yaw, 0.0)


## Same grid as LightingPresenter._build (map_dressing_test checks the two agree).
static func _fixtures(parent: Node3D, map: MapData, presets: LightingPresets) -> void:
	var scenes := {}
	for v in map.volumes:
		var nx := maxi(1, ceili(v.box.size.x / presets.overhead_cell_m))
		var nz := maxi(1, ceili(v.box.size.z / presets.overhead_cell_m))
		var cell := Vector2(v.box.size.x / nx, v.box.size.z / nz)
		var n := 0
		for i in nx:
			for k in nz:
				var at := Vector3(v.box.position.x + cell.x * (i + 0.5), v.box.position.y, v.box.position.z + cell.y * (k + 0.5))
				n += 1
				_fixture(parent, scenes, CEILING_FIXTURE.get(v.zone, "prop_light_panel"), "Overhead_%s_%d" % [v.id, n],
						at + Vector3.UP * v.box.size.y)
				_fixture(parent, scenes, "prop_emergency_strip", "Strip_%s_%d" % [v.id, n], at)
		if String(v.id) in presets.beacon_volumes:
			var top := Vector3(v.box.get_center().x, v.box.end.y, v.box.get_center().z)
			_fixture(parent, scenes, BEACON_FIXTURE.get(v.id, "prop_beacon"), "Beacon_%s" % v.id, top)
			_fixture(parent, scenes, "prop_strobe", "Strobe_%s" % v.id, top + STROBE_OFFSET)


static func _fixture(parent: Node3D, scenes: Dictionary, file: String, n: String, at: Vector3) -> void:
	if not scenes.has(file):
		scenes[file] = load(DIR + file + ".glb")
	var f := (scenes[file] as PackedScene).instantiate() as Node3D
	f.name = n
	f.set_meta(&"fixture", StringName(file))
	parent.add_child(f)
	f.position = at
