class_name MapGreybox extends RefCounted
## Greybox geometry of the loaded map (story match-flow/011; facility-map story 002 greybox): one floor slab
## per map volume, collision on PhysicsLayers.WORLD so the server's and the owner's movement step stand on
## the same floor, and a coloured post at every interactable and door. Built from MapData only, so the
## host and every client get the same floor. Walls are not built: the map file holds volume boxes, not wall
## geometry (inference: the final level scene replaces this; facility-map owns that).
## Usage: `MapGreybox.build(parent, MapData.load_map())`

const SLAB_M := 0.2 ## floor slab thickness below each volume's floor
const GAP_M := 0.05 ## inset per side, so room seams show as dark lines
const POST := Vector3(0.3, 1.2, 0.3)
const DOOR := Vector3(0.2, 2.0, 0.2)


## Adds the map's floors and posts under `parent`; returns the new root node.
static func build(parent: Node, map: MapData) -> Node3D:
	var root := Node3D.new()
	root.name = &"Greybox"
	parent.add_child(root)
	var shade := 0
	for v in map.volumes:
		var size := Vector3(v.box.size.x - 2.0 * GAP_M, SLAB_M, v.box.size.z - 2.0 * GAP_M)
		var centre := Vector3(v.box.get_center().x, v.box.position.y - SLAB_M / 2.0, v.box.get_center().z)
		var g := 0.35 + 0.1 * (shade % 4)
		shade += 1
		_box(root, centre, size, Color(g, g, g), true)
	for t in map.interactables():
		var door := t as MapPassage
		if door:
			_box(root, door.position + Vector3.UP * DOOR.y / 2.0, DOOR, Color(0.55, 0.35, 0.15), false)
		else:
			var m := t as MapMarker
			_box(root, m.position + Vector3.UP * POST.y / 2.0, POST, Color(0.2, 0.5, 0.9), false)
	return root


static func _box(parent: Node3D, centre: Vector3, size: Vector3, colour: Color, solid: bool) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
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
