# Story facility-map/003: connectivity checks (research-facility.md Acceptance Criteria 1-3,
# Connectivity Graph). Breadth-first search over the shipped map's passages; a barricaded or blocked
# door is a removed edge.
extends GdUnitTestSuite

## research-facility.md "Zones and Rooms" table, in table order.
const TABLE_ROOMS: Array[StringName] = [&"A1", &"A2", &"A3", &"A4", &"A5", &"A6", &"A7", &"H-N", &"H-S",
	&"B1", &"B2", &"B3", &"C1", &"C2", &"C3", &"C4", &"C5"]
## AC3: every edge into Zone B.
const ZONE_B_EDGES: Array[StringName] = [&"A4-B1", &"B2-H-N", &"B3-H-S", &"B1-C2"]
const BARRICADABLE_COUNT := 5

var _map: MapData


func before_test() -> void:
	_map = MapData.load_map()


func test_graph_rooms_are_the_zones_and_rooms_table() -> void:
	assert_array(_map.rooms()).contains_exactly_in_any_order(TABLE_ROOMS)


func test_every_room_has_at_least_two_exits() -> void:
	for r in TABLE_ROOMS:
		assert_int(_map.exits_of(r)).override_failure_message("%s exits" % r).is_greater_equal(2)


func test_all_barricadable_doors_barricaded_h_n_still_reaches_every_room() -> void:
	var cut := _map.barricadable_ids()
	assert_int(cut.size()).is_equal(BARRICADABLE_COUNT)
	var reach := _map.reachable(&"H-N", cut)
	assert_bool(reach.has(&"C4")).is_true()
	for r in TABLE_ROOMS:
		assert_bool(reach.has(r)).override_failure_message("%s unreachable" % r).is_true()


func test_blocking_any_single_zone_b_edge_keeps_b1_reachable_from_a1() -> void:
	for edge in ZONE_B_EDGES:
		assert_bool(_map.passages.any(func(p: MapPassage) -> bool: return p.id == edge)) \
			.override_failure_message("no passage %s" % edge).is_true()
		var cut: Array[StringName] = [edge]
		assert_bool(_map.reachable(&"A1", cut).has(&"B1")).override_failure_message("cut %s" % edge).is_true()


# --- the checks can fail --------------------------------------------------------

func _passage(id: StringName, a: StringName, b: StringName, kind := MapPassage.DOOR) -> MapPassage:
	var p := MapPassage.new()
	p.id = id
	p.a = a
	p.b = b
	p.kind = kind
	return p


func _volume(room: StringName, x: float) -> MapVolume:
	var v := MapVolume.new()
	v.id = room
	v.room = room
	v.box = AABB(Vector3(x, 0, 0), Vector3(10, 3, 10))
	return v


## A triangle R1-R2-R3 (two exits each) plus R4 behind one door: R4 fails the exit check, and with its
## door barricadable it is sealed off when barricaded.
func test_a_sealed_room_fails_both_checks() -> void:
	var map := MapData.new()
	map.volumes.assign([_volume(&"R1", 0), _volume(&"R2", 20), _volume(&"R3", 40), _volume(&"R4", 60)])
	map.passages.assign([_passage(&"R1-R2", &"R1", &"R2"), _passage(&"R2-R3", &"R2", &"R3"),
		_passage(&"R3-R1", &"R3", &"R1"), _passage(&"R3-R4", &"R3", &"R4", MapPassage.BARRICADABLE)])
	var errs := " | ".join(map._connectivity_errors())
	assert_str(errs).contains("room R4: 1 exit(s)").contains("room R4: sealed off")
	assert_str(errs).not_contains("R1:").not_contains("R2:").not_contains("R3:")
	assert_bool(map.reachable(&"R1").has(&"R4")).is_true() ## open door: reachable
	assert_bool(map.reachable(&"R1", [&"R3-R4"] as Array[StringName]).has(&"R4")).is_false()


## Code review 2026-10-14: a passage from a room to itself is not an exit.
func test_a_self_loop_is_not_an_exit() -> void:
	var map := MapData.new()
	map.volumes.assign([_volume(&"R1", 0), _volume(&"R2", 20)])
	map.passages.assign([_passage(&"R1-R2", &"R1", &"R2"), _passage(&"R1-R1", &"R1", &"R1")])
	assert_int(map.exits_of(&"R1")).is_equal(1)
	assert_str(" | ".join(map._connectivity_errors())).contains("room R1: 1 exit(s)")
