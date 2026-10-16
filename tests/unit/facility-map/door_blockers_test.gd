# BUG-0018: door state drives the level's door blockers and leaves (ADR-0007 §5). A closed or barricaded door
# enables its leaf collider and shows its leaf, an open one disables and hides it; the exit stays closed until
# the server reports Exit Open (research-facility.md AC 10). The client applies the server's replicated
# EventBatch.DOORS and EventBatch.BARRICADE entries through the same object, rejecting malformed bytes.
# Doors.door_entries sends that state to everyone on change and in full on a rejoin.
extends GdUnitTestSuite

var _map: MapData
var _knobs: Knobs
var _mats: SurfaceMaterials
var _root: Node3D
var _blockers: DoorBlockers
## Net ids of the map's doors, and the id of one barricadable door.
var _doors: Array[int] = []
var _barricadable := -1


func before_test() -> void:
	_map = MapData.load_map()
	_knobs = Knobs.load_all()
	_mats = load(MapGreybox.SURFACES) as SurfaceMaterials
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	_root = MapGreybox.build(holder, _map)
	_blockers = DoorBlockers.new(_root, _map)
	_doors = []
	var targets := _map.interactables()
	for i in targets.size():
		var p := targets[i] as MapPassage
		if p != null:
			_doors.append(i)
			if p.kind == MapPassage.BARRICADABLE and _barricadable < 0:
				_barricadable = i


func _body(passage: StringName) -> StaticBody3D:
	for b: Node in _root.find_children("Door_*", "StaticBody3D", true, false):
		if b.get_meta(&"passage", &"") == passage:
			return b
	return null


func _body_of(net_id: int) -> StaticBody3D:
	return _body((_map.interactables()[net_id] as MapPassage).id)


func _exit() -> StaticBody3D:
	for p in _map.passages:
		if p.kind == MapPassage.EXIT:
			return _body(p.id)
	return null


func _closed(body: StaticBody3D) -> bool:
	return not (body.get_node(^"Shape") as CollisionShape3D).disabled


func _leaf(body: StaticBody3D) -> MeshInstance3D:
	return body.get_node(^"Mesh") as MeshInstance3D


func _states(closed_ids: Array) -> Array[bool]:
	var out: Array[bool] = []
	for i in _doors.size():
		out.append(i in closed_ids)
	return out


func test_the_level_starts_with_every_door_open_and_undrawn_and_the_exit_closed_and_drawn() -> void:
	assert_int(_doors.size()).is_greater(0)
	for d in _doors:
		var b := _body_of(d)
		assert_object(b).is_not_null()
		assert_bool(_closed(b)).is_false()
		assert_bool(_leaf(b).visible).is_false()
		assert_object(_leaf(b).material_override).is_same(_mats.door)
	assert_bool(_closed(_exit())).is_true()
	assert_bool(_leaf(_exit()).visible).is_true()


func test_apply_enables_and_draws_exactly_the_closed_doors() -> void:
	var d := _doors[0]
	_blockers.apply(_states([d]))
	for i in _doors:
		assert_bool(_closed(_body_of(i))).override_failure_message("door %d" % i).is_equal(i == d)
		assert_bool(_leaf(_body_of(i)).visible).override_failure_message("door %d leaf" % i).is_equal(i == d)
	_blockers.apply(_states([]))
	assert_bool(_closed(_body_of(d))).is_false()
	assert_bool(_leaf(_body_of(d)).visible).is_false()


func test_the_drawn_leaf_is_the_sight_leaf() -> void:
	# The collider and mesh the level carries are the leaf MapQueries cuts sight with (MapQueries._leaf).
	for d in _doors:
		var p := _map.interactables()[d] as MapPassage
		var b := _body_of(d)
		var size := ((b.get_node(^"Shape") as CollisionShape3D).shape as BoxShape3D).size
		var want := MapQueries._leaf(p)
		var got := AABB(b.position - size / 2.0, size)
		assert_vector(got.position).override_failure_message(String(p.id)).is_equal_approx(want.position, Vector3.ONE * 1e-3)
		assert_vector(got.size).override_failure_message(String(p.id)).is_equal_approx(want.size, Vector3.ONE * 1e-3)
		assert_vector((_leaf(b).mesh as BoxMesh).size).is_equal_approx(size, Vector3.ONE * 1e-3)


func test_a_replicated_doors_entry_sets_doors_and_the_exit() -> void:
	var d := _doors[1]
	_blockers.on_doors(5, {"closed": _states([d]), "exit": true})
	assert_bool(_closed(_body_of(d))).is_true()
	assert_bool(_leaf(_body_of(d)).visible).is_true()
	assert_bool(_closed(_body_of(_doors[0]))).is_false()
	assert_bool(_closed(_exit())).is_false()
	assert_bool(_leaf(_exit()).visible).is_false()
	_blockers.on_doors(6, {"closed": _states([]), "exit": false})
	assert_bool(_closed(_body_of(d))).is_false()
	assert_bool(_closed(_exit())).is_true()


func test_a_malformed_doors_entry_changes_nothing() -> void:
	var d := _doors[0]
	var too_long := _states([d])
	too_long.append(true)
	var not_bool: Array = [1] ## a typed copy would refuse the int
	not_bool.append_array(_states([d]).slice(1))
	for bad: Dictionary in [{}, {"closed": "x", "exit": true}, {"closed": _states([d])},
			{"closed": _states([d]), "exit": 1}, {"closed": too_long, "exit": true},
			{"closed": not_bool, "exit": true}, {"closed": _states([d]).slice(1), "exit": true}]:
		_blockers.on_doors(1, bad)
		assert_bool(_closed(_body_of(d))).override_failure_message(str(bad)).is_false()
		assert_bool(_closed(_exit())).override_failure_message(str(bad)).is_true()


func test_a_barricade_entry_draws_and_removes_the_planks() -> void:
	var b := _body_of(_barricadable)
	assert_object(b.get_node_or_null(^"Planks")).is_null()
	_blockers.on_barricade(3, {"door": _barricadable, "barricaded": true, "lockout_end": -1})
	var planks := b.get_node(^"Planks") as Node3D
	assert_bool(planks.visible).is_true()
	assert_int(planks.get_child_count()).is_greater(0)
	assert_object((planks.get_child(0) as MeshInstance3D).material_override).is_same(_mats.barricade)
	_blockers.on_barricade(4, {"door": _barricadable, "barricaded": false, "lockout_end": 4})
	assert_bool(planks.visible).is_false()
	# A second blockers object on the same level (several clients in one world) reuses the planks.
	DoorBlockers.new(_root, _map).on_barricade(5, {"door": _barricadable, "barricaded": true, "lockout_end": -1})
	assert_int(b.find_children("Planks", "", false, false).size()).is_equal(1)
	assert_bool(planks.visible).is_true()


func test_a_malformed_barricade_entry_changes_nothing() -> void:
	for bad: Dictionary in [{}, {"door": _barricadable}, {"door": "x", "barricaded": true},
			{"door": _barricadable, "barricaded": 1}, {"door": 9999, "barricaded": true},
			{"door": -1, "barricaded": true}]:
		_blockers.on_barricade(1, bad)
	for d in _doors:
		assert_object(_body_of(d).get_node_or_null(^"Planks")).is_null()


func test_door_entries_send_changes_once_and_everything_on_a_rejoin() -> void:
	var holds := HoldService.new(_knobs, func() -> Array: return [],
		func(_a: int) -> Array: return [], func(_a: int) -> Vector3: return Vector3.ZERO,
		func(_a: int, _i: Interactable) -> bool: return true, func(_a: int) -> int: return -1)
	var exit := [false]
	var doors := Doors.new(holds, _map, func() -> Array[Vector4]: return [] as Array[Vector4])
	doors.exit_open = func() -> bool: return exit[0]
	var registry := StateRegistry.new()
	doors.setup(null, null, registry, _knobs)
	doors.blockers = _blockers
	# Nothing changed since the level's start state: nothing to send, but a rejoin gets the whole state.
	assert_array(doors.door_entries(2)).is_empty()
	var full: Array = doors.door_entries(2, true)
	assert_array(full).is_equal([[EventBatch.DOORS, {"closed": _states([]), "exit": false}]])
	var d := _doors[0]
	assert_bool(doors.toggle(d)).is_true()
	assert_bool(_closed(_body_of(d))).is_true()
	assert_array(doors.door_entries(2)).is_equal([[EventBatch.DOORS, {"closed": _states([d]), "exit": false}]])
	assert_array(doors.door_entries(2)).is_empty()
	# Exit Open: the server's blocker opens on Doors' tick and the change goes out.
	exit[0] = true
	doors.server_tick(1)
	assert_bool(_closed(_exit())).is_false()
	assert_array(doors.door_entries(3)).is_equal([[EventBatch.DOORS, {"closed": _states([d]), "exit": true}]])
	registry.clear()
