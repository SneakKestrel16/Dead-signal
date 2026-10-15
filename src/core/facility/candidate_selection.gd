class_name CandidateSelection extends RefCounted
## Active objective point selection, facility-map story 007 (research-facility.md Authored Candidate
## Points; survivor-objectives.md rules 5-6; ADR-0012 §6). Pure: map data in, marker indices out.
## valid_placements() runs once at map load and lists every combination that satisfies rule 6; pick()
## draws one per round with the injected, seeded RandomNumberGenerator (never the global randi()).
## Uniform over valid combinations is ADR-0012's reading of rule 5's "uniformly at random" (inference;
## a designer reading per-type uniformity would change only pick()).
## Usage:
##   var placements := CandidateSelection.valid_placements(map)   # map load
##   if placements.is_empty(): refuse the load
##   var active := CandidateSelection.pick(placements, round_rng)  # round start
##   for i in active: map.markers[i]   # terminal, fuse boxes, drives, fuses, each in map order

const SURVIVOR_SPAWN := &"survivor_spawn"
const DRIVE := &"drive"
const FUSE := &"fuse"
const FUSE_BOX := &"fuse_box"
const TERMINAL := &"terminal"
## MapVolume.zone of the service corridors; each corridor counts as its own zone (rule 6).
const LINK_ZONE := &"link"


## Every rule-6-valid placement: indices into map.markers, `terminals` terminals, then `fuse_boxes`
## fuse boxes, `drives` drives and `fuses` fuses, each group in map order. Rule 6: two active points
## of one type never share a room; the active fuses are in different zones; no drive or fuse
## candidate in the survivor spawn room is used; an active terminal and drive never share a room.
## Counts default to the GDD's (rules 8 and 15; SurvivorObjectives.ACTIVE_* for now). [] = none valid,
## which fails the load (ADR-0012 §6).
static func valid_placements(map: MapData, drives: int = 2, fuses: int = 2, fuse_boxes: int = 2,
		terminals: int = 1) -> Array[PackedInt32Array]:
	var room := {}
	var zone := {}
	for v in map.volumes:
		room[v.id] = v.room
		zone[v.id] = v.room if v.zone == LINK_ZONE else v.zone
	var spawn_rooms := {}
	var by_type := {DRIVE: [], FUSE: [], FUSE_BOX: [], TERMINAL: []}
	for m in map.markers:
		if m.type == SURVIVOR_SPAWN:
			spawn_rooms[room.get(m.volume)] = true
	for i in map.markers.size():
		var m := map.markers[i]
		if by_type.has(m.type) and not (m.type in [DRIVE, FUSE] and spawn_rooms.has(room.get(m.volume))):
			by_type[m.type].append(i)
	var room_of := func(i: int) -> Variant: return room.get(map.markers[i].volume)
	var zone_of := func(i: int) -> Variant: return zone.get(map.markers[i].volume)
	var box_sets := _distinct(by_type[FUSE_BOX], fuse_boxes, room_of)
	var drive_sets := _distinct(by_type[DRIVE], drives, room_of)
	var fuse_sets := _distinct(by_type[FUSE], fuses, room_of, zone_of)
	var out: Array[PackedInt32Array] = []
	for t in _distinct(by_type[TERMINAL], terminals, room_of):
		var t_rooms := Array(t).map(room_of)
		for b in box_sets:
			for d in drive_sets:
				if Array(d).any(func(i: int) -> bool: return room_of.call(i) in t_rooms):
					continue
				for f in fuse_sets:
					out.append(t + b + d + f)
	return out


## One placement drawn uniformly from `placements` with `rng` (seeded from the round seed).
## `placements` must be non-empty.
static func pick(placements: Array[PackedInt32Array], rng: RandomNumberGenerator) -> PackedInt32Array:
	return placements[rng.randi_range(0, placements.size() - 1)]


## Every k-subset of `items` (in order) whose members differ pairwise in `key_a` and, when valid, `key_b`.
static func _distinct(items: Array, k: int, key_a: Callable, key_b: Callable = Callable()) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	_extend(items, k, 0, PackedInt32Array(), key_a, key_b, out)
	return out


static func _extend(items: Array, k: int, start: int, chosen: PackedInt32Array, key_a: Callable,
		key_b: Callable, out: Array[PackedInt32Array]) -> void:
	if chosen.size() == k:
		out.append(chosen)
		return
	for n in range(start, items.size()):
		var i: int = items[n]
		var clash := false
		for c in chosen:
			if key_a.call(c) == key_a.call(i) or (key_b.is_valid() and key_b.call(c) == key_b.call(i)):
				clash = true
		if not clash:
			var next := chosen.duplicate()
			next.append(i)
			_extend(items, k, n + 1, next, key_a, key_b, out)

