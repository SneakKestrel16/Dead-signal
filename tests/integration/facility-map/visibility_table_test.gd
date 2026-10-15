# Story facility-map/005: per-volume visibility table for relevance (research-facility.md "Visibility
# sets"; ADR-0004 §4). Integration: reads the shipped map file and drives ReplicationScope over it.
extends GdUnitTestSuite

const SEED := 5005
const VIEWER := 1
const BODY := 2

var _map: MapData
var _q: MapQueries
var _closed: Dictionary[StringName, bool] = {}


func before_test() -> void:
	_map = MapData.load_map()
	_q = MapQueries.new(_map)
	_closed = {}


func _volume(id: StringName) -> MapVolume:
	for v in _map.volumes:
		if v.id == id:
			return v
	return null


func _centre(id: StringName) -> Vector3:
	return _volume(id).box.get_center() * Vector3(1, 0, 1)


func _scope(knobs: Knobs) -> ReplicationScope:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var scope := ReplicationScope.new(knobs, rng)
	scope.relevance.volume_at = _q.volume_at
	scope.relevance.visible_volumes = func(v: StringName) -> PackedStringArray:
		return _q.visible_set(v, func(door: StringName) -> bool: return _closed.get(door, false))
	return scope


# --- AC1: 25 volumes, symmetric -----------------------------------------------------

func test_every_one_of_the_25_volumes_has_a_visibility_set() -> void:
	assert_int(_map.volumes.size()).is_equal(25)
	for v in _map.volumes:
		assert_dict(v.sees).override_failure_message("volume %s" % v.id).is_not_empty()
	assert_array(_map.errors()).is_empty()


func test_table_is_symmetric_with_the_same_door_both_ways() -> void:
	for v in _map.volumes:
		for seen: StringName in v.sees:
			var other := _volume(seen)
			assert_object(other).override_failure_message("%s sees unknown %s" % [v.id, seen]).is_not_null()
			if other != null:
				assert_bool(other.sees.has(v.id) and other.sees[v.id] == v.sees[seen]) \
					.override_failure_message("%s -> %s not mirrored" % [v.id, seen]).is_true()


func test_an_asymmetric_edit_fails_the_load() -> void:
	_volume(&"A5").sees.erase(&"A4")
	assert_array(_map.errors()).contains(["volume A4: sees A5 but not back through the same door"])


func test_a_volume_with_no_set_fails_the_load() -> void:
	_volume(&"C4").sees.clear()
	assert_array(_map.errors()).contains(["volume C4: empty visibility set"])


func test_an_entry_cut_by_an_archway_fails_the_load() -> void:
	_volume(&"A1").sees[&"H-S1"] = &"A1-H-S" ## an archway never closes
	_volume(&"H-S1").sees[&"A1"] = &"A1-H-S"
	assert_array(_map.errors()).contains(["volume A1: door A1-H-S does not join A1 and H-S"])


func test_a_volume_listing_itself_fails_the_load() -> void:
	_volume(&"B2").sees[&"B2"] = &""
	assert_array(_map.errors()).contains(["volume B2: sees unknown or itself: B2"])


func test_a_door_that_does_not_join_the_two_rooms_fails_the_load() -> void:
	_volume(&"A1").sees[&"A3"] = &"A2-A3"
	_volume(&"A3").sees[&"A1"] = &"A2-A3"
	assert_array(_map.errors()).contains(["volume A1: door A2-A3 does not join A1 and A3"])


## Every row against the level doc's own table (the source of truth, read fresh): "X=Y: vols" and
## "X#Y: vols" are door entries (passage "X-Y"); "open:", "glass:" and "archway X~Y:" are uncut. A
## volume listed both through a door and through glass (A2-M and A3) stays uncut: the glass shows it.
func test_every_row_matches_the_level_doc_table() -> void:
	var doc := FileAccess.get_file_as_string("res://design/levels/research-facility.md")
	var lines := doc.substr(doc.find("| Volume | Through a door")).split("\n")
	var rows := 0
	for line in lines.slice(2):
		if not line.begins_with("|"):
			break
		var cells := line.trim_prefix("|").trim_suffix("|").split("|")
		var want: Dictionary[StringName, StringName] = {}
		for part in cells[1].split("·"):
			var door := part.get_slice(":", 0).strip_edges().replace("=", "-").replace("#", "-")
			for v in part.get_slice(":", 1).split(","):
				want[StringName(v.strip_edges())] = StringName(door)
		if cells[2].strip_edges() != "—":
			for part in cells[2].split("·"):
				for v in part.get_slice(":", 1).split(","):
					want[StringName(v.strip_edges())] = &""
		var id := StringName(cells[0].strip_edges())
		assert_object(_volume(id)).override_failure_message("no volume " + id).is_not_null()
		if _volume(id) != null:
			assert_dict(_volume(id).sees).override_failure_message("row " + id).is_equal(want)
		rows += 1
	assert_int(rows).is_equal(25)


# --- AC2: volume_at for each volume -------------------------------------------------

func test_volume_at_returns_each_volume_for_a_point_inside_it() -> void:
	for v in _map.volumes:
		assert_str(_q.volume_at(_centre(v.id))).is_equal(v.id)


# --- edge: door entries cut while closed ------------------------------------------

func test_a_door_entry_is_cut_while_that_door_is_closed() -> void:
	assert_array(Array(_q.visible_set(&"A1"))).contains([&"A3", &"A2-S"])
	_closed[&"A1-A3"] = true
	var cut := Array(_q.visible_set(&"A1", func(d: StringName) -> bool: return _closed.get(d, false)))
	assert_array(cut).not_contains([&"A3"])
	assert_array(cut).contains([&"A2-S", &"H-S1", &"H-S2"]) ## another door and the archway stay


func test_glass_and_archway_entries_are_never_cut() -> void:
	var all_closed := func(_d: StringName) -> bool: return true
	assert_array(Array(_q.visible_set(&"A2-M", all_closed))).contains_exactly_in_any_order(
		[&"A3", &"A4", &"A2-N", &"A2-S", &"H-N1", &"H-S1"])
	assert_array(Array(_q.visible_set(&"C4", all_closed))).contains_exactly([&"C2"])


# --- AC3: relevance through the shipped table -------------------------------------

func test_body_inside_the_visible_set_is_sent_and_outside_is_not() -> void:
	var scope := _scope(Knobs.load_all())
	var far := BODY + 1
	var next_door := BODY + 2
	var sent := scope.bodies_for(1, VIEWER, {VIEWER: _centre(&"A1"), BODY: _centre(&"A3"), far: _centre(&"C4"),
		next_door: _centre(&"A5")})
	assert_bool(sent.has(BODY)).is_true() ## A3 is in A1's set
	assert_bool(sent.has(far)).is_false() ## C4 is not
	assert_bool(sent.has(next_door)).is_false() ## nor is A5, a room away across A2


## The table cuts a door entry when `door_closed(door)` says so. "Closed or barricaded" is the door
## state owner's answer to that callable (survivor-defense), not this table's.


func test_closing_the_door_stops_sending_the_body_behind_it() -> void:
	var knobs := Knobs.load_all()
	var scope := _scope(knobs)
	var me := _centre(&"A1")
	var there := _centre(&"A3")
	assert_bool(scope.bodies_for(1, VIEWER, {VIEWER: me, BODY: there}).has(BODY)).is_true()
	_closed[&"A1-A3"] = true
	var t := 2 + knobs.ticks(knobs.net.relevance_linger_s) + 1 ## past the linger
	for tick in range(2, t):
		scope.bodies_for(tick, VIEWER, {VIEWER: me, BODY: there})
	assert_bool(scope.bodies_for(t, VIEWER, {VIEWER: me, BODY: there}).has(BODY)).is_false()
