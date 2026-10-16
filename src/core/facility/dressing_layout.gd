class_name DressingLayout extends Resource
## Hand-authored dressing placements per room (research-facility-assets.md ASSET-067..069; art bible §6 prop
## density table). Values come only from data/art/dressing_layout.tres; MapDressing places them, visual only.
## A line is "name x z yaw_deg [y]": `name` an item key, or a set key whose own lines are local to the line's
## position and yaw. Room lines are map metres (MapVolume axes: x east, z south); yaw uses the controller
## convention (0 faces -Z, 90 faces -X).
## Usage: `for p in (load(MapDressing.LAYOUT) as DressingLayout).placements(): add p.item at p.xform`

## Item key -> scene (assets/art/props/dressing/, tools/art/build_dressing.py).
@export var items: Dictionary[StringName, PackedScene] = {}
## Set key -> lines local to the set's origin (e.g. a bench with a monitor, binders and a chair).
@export var sets: Dictionary[StringName, PackedStringArray] = {}
## Room id (MapVolume.room) -> lines in map space.
@export var rooms: Dictionary[StringName, PackedStringArray] = {}
## Room id -> extra segments kept clear like a path, as point pairs (B1: each doorway to The Core, art bible §6
## "The Core must be visible from every B1 doorway").
## Room id -> static decals (ASSET-028, mat_decal_set 4x4 atlas: row 0 stains, 1 cracks, 2 scuffs, 3 notes and
## a drip), one "cell x z yaw_deg size_m y" line each: y 0 lies on the floor, otherwise the decal hangs on a wall
## at height y facing yaw (the controller convention), x z already off the wall face.
@export var decals: Dictionary[StringName, PackedStringArray] = {}
## Room id -> evacuation arrow plates (signage atlas row 5), one "dir x z yaw_deg y" line each: dir `<` or `>` as
## a viewer facing the plate reads it, x z already off the wall face, facing yaw (the controller convention).
@export var arrows: Dictionary[StringName, PackedStringArray] = {}
@export var clear_lines: Dictionary[StringName, PackedVector3Array] = {}


## Every placement, sets expanded, in file order: [{room, item, xform}]. A line naming an unknown item or set,
## or with too few fields, is skipped with an error (pushed, so a test log shows it).
func placements() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for room: StringName in rooms:
		for line in rooms[room]:
			_expand(out, room, line, Transform3D.IDENTITY, true)
	return out


func _expand(out: Array[Dictionary], room: StringName, line: String, parent: Transform3D, allow_set: bool) -> void:
	var f := line.split(" ", false)
	if f.size() < 4:
		push_error("DressingLayout: bad line '%s' in %s" % [line, room])
		return
	var at := Transform3D(Basis(Vector3.UP, deg_to_rad(f[3].to_float())),
			Vector3(f[1].to_float(), f[4].to_float() if f.size() > 4 else 0.0, f[2].to_float()))
	var key := StringName(f[0])
	if allow_set and sets.has(key):
		for sub in sets[key]:
			_expand(out, room, sub, parent * at, false)
	elif items.has(key):
		out.append({"room": room, "item": key, "xform": parent * at})
	else:
		push_error("DressingLayout: unknown item '%s' in %s" % [key, room])
