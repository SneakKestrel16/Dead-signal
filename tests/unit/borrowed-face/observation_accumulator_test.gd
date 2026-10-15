# Story borrowed-face/001: observation accumulator (design/gdd/borrowed-face.md rules 1-3, Formulas
# "Observation accumulation", Acceptance Criteria on observation). The sight sources are stubs; the
# last tests run MapQueries.clear_sight against real static bodies (ADR-0007 §5, ADR-0003 §6).
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const S2 := 3
const SURVIVORS: Array[int] = [2, 3]
const EYE := Vector3(0.0, 1.6, 0.0)
## observe_time_s 3 s at 60 Hz (data/knobs/borrowed_face.tres, net.tres).
const OBSERVE_TICKS := 180

var _server: RoundServer
var _bf: BorrowedFace
var _knobs: Knobs
## survivor -> [head, chest, pelvis]
var _points: Dictionary[int, PackedVector3Array] = {}
## Points the stub sight ray reaches; unset = every point is in sight.
var _clear: Dictionary[Vector3, bool] = {}
var _all_clear := true
var _locked := false
var _yaw := 0.0


func before_test() -> void:
	_points = {}
	_clear = {}
	_all_clear = true
	_locked = false
	_yaw = 0.0
	_knobs = Knobs.load_all()


func _start() -> void:
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_bf = BorrowedFace.new()
	_bf.set_roster(SURVIVORS, MONSTER)
	_bf.set_sight_sources(_eye_of, _yaw_of, _points_of, _sight, _is_locked)
	assert_array(_server.start_round({TickOrder.BORROWED_FACE: _bf}, _knobs)).is_empty()


func _eye_of(_p: int) -> Vector3:
	return EYE


func _yaw_of(_p: int) -> float:
	return _yaw


func _points_of(p: int) -> PackedVector3Array:
	return _points.get(p, PackedVector3Array())


func _sight(_eye: Vector3, point: Vector3) -> bool:
	return _all_clear or _clear.has(point)


func _is_locked(_p: int) -> bool:
	return _locked


## Puts survivor `s` with its chest at eye height, `dist_m` away, `angle_deg` off -Z (yaw 0).
func _place(s: int, angle_deg: float, dist_m: float) -> void:
	var chest := EYE + Basis(Vector3.UP, deg_to_rad(angle_deg)) * Vector3.FORWARD * dist_m
	_points[s] = PackedVector3Array([chest + Vector3.UP * 0.4, chest, chest + Vector3.DOWN * 0.3])


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


func test_survivor_is_observed_after_exactly_observe_time_s_in_view() -> void:
	_place(S1, 0.0, 10.0)
	_start()
	_step(OBSERVE_TICKS - 1)
	assert_bool(_bf.observed(S1)).is_false()
	_step(1)
	assert_bool(_bf.observed(S1)).is_true()
	assert_float(_bf.observation_s(S1)).is_equal_approx(3.0, 1e-6)
	assert_bool(_bf.observed(S2)).is_false()


## GDD Formulas example: 1.5 s in view, behind a wall, 1.5 s in view -> observed (cumulative, no decay).
func test_observation_is_cumulative_and_blocked_sight_adds_nothing() -> void:
	_place(S1, 0.0, 10.0)
	_start()
	_step(OBSERVE_TICKS / 2)
	_all_clear = false # wall or closed door: no body point in sight
	_step(120)
	assert_float(_bf.observation_s(S1)).is_equal_approx(1.5, 1e-6)
	_all_clear = true
	_step(OBSERVE_TICKS / 2)
	assert_bool(_bf.observed(S1)).is_true()


func test_any_one_body_point_in_sight_is_enough() -> void:
	_place(S1, 0.0, 10.0)
	_all_clear = false
	_clear[_points[S1][2]] = true # pelvis only
	_start()
	_step(10)
	assert_float(_bf.observation_s(S1)).is_equal_approx(10.0 / 60.0, 1e-6)


func test_range_is_inclusive_at_observe_range_m() -> void:
	_place(S1, 0.0, 15.0)
	_place(S2, 0.0, 15.01)
	_start()
	_step(10)
	assert_float(_bf.observation_s(S1)).is_greater(0.0)
	assert_float(_bf.observation_s(S2)).is_equal(0.0)


func test_46_degrees_off_accumulates_nothing_and_44_does() -> void:
	_place(S1, 44.0, 5.0)
	_place(S2, -46.0, 5.0)
	_start()
	_step(10)
	assert_float(_bf.observation_s(S1)).is_greater(0.0)
	assert_float(_bf.observation_s(S2)).is_equal(0.0)


## The cone is horizontal to the chest point: a head straight ahead does not count.
func test_cone_is_measured_to_the_chest_not_the_head() -> void:
	_place(S1, 46.0, 5.0)
	var pts := _points[S1]
	pts[0] = EYE + Vector3(0.0, 3.0, -5.0) # head dead ahead and high: in view at some pitch
	_points[S1] = pts
	_start()
	_step(10)
	assert_float(_bf.observation_s(S1)).is_equal(0.0)


func test_cone_follows_the_look_yaw() -> void:
	_place(S1, 90.0, 5.0)
	_yaw = deg_to_rad(90.0)
	_start()
	_step(10)
	assert_float(_bf.observation_s(S1)).is_greater(0.0)


func test_stunned_or_shock_locked_monster_accumulates_nothing() -> void:
	_place(S1, 0.0, 5.0)
	_locked = true
	_start()
	_step(OBSERVE_TICKS + 10)
	assert_float(_bf.observation_s(S1)).is_equal(0.0)
	_locked = false
	_step(1)
	assert_float(_bf.observation_s(S1)).is_equal_approx(1.0 / 60.0, 1e-6)


func test_survivor_with_no_body_accumulates_nothing() -> void:
	_start()
	_step(10)
	assert_float(_bf.observation_s(S1)).is_equal(0.0)


func test_time_range_and_cone_come_from_borrowed_face_knobs() -> void:
	_knobs.borrowed_face.observe_time_s = 1.0
	_knobs.borrowed_face.observe_range_m = 8.0
	_knobs.borrowed_face.observe_fov_deg = 60.0
	_place(S1, 29.0, 7.9)
	_place(S2, 31.0, 7.9)
	_start()
	_step(59)
	assert_bool(_bf.observed(S1)).is_false()
	_step(1)
	assert_bool(_bf.observed(S1)).is_true()
	assert_float(_bf.observation_s(S2)).is_equal(0.0)
	_place(S2, 0.0, 8.1)
	_step(1)
	assert_float(_bf.observation_s(S2)).is_equal(0.0)


func test_a_new_round_resets_observation() -> void:
	_place(S1, 0.0, 5.0)
	_start()
	_step(OBSERVE_TICKS)
	assert_bool(_bf.observed(S1)).is_true()
	_server.start_round({TickOrder.BORROWED_FACE: _bf}, _knobs)
	assert_bool(_bf.observed(S1)).is_false()
	assert_float(_bf.observation_s(S1)).is_equal(0.0)


# --- MapQueries.clear_sight: SIGHT mask plus analytic doors ----------------------------

func _wall(root: Node3D, at: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = PhysicsLayers.NONE
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 0.1)
	shape.shape = box
	body.add_child(shape)
	body.position = at
	root.add_child(body)
	return body


func test_clear_sight_wall_blocks_glass_does_not() -> void:
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	var q := MapQueries.new(MapData.new())
	var space := root.get_world_3d().direct_space_state
	var point := Vector3(0.0, 1.2, -5.0)
	assert_bool(q.clear_sight(EYE, point, Callable(), space)).is_true()
	_wall(root, Vector3(0.0, 1.0, -2.0), PhysicsLayers.GLASS)
	assert_bool(q.clear_sight(EYE, point, Callable(), space)).is_true()
	_wall(root, Vector3(0.0, 1.0, -3.0), PhysicsLayers.WORLD)
	assert_bool(q.clear_sight(EYE, point, Callable(), space)).is_false()


func test_clear_sight_closed_door_blocks_open_does_not() -> void:
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	var door := MapPassage.new()
	door.id = &"d"
	door.kind = MapPassage.DOOR
	door.position = Vector3(0.0, 0.0, -2.0)
	door.width_m = 1.0
	door.swing_box = AABB(Vector3(-0.5, 0.0, -3.0), Vector3(1.0, 2.0, 2.0))
	var map := MapData.new()
	map.passages.assign([door])
	var q := MapQueries.new(map)
	var space := root.get_world_3d().direct_space_state
	var point := Vector3(0.0, 1.2, -5.0)
	assert_bool(q.clear_sight(EYE, point, func(_id: int) -> bool: return false, space)).is_true()
	assert_bool(q.clear_sight(EYE, point, func(_id: int) -> bool: return true, space)).is_false()
