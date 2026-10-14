class_name MapData extends Resource
## The facility's map data, loaded whole at round start from one file (research-facility.md
## Technical Notes; ADR-0007 §9-10; ADR-0006 fixed res:// path). Everything gameplay reads from the
## level comes from here, never from runtime geometry. Lookups go through MapQueries.
## Usage:
##   var map := MapData.load_map()
##   if not map.errors().is_empty(): refuse the round
##   var net_id := map.interactables().find(door)

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
	var rooms := {&"Outside": true}
	for item: Resource in volumes + passages + markers:
		if seen.has(item.id):
			out.append("duplicate id: %s" % item.id)
		seen[item.id] = true
	for v in volumes:
		rooms[v.room] = true
	for p in passages:
		for r: StringName in [p.a, p.b]:
			if not rooms.has(r):
				out.append("passage %s: unknown room %s" % [p.id, r])
	var types := {}
	var queries := MapQueries.new(self)
	for m in markers:
		types[m.type] = true
		if not m.type in MARKER_TYPES:
			out.append("marker %s: unknown type %s" % [m.id, m.type])
		if queries.volume_at(m.position) != m.volume:
			out.append("marker %s: position is not in volume %s" % [m.id, m.volume])
	for t in MARKER_TYPES:
		if not types.has(t):
			out.append("missing marker type: %s" % t)
	return out


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


## SHA-256 over every saved field of every volume, passage and marker, in order: equal digests mean
## an identical layout.
func digest() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for item: Resource in volumes + passages + markers:
		for prop in item.get_property_list():
			if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				ctx.update(var_to_str([prop.name, item.get(prop.name)]).to_utf8_buffer())
	return ctx.finish().hex_encode()
