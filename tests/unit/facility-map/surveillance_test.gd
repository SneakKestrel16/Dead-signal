# Story facility-map/011: the C1 monitor's camera feeds, server side (research-facility.md Surveillance;
# ADR-0009 §8). The monitor cycles camera 1 -> 4 -> off per press, turns off on leaving range, another hold
# or a lock, widens the viewer's relevance by the camera's volumes and tells only the viewer its camera.
extends GdUnitTestSuite

const VIEWER := 1
const OTHER := 2

var _knobs: Knobs
var _map: MapData
var _cams: Surveillance
var _centre: Dictionary[int, Vector3] = {}
var _holds: Dictionary[int, Dictionary] = {}
var _free: Dictionary[int, bool] = {}
var _closed: Dictionary[StringName, bool] = {}


func before_test() -> void:
	_knobs = Knobs.load_all()
	_map = MapData.load_map()
	_cams = Surveillance.new(_map, _knobs, _can_view, _centre_of, _hold_of, _door_closed)
	_centre = {VIEWER: _cams.point, OTHER: _cams.point}
	_holds = {}
	_free = {}
	_closed = {}


func _can_view(actor: int) -> bool:
	return _free.get(actor, true)


func _centre_of(actor: int) -> Vector3:
	return _centre[actor]


func _hold_of(actor: int) -> Dictionary:
	return _holds.get(actor, {})


func _door_closed(door: StringName) -> bool:
	return _closed.get(door, false)


func _camera_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for m in _map.markers:
		if m.type == &"camera":
			out.append(m.id)
	return out


func test_monitor_is_an_instant_unfakeable_interactable_at_the_monitor_marker() -> void:
	var monitor: MapMarker
	for m in _map.markers:
		if m.type == &"monitor":
			monitor = m
	var rules := MapQueries.InteractRules.from_knobs(_knobs)
	assert_vector(_cams.point).is_equal(monitor.position + Vector3.UP * rules.point_height_m)
	assert_float(_cams.range_m).is_equal(rules.range_by_type[&"monitor"])
	assert_float(_cams.duration_s).is_equal(0.0)
	assert_bool(_cams.fakeable).is_false()
	assert_array(_cams.camera_ids()).is_equal(_camera_ids())


func test_each_press_cycles_camera_one_to_four_then_off_per_player() -> void:
	assert_int(_cams.viewed_camera(VIEWER)).is_equal(Surveillance.OFF)
	var seen: Array[int] = []
	for i in 5:
		_cams.on_complete(VIEWER)
		seen.append(_cams.viewed_camera(VIEWER))
	assert_array(seen).is_equal([0, 1, 2, 3, Surveillance.OFF])
	assert_int(_cams.viewed_camera(OTHER)).is_equal(Surveillance.OFF)


func test_any_player_may_view_unless_locked() -> void:
	assert_bool(_cams.eligible(OTHER)).is_true()
	_free[OTHER] = false
	assert_bool(_cams.eligible(OTHER)).is_false()


func test_viewing_turns_off_on_leaving_range_another_hold_or_a_lock() -> void:
	_cams.on_complete(VIEWER)
	_cams.server_tick(1)
	assert_int(_cams.viewed_camera(VIEWER)).is_equal(0)
	# Within the hold tolerance it stays on (inference: the hold continuation range, ADR-0008).
	_centre[VIEWER] = _cams.point + Vector3(_cams.range_m + _knobs.controller.hold_range_tolerance_m * 0.5, 0, 0)
	_cams.server_tick(2)
	assert_int(_cams.viewed_camera(VIEWER)).is_equal(0)
	_centre[VIEWER] = _cams.point + Vector3(_cams.range_m + _knobs.controller.hold_range_tolerance_m * 1.5, 0, 0)
	_cams.server_tick(3)
	assert_int(_cams.viewed_camera(VIEWER)).is_equal(Surveillance.OFF)

	_centre[VIEWER] = _cams.point
	_cams.on_complete(VIEWER)
	_holds[VIEWER] = {"net_id": 7}
	_cams.server_tick(4)
	assert_int(_cams.viewed_camera(VIEWER)).is_equal(Surveillance.OFF)

	_holds.clear()
	_cams.on_complete(VIEWER)
	_free[VIEWER] = false # shocked, Seized or Downed
	_cams.server_tick(5)
	assert_int(_cams.viewed_camera(VIEWER)).is_equal(Surveillance.OFF)


func test_extra_volumes_are_the_viewed_cameras_volume_and_its_door_cut_visible_set() -> void:
	assert_array(Array(_cams.extra_volumes(VIEWER))).is_empty()
	_cams.on_complete(VIEWER) # c1, B1
	var q := MapQueries.new(_map)
	var want := Array(q.visible_set(&"B1"))
	want.append(&"B1")
	assert_array(Array(_cams.extra_volumes(VIEWER))).contains_exactly_in_any_order(want)
	for v in _map.volumes:
		if v.id == &"B1":
			for seen: StringName in v.sees:
				if v.sees[seen] != &"":
					_closed[v.sees[seen]] = true
	assert_array(Array(_cams.extra_volumes(VIEWER))).contains_exactly_in_any_order(
			Array(q.visible_set(&"B1", _door_closed)) + [&"B1"])
	assert_array(Array(_cams.extra_volumes(OTHER))).is_empty()


func test_camera_entry_goes_to_the_viewer_once_per_change_and_again_on_catch_up() -> void:
	assert_array(_cams.camera_entries(VIEWER)).is_empty()
	_cams.on_complete(VIEWER)
	assert_array(_cams.camera_entries(VIEWER)).is_equal([[EventBatch.CAMERA, {"camera": 0}]])
	assert_array(_cams.camera_entries(VIEWER)).is_empty()
	assert_array(_cams.camera_entries(OTHER)).is_empty()
	assert_array(_cams.camera_entries(VIEWER, true)).is_equal([[EventBatch.CAMERA, {"camera": 0}]])
	_free[VIEWER] = false
	_cams.server_tick(1)
	assert_array(_cams.camera_entries(VIEWER)).is_equal([[EventBatch.CAMERA, {"camera": Surveillance.OFF}]])


func test_a_body_on_the_viewed_camera_is_relevant_to_a_far_viewer_only_while_viewing() -> void:
	_knobs.net.relevance_linger_s = 0.0 # no linger: each update reads this tick's rule alone
	var q := MapQueries.new(_map)
	var rel := Relevance.new(_knobs)
	rel.volume_at = q.volume_at
	rel.visible_volumes = q.visible_set
	rel.extra_volumes = _cams.extra_volumes
	var positions := {VIEWER: Vector3(51, 0, 8), OTHER: Vector3(30, 0, 22)} # C1 monitor, B1 by the Core
	assert_array(rel.update(1, VIEWER, positions)).is_empty()
	_cams.on_complete(VIEWER)
	assert_array(rel.update(2, VIEWER, positions)).is_equal([OTHER])
	_cams.on_complete(VIEWER) # c2, H-S: B1 is not on it
	assert_array(rel.update(3, VIEWER, positions)).is_empty()


func test_round_end_resets_every_viewer() -> void:
	var server: RoundServer = auto_free(RoundServer.new())
	assert_array(server.start_round({TickOrder.SURVEILLANCE: _cams}, _knobs)).is_empty()
	_cams.on_complete(VIEWER)
	server.bus.emit(EvRoundEnded.new())
	server.bus.flush()
	assert_int(_cams.viewed_camera(VIEWER)).is_equal(Surveillance.OFF)
	server.end_round()


func test_a_camera_marker_without_yaw_fails_the_map() -> void:
	assert_array(Array(_map.errors())).is_empty()
	for m in _map.markers:
		if m.type == &"camera":
			m.yaw_deg = NAN
			break
	assert_str(";".join(_map.errors())).contains("camera marker has no yaw_deg")
