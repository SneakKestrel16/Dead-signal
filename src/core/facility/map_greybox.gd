class_name MapGreybox extends RefCounted
## Level geometry of the loaded map (story match-flow/011; facility-map story 002 greybox; AD-249 walls). The
## host and every client call build() with the same MapData, so all stand in the same level:
## - the authored greybox scene (assets/levels/research_facility.tscn, generated from the map by
##   tools/level/greybox_from_map.gd and checked by tests/integration/facility-map/greybox_geometry_test.gd):
##   its walls (0.2 m, centred on each volume edge, gaps at every passage), glass partitions on
##   PhysicsLayers.GLASS, LOS blockers and floor collision on PhysicsLayers.WORLD;
## - per volume a floor slab (collision on WORLD) and a ceiling (mesh only: nothing jumps or flies), and a
##   floor slab under the exit zone past the exit opening;
## - each wall drawn as two half-thickness skins, one per side, split per touching volume, so each room shows
##   its own zone's wall material (SurfaceMaterials, data/art/surface_materials.tres);
## - a coloured post at every interactable and door.
## Door blockers keep the scene's start state (doors open, exit closed until Exit Open, research-facility.md
## AC 10), each leaf drawn in SurfaceMaterials.door while its blocker is enabled. DoorBlockers drives them from
## door state: Doors on the host, the replicated EventBatch.DOORS on a client (BUG-0018).
## Usage: `MapGreybox.build(parent, MapData.load_map())`

const LEVEL := "res://assets/levels/research_facility.tscn"
const SURFACES := "res://data/art/surface_materials.tres"
const SLAB_M := 0.2 ## floor slab thickness below each volume's floor, and ceiling thickness above it
const SKIN_T := 0.1 ## half the scene's wall thickness (greybox_from_map.gd WALL_T)
const EPS := 1e-3
const POST := Vector3(0.3, 1.2, 0.3)
const DOOR := Vector3(0.2, 2.0, 0.2)


## Adds the map's level geometry and posts under `parent`; returns the new root node.
static func build(parent: Node, map: MapData) -> Node3D:
	var root := Node3D.new()
	root.name = &"Greybox"
	parent.add_child(root)
	var mats := load(SURFACES) as SurfaceMaterials
	var queries := MapQueries.new(map)
	var level := (load(LEVEL) as PackedScene).instantiate() as Node3D
	root.add_child(level)
	for body: Node3D in level.get_children():
		var mesh := body.get_node(^"Mesh") as MeshInstance3D
		var n := String(body.name)
		if n.begins_with("Wall_"):
			_skin(root, body, map, mats)
			mesh.free()
		elif n.begins_with("Glass_"):
			mesh.material_override = mats.glass
		elif body.has_meta(&"passage"):
			mesh.material_override = mats.door
			mesh.visible = not (body.get_node(^"Shape") as CollisionShape3D).disabled
		elif n == "Floor":
			mesh.free() ## the slabs below draw the floor
		else: ## LOS blockers (Core, racks, breaker wall)
			mesh.material_override = mats.wall_of(_zone(map, queries.volume_at(body.position)))
	for v in map.volumes:
		var floor_at := Vector3(v.box.get_center().x, v.box.position.y - SLAB_M / 2.0, v.box.get_center().z)
		var slab := Vector3(v.box.size.x, SLAB_M, v.box.size.z)
		_tag(_box(root, floor_at, slab, mats.floor_of(v.zone), true), v.id, &"floor")
		_tag(_box(root, floor_at + Vector3.UP * (v.box.size.y + SLAB_M), slab, mats.ceiling_of(v.zone), false), v.id, &"ceiling")
	for z in map.zones:
		if z.kind == MapZone.EXIT:
			var outside := mats.floor_of(_zone(map, queries.volume_at(z.box.get_center() - Vector3(z.box.size.x, 0.0, 0.0))))
			_box(root, Vector3(z.box.get_center().x, -SLAB_M / 2.0, z.box.get_center().z), Vector3(z.box.size.x, SLAB_M, z.box.size.z), outside, true)
	for t in map.interactables():
		var door := t as MapPassage
		if door:
			_box(root, door.position + Vector3.UP * DOOR.y / 2.0, DOOR, _flat(Color(0.55, 0.35, 0.15)), false)
		else:
			var m := t as MapMarker
			_box(root, m.position + Vector3.UP * POST.y / 2.0, POST, _flat(Color(0.2, 0.5, 0.9)), false)
	return root


## Draws scene wall `body` as half-thickness skins: on each side, one per volume whose edge lies on the wall's
## line, over the length they share, in that volume's zone wall material. A side with no volume (the outside)
## gets no skin. Collision stays the scene's.
static func _skin(root: Node3D, body: Node3D, map: MapData, mats: SurfaceMaterials) -> void:
	var size := ((body.get_node(^"Shape") as CollisionShape3D).shape as BoxShape3D).size
	var axis := 0 if String(body.name).begins_with("Wall_x") else 2 ## Wall_x...: on a line x = c
	var along := 2 if axis == 0 else 0
	var c: float = body.position[axis]
	var lo: float = body.position[along] - size[along] / 2.0
	var hi: float = body.position[along] + size[along] / 2.0
	for v in map.volumes:
		for low_side in [true, false]:
			var edge: float = v.box.end[axis] if low_side else v.box.position[axis]
			if absf(edge - c) > EPS:
				continue
			var a := maxf(lo, v.box.position[along])
			var b := minf(hi, v.box.end[along])
			if b - a < EPS:
				continue
			var centre := body.position
			centre[axis] = c + (-SKIN_T if low_side else SKIN_T) / 2.0
			centre[along] = (a + b) / 2.0
			var s := size
			s[axis] = SKIN_T
			s[along] = b - a
			var side := "%s%s" % ["x" if axis == 0 else "z", "+" if low_side else "-"]
			var mi := _box(root, centre, s, mats.wall_of(v.zone), false)
			mi.name = "Skin_%s_%s_%d" % [v.id, side, root.get_child_count()]
			_tag(mi, v.id, &"wall")
			mi.set_meta(&"side", side)


## Zone of volume `id`, or &"" outside every volume.
static func _zone(map: MapData, id: StringName) -> StringName:
	for v in map.volumes:
		if v.id == id:
			return v.zone
	return &""


## Marks a surface mesh with its volume and surface kind (floor, wall, ceiling): the texture pass and the
## level geometry test read them.
static func _tag(n: Node3D, volume: StringName, surface: StringName) -> void:
	var mi := n if n is MeshInstance3D else n.get_child(1)
	mi.set_meta(&"volume", volume)
	mi.set_meta(&"surface", surface)


static func _flat(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	return mat


## A box mesh (and, when `solid`, a WORLD StaticBody3D holding it) at `centre`; returns the mesh or the body.
static func _box(parent: Node3D, centre: Vector3, size: Vector3, mat: Material, solid: bool) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	var holder: Node3D = mi
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = PhysicsLayers.WORLD
		body.collision_mask = PhysicsLayers.NONE
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		body.add_child(mi)
		holder = body
	parent.add_child(holder)
	holder.position = centre
	return holder
