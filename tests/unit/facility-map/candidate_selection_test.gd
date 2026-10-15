# Story facility-map/007: candidate point selection (research-facility.md Authored Candidate Points;
# survivor-objectives.md rules 5-6; ADR-0012 §6). Checks the shipped map's candidates with seeded draws.
extends GdUnitTestSuite

## 3 fuse box pairs x 19 fuse pairs (21 minus the A and C same-zone pairs) x (15 + 15 + 10) drive
## pairs per terminal (T3 drops the 5 pairs holding d6).
const VALID_COUNT := 2280
const SELECTIONS := 1000
const ROUNDS := 20
const MIN_DRIVE_PAIRS := 4
const TERMINALS := 3
const SEED := 12345

var _map: MapData
var _placements: Array[PackedInt32Array]
var _volume: Dictionary[StringName, MapVolume] = {}


func before_test() -> void:
	_map = MapData.load_map()
	_placements = CandidateSelection.valid_placements(_map)
	for v in _map.volumes:
		_volume[v.id] = v


func _room(i: int) -> StringName:
	return _volume[_map.markers[i].volume].room


func _of_type(placement: PackedInt32Array, type: StringName) -> Array[int]:
	var out: Array[int] = []
	for i in placement:
		if _map.markers[i].type == type:
			out.append(i)
	return out


func _broken_rule(p: PackedInt32Array) -> String:
	var counts := {&"drive": 2, &"fuse": 2, &"fuse_box": 2, &"terminal": 1}
	for type: StringName in counts:
		var picked := _of_type(p, type)
		if picked.size() != counts[type]:
			return "%s count %d" % [type, picked.size()]
		if picked.size() == 2 and _room(picked[0]) == _room(picked[1]):
			return "two %s in %s" % [type, _room(picked[0])]
	for i in _of_type(p, &"drive") + _of_type(p, &"fuse"):
		if _room(i) == &"A1":
			return "%s in A1" % _map.markers[i].id
	for i in _of_type(p, &"fuse_box"):
		if _volume[_map.markers[i].volume].zone != &"B":
			return "%s outside Zone B" % _map.markers[i].id
	var fuses := _of_type(p, &"fuse")
	var zones := fuses.map(func(i: int) -> StringName:
		var v := _volume[_map.markers[i].volume]
		return v.room if v.zone == &"link" else v.zone)
	if zones[0] == zones[1]:
		return "fuses both in zone %s" % zones[0]
	var ids := Array(p).map(func(i: int) -> StringName: return _map.markers[i].id)
	if &"T3" in ids and &"d6" in ids:
		return "T3 with d6"
	return ""


func test_valid_placement_count_is_every_rule_6_combination() -> void:
	assert_int(_placements.size()).is_equal(VALID_COUNT)


func test_1000_seeded_selections_break_no_placement_constraint() -> void:
	for s in SELECTIONS:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var p := CandidateSelection.pick(_placements, rng)
		assert_str(_broken_rule(p)).override_failure_message("seed %d: %s" % [s, _broken_rule(p)]).is_empty()


func test_20_seeded_rounds_vary_drive_pairs_and_terminals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var pairs := {}
	var terminals := {}
	for r in ROUNDS:
		var p := CandidateSelection.pick(_placements, rng)
		pairs[_of_type(p, &"drive")] = true
		terminals[_of_type(p, &"terminal")[0]] = true
	assert_int(pairs.size()).is_greater_equal(MIN_DRIVE_PAIRS)
	assert_int(terminals.size()).is_equal(TERMINALS)


func test_same_seed_gives_same_placement() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = SEED
	b.seed = SEED
	assert_array(CandidateSelection.pick(_placements, a)).is_equal(CandidateSelection.pick(_placements, b))


func test_impossible_counts_give_no_placement() -> void:
	assert_int(CandidateSelection.valid_placements(_map, 2, 2, 2, TERMINALS + 1).size()).is_equal(0)


func test_drive_candidate_in_spawn_room_is_never_used() -> void:
	var d1 := _map.markers.find_custom(func(m: MapMarker) -> bool: return m.id == &"d1")
	_map.markers[d1].volume = &"A1"
	for p in CandidateSelection.valid_placements(_map):
		assert_bool(d1 in p).override_failure_message("d1 in A1 used").is_false()
