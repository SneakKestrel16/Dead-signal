# Story facility-map/004: analytic zones, terminal zone and exit gating (research-facility.md AC 10,
# Technical Notes "Server authority"; ADR-0007 §9). Zones are point-in-box tests over the shipped map's
# authored zones; the exit blocker of the greybox opens only on the server's TerminalState.ACTIVATED.
extends GdUnitTestSuite

const SCENE := "res://assets/levels/research_facility.tscn"
const EXIT_ID := &"C4-Outside"
## A point inside no zone: B1, the Server Hall.
const NO_ZONE := Vector3(28.0, 0.0, 23.0)
## Five survivors in C4 facing exit E's opening (60, 20), as five clients interacting early.
const CLIENT_EYES: Array[Vector3] = [Vector3(58.0, 1.6, 20.0), Vector3(58.5, 1.6, 19.0),
	Vector3(58.5, 1.6, 21.0), Vector3(57.5, 1.6, 18.5), Vector3(57.5, 1.6, 21.5)]

var _map: MapData
var _q: MapQueries


func before_test() -> void:
	_map = MapData.load_map()
	_q = MapQueries.new(_map)


func _zone(kind: StringName) -> Array[MapZone]:
	var out: Array[MapZone] = []
	for z in _map.zones:
		if z.kind == kind:
			out.append(z)
	return out


func _kind_at(point: Vector3) -> StringName:
	var id := _q.zone_at(point)
	for z in _map.zones:
		if z.id == id:
			return z.kind
	return &""


# --- AC1: zone_at inside, on the edge, outside --------------------------------

func test_the_shipped_map_authors_an_exit_three_terminal_zones_and_four_spawn_rooms() -> void:
	assert_array(_map.errors()).is_empty()
	assert_int(_zone(MapZone.EXIT).size()).is_equal(1)
	assert_int(_zone(MapZone.TERMINAL).size()).is_equal(3)
	assert_int(_zone(MapZone.SURVIVOR_SPAWN).size()).is_equal(1)
	assert_int(_zone(MapZone.MONSTER_SPAWN).size()).is_equal(3)


func test_every_zone_holds_its_inside_and_north_west_edges_not_its_east_or_south_edge() -> void:
	for z in _map.zones:
		var nw := z.box.position
		var c := z.box.get_center()
		assert_bool(_q.in_zone(z.id, c)).override_failure_message("%s centre" % z.id).is_true()
		assert_bool(_q.in_zone(z.id, nw)).override_failure_message("%s NW edge" % z.id).is_true()
		assert_bool(_q.in_zone(z.id, Vector3(z.box.end.x, 0.0, c.z))).override_failure_message("%s east edge" % z.id).is_false()
		assert_bool(_q.in_zone(z.id, Vector3(c.x, 0.0, z.box.end.z))).override_failure_message("%s south edge" % z.id).is_false()
		assert_bool(_q.in_zone(z.id, nw - Vector3(0.01, 0.0, 0.0))).override_failure_message("%s west" % z.id).is_false()
		assert_bool(_q.in_zone(z.id, NO_ZONE)).is_false()


func test_zone_at_names_the_zone_inside_and_none_outside() -> void:
	assert_str(_q.zone_at(Vector3(61.0, 0.0, 20.0))).is_equal(_zone(MapZone.EXIT)[0].id)
	assert_str(_q.zone_at(Vector3(60.0, 0.0, 18.0))).is_equal(_zone(MapZone.EXIT)[0].id) ## doorway line, NW corner
	assert_str(_q.zone_at(Vector3(60.0, 0.0, 22.0))).is_equal(&"") ## south edge of the opening
	assert_str(_q.zone_at(NO_ZONE)).is_equal(&"")
	assert_str(_q.zone_at(Vector3(-1.0, 0.0, 30.0))).is_equal(&"") ## west of A1, off the map
	for z in _zone(MapZone.SURVIVOR_SPAWN) + _zone(MapZone.MONSTER_SPAWN) + _zone(MapZone.EXIT):
		## Inner south-east corner: C3's north-west corner is also T3's terminal zone.
		assert_str(_q.zone_at(z.box.end - Vector3(0.01, 0.0, 0.01))).override_failure_message(String(z.id)).is_equal(z.id)


func test_every_spawn_and_terminal_marker_lies_in_a_zone_of_its_type() -> void:
	for m in _map.markers:
		if m.type in [MapZone.TERMINAL, MapZone.SURVIVOR_SPAWN, MapZone.MONSTER_SPAWN]:
			assert_str(_kind_at(m.position)).override_failure_message(String(m.id)).is_equal(m.type)


func test_a_terminal_zone_inside_a_spawn_room_wins_zone_at_and_both_answer_in_zone() -> void:
	var t3 := Vector3(43.0, 0.0, 31.0) ## T3 in C3, which is also monster spawn room M1
	assert_str(_kind_at(t3)).is_equal(MapZone.TERMINAL)
	var spawn_ids := _zone(MapZone.MONSTER_SPAWN).filter(func(z: MapZone) -> bool: return _q.in_zone(z.id, t3))
	assert_int(spawn_ids.size()).is_equal(1)


func test_in_exit_reads_the_authored_exit_volume() -> void:
	assert_bool(_q.in_exit(Vector3(61.0, 0.0, 20.0))).is_true()
	assert_bool(_q.in_exit(Vector3(60.0, 0.0, 20.0))).is_true() ## doorway line: past C4's east edge
	assert_bool(_q.in_exit(Vector3(59.9, 0.0, 20.0))).is_false() ## still in C4
	assert_bool(_q.in_exit(Vector3(61.0, 0.0, 23.0))).is_false() ## beside the opening, outside the wall
	assert_bool(MapQueries.new(MapData.new()).in_exit(Vector3(61.0, 0.0, 20.0))).is_false()


func test_an_unknown_zone_kind_and_an_exit_without_a_volume_fail_the_load() -> void:
	_zone(MapZone.TERMINAL)[0].kind = &"lobby"
	var exit := _zone(MapZone.EXIT)[0]
	_map.zones.erase(exit)
	assert_array(_map.errors()).contains_exactly(["zone %s: unknown kind lobby" % _zone(&"lobby")[0].id,
		"passage %s: no exit zone at its opening" % EXIT_ID])


# --- AC2: exit E stays closed until the server reports activation ------------

func _level() -> Node3D:
	var level: Node3D = auto_free(load(SCENE).instantiate())
	add_child(level)
	return level


func _exit_shape(level: Node3D) -> CollisionShape3D:
	for body in level.find_children("*", "StaticBody3D", true, false):
		if body.get_meta(&"passage", &"") == EXIT_ID:
			return body.get_node("Shape") as CollisionShape3D
	return null


func _progress(objective: int, state: int) -> EvObjectiveProgressChanged:
	var e := EvObjectiveProgressChanged.new()
	e.objective = objective
	e.state = state
	return e


func test_five_early_interacts_open_the_exit_zero_times() -> void:
	var level := _level()
	var gate := ExitGate.new(_exit_shape(level))
	await get_tree().physics_frame
	var rules := MapQueries.InteractRules.from_knobs(Knobs.load_all())
	var space := level.get_world_3d().direct_space_state
	var targets := _map.interactables()
	for eye in CLIENT_EYES:
		var id := _q.interactable_on_ray(eye, Vector3(60.0, 1.0, 20.0) - eye, eye, rules, space)
		## The exit is no interactable: nothing a client aims at can be it.
		assert_bool(id >= 0 and targets[id] is MapPassage and (targets[id] as MapPassage).kind == MapPassage.EXIT).is_false()
	assert_bool(gate.is_open()).is_false()
	assert_bool(_exit_shape(level).disabled).is_false()


func test_the_exit_opens_only_on_the_terminal_activated_state() -> void:
	var shape := _exit_shape(_level())
	var gate := ExitGate.new(shape)
	var bus := EventBus.new(1)
	gate.subscribe(bus)
	const T := SurvivorObjectives.TERMINAL_ID
	const ACTIVATED := SurvivorObjectives.TerminalState.ACTIVATED
	for e: EvObjectiveProgressChanged in [_progress(T, SurvivorObjectives.TerminalState.ARMED),
			_progress(T, SurvivorObjectives.TerminalState.ACTIVATING), _progress(T, SurvivorObjectives.TerminalState.POWERED),
			_progress(SurvivorObjectives.DRIVE_ID, ACTIVATED), _progress(SurvivorObjectives.FUSE_ID, ACTIVATED)]:
		bus.emit(e)
		bus.flush()
		assert_bool(shape.disabled).override_failure_message("opened on %d/%d" % [e.objective, e.state]).is_false()
	bus.emit(_progress(T, ACTIVATED))
	bus.flush()
	assert_bool(gate.is_open()).is_true()
	assert_bool(shape.disabled).is_true()


func test_a_client_applies_the_servers_exit_state_from_the_replicated_entry() -> void:
	var shape := _exit_shape(_level())
	var gate := ExitGate.new(shape)
	gate.apply({"objective": SurvivorObjectives.TERMINAL_ID, "state": SurvivorObjectives.TerminalState.ACTIVATING})
	assert_bool(shape.disabled).is_false()
	gate.apply({"objective": "30", "state": 3}) ## malformed: ignored, never opens
	assert_bool(shape.disabled).is_false()
	gate.apply({"objective": SurvivorObjectives.TERMINAL_ID, "state": SurvivorObjectives.TerminalState.ACTIVATED})
	assert_bool(shape.disabled).is_true()
