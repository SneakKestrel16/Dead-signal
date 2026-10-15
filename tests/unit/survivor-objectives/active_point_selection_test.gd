# Story survivor-objectives/008: active point selection (survivor-objectives.md rules 5-6, Tuning Knobs
# candidate counts; ADR-0012 §6). SurvivorObjectives draws its points from CandidateSelection with its
# injected, seeded rng. Rule 6 itself and the 1000-seed check are facility-map/007's
# (tests/unit/facility-map/candidate_selection_test.gd); here every round's draw must be one of those
# valid placements, so it inherits them.
extends GdUnitTestSuite

const ROUNDS := 20
const MIN_DRIVE_PAIRS := 4
const TERMINALS := 3
const SEED := 12345

var _knobs: Knobs
var _map: MapData
var _holds: HoldService


func before_test() -> void:
	_knobs = Knobs.load_all()
	_map = MapData.load_map()


func _round(rng_seed: int) -> SurvivorObjectives:
	var holds := HoldService.new(_knobs, func() -> Array: return [], func(_a: int) -> Array: return [],
		func(_a: int) -> Vector3: return Vector3.ZERO, func(_a: int, _i: Interactable) -> bool: return true,
		func(_a: int) -> int: return -1)
	_holds = holds
	var obj := SurvivorObjectives.new(holds, _map)
	obj.rng.seed = rng_seed
	obj.setup(null, EventBus.new(_knobs.core.max_flush_rounds), StateRegistry.new(), _knobs)
	return obj


func _of_type(p: PackedInt32Array, type: StringName) -> Array[int]:
	var out: Array[int] = []
	for i in p:
		if _map.markers[i].type == type:
			out.append(i)
	return out


## Lock keys of the drive consoles, fuse spawns and fuse boxes the round registered (untagged points).
func _registered() -> Array[StringName]:
	var out: Array[StringName] = []
	for item in _holds._items:
		var key: StringName = (item as ObjectivePoint).lock_key
		if not String(key).begins_with("terminal") and not String(key).ends_with("_dropped") 				and _map.markers.any(func(m: MapMarker) -> bool: return key == StringName("%s_%s" % [m.type, m.id])):
			out.append(key)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


func _expected(active: PackedInt32Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for i in active:
		if _map.markers[i].type != &"terminal":
			out.append(StringName("%s_%s" % [_map.markers[i].type, _map.markers[i].id]))
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


func test_20_seeded_rounds_vary_and_every_draw_is_a_valid_placement() -> void:
	var valid := {}
	for p in CandidateSelection.valid_placements(_map):
		valid[p] = true
	var pairs := {}
	var terminals := {}
	for r in ROUNDS:
		var active: PackedInt32Array = _round(SEED + r).active()
		assert_bool(valid.has(active)).override_failure_message("round %d: %s not valid" % [r, active]).is_true()
		assert_array(_registered()).is_equal(_expected(active))
		pairs[_of_type(active, &"drive")] = true
		terminals[_of_type(active, &"terminal")[0]] = true
	assert_int(pairs.size()).is_greater_equal(MIN_DRIVE_PAIRS)
	assert_int(terminals.size()).is_equal(TERMINALS)


func test_same_seed_gives_same_points() -> void:
	assert_array(_round(SEED).active()).is_equal(_round(SEED).active())


func test_injected_placement_is_used() -> void:
	var holds := HoldService.new(_knobs, func() -> Array: return [], func(_a: int) -> Array: return [],
		func(_a: int) -> Vector3: return Vector3.ZERO, func(_a: int, _i: Interactable) -> bool: return true,
		func(_a: int) -> int: return -1)
	var obj := SurvivorObjectives.new(holds, _map)
	obj.placement = FirstMarkers.of(_map)
	obj.setup(null, EventBus.new(_knobs.core.max_flush_rounds), StateRegistry.new(), _knobs)
	assert_array(obj.active()).is_equal(FirstMarkers.of(_map))


func test_shipped_candidate_counts_match_the_map() -> void:
	assert_array(SurvivorObjectives.candidate_errors(_map, _knobs.objectives)).is_empty()


func test_candidate_count_mismatch_fails_validation() -> void:
	for knob: String in ["drive_candidates", "fuse_candidates", "fuse_box_candidates", "terminal_candidates"]:
		var o := _knobs.objectives.duplicate() as ObjectivesKnobs
		o.set(knob, o.get(knob) - 1)
		assert_array(SurvivorObjectives.candidate_errors(_map, o)).override_failure_message(knob).is_not_empty()


func test_map_with_no_valid_placement_fails_validation() -> void:
	## Every fuse box candidate in one room: no two active boxes can differ in room (rule 6).
	var room_of_first: StringName = &""
	for m in _map.markers:
		if m.type == &"fuse_box":
			if room_of_first == &"":
				room_of_first = m.volume
			m.volume = room_of_first
	assert_array(SurvivorObjectives.candidate_errors(_map, _knobs.objectives)).is_not_empty()
