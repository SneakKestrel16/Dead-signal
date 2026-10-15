# Story facility-map/001: facility map data and whole-level load (research-facility.md Acceptance
# Criteria 6, Spawn Points, Technical Notes; ADR-0007 §9-10; ADR-0008 §2 net ids). Integration: reads
# the shipped map file. Expected counts and rooms are the level doc's tables, quoted per test.
extends GdUnitTestSuite

const MIN_MONSTER_WALK_M := 25.0 ## Spawn Points: "at least ~25 m of walking from A1"


func _count(items: Array, field: StringName) -> Dictionary:
	var out := {}
	for i: Resource in items:
		out[i.get(field)] = out.get(i.get(field), 0) + 1
	return out


func _room_of(map: MapData, volume_id: StringName) -> StringName:
	for v in map.volumes:
		if v.id == volume_id:
			return v.room
	return &""


func test_shipped_map_loads_with_no_errors() -> void:
	var map := MapData.load_map()
	assert_array(map.errors()).is_empty()
	assert_int(map.volumes.size()).is_greater(0)


func test_volumes_cover_every_room_and_corridor_segment_in_the_level_doc() -> void:
	var map := MapData.load_map()
	## Zones and Rooms table (17 rooms); Lighting volumes: H-N and H-S in four segments, A2 in three.
	var rooms := {}
	for v in map.volumes:
		rooms[v.room] = true
	assert_array(rooms.keys()).contains_exactly_in_any_order([&"A1", &"A2", &"A3", &"A4", &"A5", &"A6", &"A7",
		&"H-N", &"H-S", &"B1", &"B2", &"B3", &"C1", &"C2", &"C3", &"C4", &"C5"])
	assert_dict(_count(map.volumes, &"room")).contains_key_value(&"H-N", 4).contains_key_value(&"H-S", 4) \
		.contains_key_value(&"A2", 3)
	assert_int(map.volumes.size()).is_equal(25)


func test_passages_match_the_connectivity_graph() -> void:
	var map := MapData.load_map()
	## Connectivity Graph: 19 `=` doors, 5 `#` barricadable, 2 archways (A1~H-S, C2~C4), 2 open
	## corridor junctions (A2~H-N, A2~H-S), 1 exit.
	assert_dict(_count(map.passages, &"kind")).is_equal({&"door": 19, &"barricadable": 5, &"archway": 2,
		&"open": 2, &"exit": 1})
	var barricadable := []
	for p in map.passages:
		if p.kind == MapPassage.BARRICADABLE:
			barricadable.append(p.id)
	## Barricadable doors: B1-C2, H-N-C1, C1-C4, C3-C4, H-S-C3.
	assert_array(barricadable).contains_exactly_in_any_order([&"B1-C2", &"H-N-C1", &"C1-C4", &"C3-C4", &"C3-H-S"])


func test_every_door_has_a_swing_box_around_it_and_openings_have_none() -> void:
	var map := MapData.load_map()
	for p in map.passages:
		if p.is_door():
			assert_bool(p.swing_box.has_volume() and p.swing_box.grow(0.01).has_point(p.position)) \
				.override_failure_message("door %s swing box %s" % [p.id, p.swing_box]).is_true()
		else:
			assert_bool(p.swing_box.has_volume()).override_failure_message("opening %s" % p.id).is_false()


func test_markers_match_the_level_doc_counts_and_rooms() -> void:
	var map := MapData.load_map()
	assert_dict(_count(map.markers, &"type")).is_equal({&"survivor_spawn": 5, &"monster_spawn": 3, &"hiding": 6,
		&"switch": 14, &"camera": 4, &"monitor": 1, &"drive": 6, &"fuse": 7, &"fuse_box": 3, &"terminal": 3})
	## Spawn Points, Authored Candidate Points, hiding and surveillance tables; one switch per room.
	var expected := {
		&"S1": &"A1", &"S2": &"A1", &"S3": &"A1", &"S4": &"A1", &"S5": &"A1",
		&"M1": &"C3", &"M2": &"C5", &"M3": &"B2",
		&"d1": &"A6", &"d2": &"A4", &"d3": &"A3", &"d4": &"A7", &"d5": &"A5", &"d6": &"C3",
		&"f1": &"A3", &"f2": &"A5", &"f3": &"B3", &"f4": &"H-S", &"f5": &"C5", &"f6": &"C1", &"f7": &"H-N",
		&"P1": &"B2", &"P2": &"B1", &"P3": &"B3", &"T1": &"C4", &"T2": &"C2", &"T3": &"C3",
		&"h1": &"A6", &"h2": &"A3", &"h3": &"A4", &"h4": &"A5", &"h5": &"B3", &"h6": &"C5",
		&"c1": &"B1", &"c2": &"H-S", &"c3": &"C4", &"c4": &"A2", &"monitors": &"C1",
	}
	var switch_rooms := []
	for m in map.markers:
		var room := _room_of(map, m.volume)
		if m.type == &"switch":
			switch_rooms.append(room)
		else:
			assert_str(room).override_failure_message("%s in %s" % [m.id, room]).is_equal(expected[m.id])
	## "one per room, none in corridors or the A2 spine"
	assert_array(switch_rooms).contains_exactly_in_any_order([&"A1", &"A3", &"A4", &"A5", &"A6", &"A7", &"B1", &"B2",
		&"B3", &"C1", &"C2", &"C3", &"C4", &"C5"])


## AC2. Geometry node count joins this check with story 002 (greybox geometry); candidate activation
## is stories 007-008, so the map data itself must not vary at all.
func test_layout_is_identical_across_10_loads() -> void:
	var first := MapData.load_map()
	for i in 9:
		var again := MapData.load_map()
		assert_bool(again != first).is_true() ## a fresh load, not the cached resource
		assert_str(again.digest()).is_equal(first.digest())
	assert_int(first.digest().length()).is_equal(64)


func test_digest_changes_when_a_door_moves() -> void:
	var map := MapData.load_map()
	var before := map.digest()
	map.passages[0].position.x += 0.1
	assert_str(map.digest()).is_not_equal(before)


func test_interactables_get_the_same_net_ids_on_host_and_client() -> void:
	var host := MapData.load_map().interactables()
	var client := MapData.load_map().interactables()
	assert_int(host.size()).is_equal(24 + 6 + 14 + 1 + 6 + 7 + 3 + 3) ## doors, then hiding .. terminals
	for net_id in host.size():
		assert_str(client[net_id].id).is_equal(host[net_id].id)
	assert_str(host[0].id).is_equal(&"A1-A2") ## map order: first door in the file
	assert_str(host[24].id).is_equal(&"h1") ## then markers in file order: the first hiding spot
	assert_str(host[-1].id).is_equal(&"T3")
	assert_bool(host.any(func(i: Resource) -> bool: return i is MapMarker and i.type in [&"survivor_spawn",
		&"monster_spawn", &"camera"])).is_false()
	assert_bool(host.any(func(i: Resource) -> bool: return i is MapPassage and not i.is_door())).is_false()


## Shortest walk from any A1 exit to `target`, over passage centres joined straight within a room (every
## room and corridor is a box, so a straight line inside one is walkable). A lower bound on walking from
## anywhere in A1, since every route out passes an A1 exit.
func _walk_from_a1(map: MapData, target: MapMarker) -> float:
	var room := _room_of(map, target.volume)
	var dist := {}
	var open: Array[MapPassage] = []
	for p in map.passages:
		dist[p] = INF
		if p.a == &"A1" or p.b == &"A1":
			dist[p] = 0.0
		open.append(p)
	var best := INF
	while not open.is_empty():
		open.sort_custom(func(x: MapPassage, y: MapPassage) -> bool: return dist[x] < dist[y])
		var p: MapPassage = open.pop_front()
		if p.a == room or p.b == room:
			best = minf(best, dist[p] + p.position.distance_to(target.position))
		for q in open:
			if q.a in [p.a, p.b] or q.b in [p.a, p.b]:
				dist[q] = minf(dist[q], dist[p] + p.position.distance_to(q.position))
	return best


## AC4. Sight is checked at room level against the passage data: no M room is A1 or opens onto A1
## (A1 has no glass). A full sightline check needs walls: story 005's visibility table and the
## greybox sightline pass settle it.
func test_monster_spawns_are_25m_walk_from_a1_and_out_of_its_sight() -> void:
	var map := MapData.load_map()
	var a1_neighbours := {&"A1": true}
	for p in map.passages:
		if p.a == &"A1":
			a1_neighbours[p.b] = true
		if p.b == &"A1":
			a1_neighbours[p.a] = true
	var spawns := map.markers.filter(func(m: MapMarker) -> bool: return m.type == &"monster_spawn")
	assert_int(spawns.size()).is_equal(3)
	for m: MapMarker in spawns:
		var walk := _walk_from_a1(map, m)
		assert_float(walk).override_failure_message("%s is %.1f m from A1" % [m.id, walk]).is_greater_equal(MIN_MONSTER_WALK_M)
		assert_bool(a1_neighbours.has(_room_of(map, m.volume))).override_failure_message("%s in sight" % m.id).is_false()


func test_walk_measure_is_live() -> void:
	# The walk helper above must be able to fail: a marker in the room next to A1 is close.
	var map := MapData.load_map()
	var near := MapMarker.new()
	near.volume = &"A3"
	near.position = Vector3(5, 0, 20)
	assert_float(_walk_from_a1(map, near)).is_less(MIN_MONSTER_WALK_M)


func test_a_missing_marker_type_fails_the_load_by_name() -> void:
	var map := MapData.load_map()
	map.markers = map.markers.filter(func(m: MapMarker) -> bool: return m.type != &"hiding")
	assert_array(map.errors()).contains_exactly(["missing marker type: hiding"])


func test_a_duplicate_marker_id_fails_the_load() -> void:
	var map := MapData.load_map()
	var dup := map.markers[1].duplicate() as MapMarker
	dup.id = map.markers[0].id
	map.markers.append(dup)
	assert_array(map.errors()).contains_exactly(["duplicate id: %s" % map.markers[0].id])


func test_a_marker_outside_its_volume_fails_the_load() -> void:
	var map := MapData.load_map()
	map.markers[0].position = Vector3(55, 0, 20) ## C4, not A1
	assert_array(map.errors()).contains_exactly(["marker %s: position is not in volume A1" % map.markers[0].id])


func test_a_missing_map_file_fails_the_load() -> void:
	assert_array(MapData.load_map("res://data/maps/nope.tres").errors()).is_not_empty()


func test_a_passage_to_an_unknown_room_fails_the_load() -> void:
	var map := MapData.load_map()
	map.passages[0].b = &"Z9"
	## Its visibility door entries fail too (facility-map story 005); every other error is that one.
	var structural := Array(map.errors()).filter(func(e: String) -> bool: return not e.begins_with("volume "))
	assert_array(structural).contains_exactly(["passage %s: unknown room Z9" % map.passages[0].id])


func test_overlapping_volumes_fail_the_load() -> void:
	var map := MapData.load_map()
	map.volumes[1].box.position.x -= 0.5 ## A2-N pushed into A6
	assert_array(map.errors()).contains([&"volumes overlap: A2-N A6"])
