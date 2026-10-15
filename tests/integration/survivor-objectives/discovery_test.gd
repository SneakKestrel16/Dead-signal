# Story survivor-objectives/009: objective discovery (survivor-objectives.md rule 7; ADR-0012 §1-5).
# Real SurvivorObjectives on the real map and knobs; eyes, yaws, line of sight and statuses are fed by the
# test, as the composition root feeds them from ServerMovement, ViewState and MapQueries.clear_sight.
# That a discover() reaches every survivor peer and nothing reaches one before it, and that the
# shapeshifter is granted every active point at round start, is facility-map/008's
# (tests/integration/facility-map/candidate_replication_test.gd); here: who discovers what, and when.
extends GdUnitTestSuite

const SURVIVORS: Array[int] = [1, 2, 3, 4]
const MONSTER := 5
## Far from every marker: a survivor parked here sees nothing.
const FAR := Vector3(0.0, 1000.0, 0.0)

var _knobs: Knobs
var _map: MapData
var _obj: SurvivorObjectives
var _bus: EventBus
var _eyes: Dictionary = {}
var _yaws: Dictionary = {}
var _status: Dictionary = {}
var _hidden: Dictionary = {}
var _clear := true
var _discovered: Array[int] = []
var _events: Array[EvObjectiveProgressChanged] = []
var _drive := -1 ## marker index of active drive 0
var _box: int ## marker index of an active fuse box


func before_test() -> void:
	_knobs = Knobs.load_all()
	_map = MapData.load_map()
	_eyes = {}
	_yaws = {}
	_status = {}
	_hidden = {}
	_clear = true
	_discovered = []
	_events = []
	_drive = -1
	for id in SURVIVORS + [MONSTER]:
		_eyes[id] = FAR
		_yaws[id] = 0.0
		_status[id] = MatchFlow.Status.HEALTHY
	var holds := HoldService.new(_knobs, func() -> Array: return [], func(_a: int) -> Array: return [],
		func(_a: int) -> Vector3: return Vector3.ZERO, func(_a: int, _i: Interactable) -> bool: return true,
		func(_a: int) -> int: return -1)
	_obj = SurvivorObjectives.new(holds, _map, Callable(), _is_hidden)
	_obj.placement = CandidateSelection.valid_placements(_map)[0]
	_obj.survivor_ids.assign(SURVIVORS)
	_obj.set_discovery(_eye_of, _yaw_of, _sight, _discover, _status_of)
	_bus = EventBus.new(_knobs.core.max_flush_rounds)
	_bus.subscribe(&"ObjectiveProgressChanged", _on_progress)
	_obj.setup(null, _bus, StateRegistry.new(), _knobs)
	for i in _obj.active():
		if _map.markers[i].type == &"drive" and _drive == -1:
			_drive = i
		if _map.markers[i].type == &"fuse_box":
			_box = i


func _eye_of(id: int) -> Vector3:
	return _eyes[id]


func _yaw_of(id: int) -> float:
	return _yaws[id]


func _sight(_eye: Vector3, _point: Vector3) -> bool:
	return _clear


func _discover(index: int) -> bool:
	_discovered.append(index)
	return true


func _status_of(id: int) -> MatchFlow.Status:
	return _status[id]


func _is_hidden(id: int) -> bool:
	return _hidden.get(id, false)


func _on_progress(e: ServerEvent) -> void:
	_events.append(e as EvObjectiveProgressChanged)


## The marker's sample point (floor position raised to the capsule centre).
func _sample(index: int) -> Vector3:
	return _map.markers[index].position + Vector3.UP * _knobs.controller.capsule_height_m / 2.0


## Puts `id`'s eye `d` metres due south (+Z) of marker `index`'s sample point; yaw 0 faces it.
func _place(id: int, index: int, d: float, yaw := 0.0) -> void:
	_eyes[id] = _sample(index) + Vector3(0.0, 0.0, d)
	_yaws[id] = yaw


func _tick() -> void:
	_obj.server_tick(0)
	_bus.flush()


func test_survivor_in_view_within_range_discovers_on_that_tick_once() -> void:
	var r := _knobs.objectives.discover_range_m
	_place(2, _drive, r - 0.1)
	_tick()
	assert_array(_discovered).contains([_drive])
	assert_int(_discovered.count(_drive)).is_equal(1)
	_tick() ## permanent: never re-discovered
	assert_int(_discovered.count(_drive)).is_equal(1)
	var e: EvObjectiveProgressChanged = _events.filter(func(x: EvObjectiveProgressChanged) -> bool:
		return x.objective == SurvivorObjectives.DRIVE_ID).back()
	assert_bool(e.discovered).is_true()
	assert_int(e.state).is_equal(SurvivorObjectives.DriveState.SECURED)
	assert_bool(e.project(3, null, MONSTER).is_empty()).is_false() ## every survivor now gets it


func test_out_of_range_facing_away_or_blocked_does_not_discover() -> void:
	var r := _knobs.objectives.discover_range_m
	_place(1, _drive, r + 0.1)
	_tick()
	_place(1, _drive, r - 0.1, PI)
	_tick()
	_place(1, _drive, 1.0, deg_to_rad(_knobs.objectives.discover_fov_deg / 2.0 + 1.0))
	_tick()
	_place(1, _drive, r - 0.1)
	_clear = false
	_tick()
	assert_array(_discovered).not_contains([_drive])
	assert_bool(_events.any(func(x: EvObjectiveProgressChanged) -> bool:
		return x.objective == SurvivorObjectives.DRIVE_ID)).is_false()
	_place(1, _drive, 1.0, deg_to_rad(_knobs.objectives.discover_fov_deg / 2.0 - 1.0)) ## inside the cone edge
	_clear = true
	_tick()
	assert_array(_discovered).contains([_drive])


func test_hidden_escaped_eliminated_survivors_and_the_shapeshifter_never_discover() -> void:
	_place(MONSTER, _drive, 1.0)
	_place(1, _drive, 1.0)
	_hidden[1] = true
	_place(2, _drive, 1.0)
	_status[2] = MatchFlow.Status.ESCAPED
	_place(3, _drive, 1.0)
	_status[3] = MatchFlow.Status.ELIMINATED
	_tick()
	assert_array(_discovered).is_empty()
	_place(4, _drive, 1.0)
	_status[4] = MatchFlow.Status.DOWNED ## Downed survivors can discover (ADR-0012 §3)
	_tick()
	assert_array(_discovered).contains([_drive])


func test_always_known_points_never_go_through_discovery() -> void:
	_place(1, _box, 1.0)
	_tick()
	assert_array(_discovered).not_contains([_box])
	for id in SURVIVORS: ## every hidden point seen: exactly the two drive rooms and two fuse spawns
		_eyes[id] = FAR
	for i in _obj.active():
		_place(1, i, 1.0)
		_tick()
	_discovered.sort()
	var hidden: Array[int] = []
	for i in _obj.active():
		if _map.markers[i].type in [&"drive", &"fuse"]:
			hidden.append(i)
	hidden.sort()
	assert_array(_discovered).is_equal(hidden)
