class_name MapData extends Resource
## The facility's map data, loaded whole at round start from one file (research-facility.md
## Technical Notes; ADR-0007 §9-10; ADR-0006 fixed res:// path). Everything gameplay reads from the
## level comes from here, never from runtime geometry. Lookups go through MapQueries.
## Usage:
##   var map := MapData.load_map()
##   if not map.errors().is_empty(): refuse the round
##   var targets := map.interactables()   # build once per round; pass net ids as ints, never look
##                                        # an item up by reference (each load makes new instances)

const MAP_PATH := "res://data/maps/research_facility.tres"
## Every marker type the level doc places. A map missing one fails errors().
const MARKER_TYPES: Array[StringName] = [&"survivor_spawn", &"monster_spawn", &"hiding", &"switch", &"camera",
	&"monitor", &"drive", &"fuse", &"fuse_box", &"terminal"]
## Marker types a player interacts with (ADR-0008 §2); spawns and cameras are not.
const INTERACTABLE_TYPES: Array[StringName] = [&"hiding", &"switch", &"monitor", &"drive", &"fuse", &"fuse_box",
	&"terminal"]

@export var volumes: Array[MapVolume] = []
@export var passages: Array[MapPassage] = []
@export var markers: Array[MapMarker] = []
## Exit volume, terminal zones and spawn rooms (facility-map story 004). Order matters where zones
## overlap: MapQueries.zone_at returns the first, so the file lists the exit and terminal zones first.
@export var zones: Array[MapZone] = []


## Loads the map file whole, bypassing the resource cache so every round reads the file. CACHE_MODE_IGNORE,
## not IGNORE_DEEP: DEEP reloads this class's own script and crashes the type check (gotchas.md).
## Returns an empty MapData (which fails errors()) when the file is missing or not a MapData.
static func load_map(path: String = MAP_PATH) -> MapData:
	var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res is MapData:
		return res
	return MapData.new()


## Problems that make the map unusable; [] = valid. Each names the id or type at fault.
func errors() -> PackedStringArray:
	var out := PackedStringArray()
	var seen := {}
	var known := {&"Outside": true}
	for item: Resource in volumes + passages + markers + zones:
		if seen.has(item.id):
			out.append("duplicate id: %s" % item.id)
		seen[item.id] = true
	for i in volumes.size():
		known[volumes[i].room] = true
		if volumes[i].footstep_radius_scale <= 0.0 or volumes[i].footstep_radius_scale > 1.0:
			out.append("volume %s: footstep_radius_scale outside (0, 1]" % volumes[i].id)
		for j in range(i + 1, volumes.size()):
			if volumes[i].box.intersects(volumes[j].box):
				out.append("volumes overlap: %s %s" % [volumes[i].id, volumes[j].id])
	for p in passages:
		for r: StringName in [p.a, p.b]:
			if not known.has(r):
				out.append("passage %s: unknown room %s" % [p.id, r])
	var queries := MapQueries.new(self)
	for z in zones:
		if not z.kind in MapZone.KINDS:
			out.append("zone %s: unknown kind %s" % [z.id, z.kind])
	for p in passages:
		if p.kind == MapPassage.EXIT and not queries.in_exit(p.position):
			out.append("passage %s: no exit zone at its opening" % p.id)
	var types := {}
	for m in markers:
		types[m.type] = true
		if not m.type in MARKER_TYPES:
			out.append("marker %s: unknown type %s" % [m.id, m.type])
		if queries.volume_at(m.position) != m.volume:
			out.append("marker %s: position is not in volume %s" % [m.id, m.volume])
		if m.type == &"hiding" and is_nan(m.yaw_deg):
			out.append("marker %s: hiding marker has no yaw_deg" % m.id)
	for t in MARKER_TYPES:
		if not types.has(t):
			out.append("missing marker type: %s" % t)
	out.append_array(_connectivity_errors())
	out.append_array(_visibility_errors())
	return out


## research-facility.md "Visibility sets" (facility-map story 005): every volume sees at least one
## other, every entry names a known volume other than itself, the table is symmetric with the same
## door both ways, and a door entry's passage joins the two volumes' rooms.
func _visibility_errors() -> PackedStringArray:
	var out := PackedStringArray()
	var by_id: Dictionary[StringName, MapVolume] = {}
	for v in volumes:
		by_id[v.id] = v
	var by_passage: Dictionary[StringName, MapPassage] = {}
	for p in passages:
		by_passage[p.id] = p
	for v in volumes:
		if v.sees.is_empty():
			out.append("volume %s: empty visibility set" % v.id)
		for seen: StringName in v.sees:
			var door: StringName = v.sees[seen]
			var other: MapVolume = by_id.get(seen)
			if other == null or other == v:
				out.append("volume %s: sees unknown or itself: %s" % [v.id, seen])
				continue
			if not other.sees.has(v.id) or other.sees[v.id] != door:
				out.append("volume %s: sees %s but not back through the same door" % [v.id, seen])
			if door == &"":
				continue
			var p: MapPassage = by_passage.get(door)
			var joins := p != null and ((p.a == v.room and p.b == other.room) or (p.b == v.room and p.a == other.room))
			if not joins or not p.kind in [&"door", &"barricadable"]:
				out.append("volume %s: door %s does not join %s and %s" % [v.id, door, v.room, other.room])
	return out


## research-facility.md Acceptance Criteria 1-2 (facility-map story 003): every room has at least two
## exits, and barricading every barricadable door at once seals no room off.
func _connectivity_errors() -> PackedStringArray:
	var out := PackedStringArray()
	var all := rooms()
	for r in all:
		if exits_of(r) < 2:
			out.append("room %s: %d exit(s), needs at least 2" % [r, exits_of(r)])
	if not all.is_empty():
		var reach := reachable(all[0], barricadable_ids())
		for r in all:
			if not reach.has(r):
				out.append("room %s: sealed off when every barricadable door is barricaded" % r)
	return out


## Connectivity-graph rooms (each volume's room, &"Outside" excluded), in volume order.
func rooms() -> Array[StringName]:
	var out: Array[StringName] = []
	for v in volumes:
		if not v.room in out:
			out.append(v.room)
	return out


## Passages (doors, archways, open junctions, the exit) leading out of `room`. A passage from a room
## to itself leads nowhere and does not count; two doors to the same neighbour are two exits.
func exits_of(room: StringName) -> int:
	var n := 0
	for p in passages:
		if p.a != p.b and (p.a == room or p.b == room):
			n += 1
	return n


## Ids of the barricadable doors.
func barricadable_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for p in passages:
		if p.kind == MapPassage.BARRICADABLE:
			out.append(p.id)
	return out


## Rooms reachable from `from` (included) over every passage whose id is not in `cut`; a blocked or
## barricaded door is a cut edge (research-facility.md Connectivity Graph). &"Outside" is a node too.
func reachable(from: StringName, cut: Array[StringName] = []) -> Dictionary:
	var seen := {from: true}
	var queue: Array[StringName] = [from]
	while not queue.is_empty():
		var r: StringName = queue.pop_front()
		for p in passages:
			if p.id in cut:
				continue
			var other: StringName = p.b if p.a == r else (p.a if p.b == r else &"")
			if other != &"" and not seen.has(other):
				seen[other] = true
				queue.append(other)
	return seen


## Map interactables in map order (doors, then interactable markers, each in file order). The index
## is the net id, so every peer loading the same file gets the same ids (ADR-0008 §2).
func interactables() -> Array[Resource]:
	var out: Array[Resource] = []
	for p in passages:
		if p.is_door():
			out.append(p)
	for m in markers:
		if m.type in INTERACTABLE_TYPES:
			out.append(m)
	return out


## SHA-256 over every saved field of every volume, passage, marker and zone, in order: equal digests mean
## an identical layout.
func digest() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for item: Resource in volumes + passages + markers + zones:
		for prop in item.get_property_list():
			if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				ctx.update(var_to_str([prop.name, item.get(prop.name)]).to_utf8_buffer())
	return ctx.finish().hex_encode()
