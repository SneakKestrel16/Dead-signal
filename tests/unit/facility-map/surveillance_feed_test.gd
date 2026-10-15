# Story facility-map/011: the client's C1 monitor feed (ADR-0009 §8). One SubViewport sharing the main
# World3D, a Camera3D at the viewed camera's authored transform, live only while viewing. The feed draws
# the same bodies as the main view, so a disguised shapeshifter shows its disguise (the server's appearance).
extends GdUnitTestSuite

var _knobs: Knobs
var _map: MapData
var _feed: SurveillanceFeed


func before_test() -> void:
	_knobs = Knobs.load_all()
	_map = MapData.load_map()
	_feed = SurveillanceFeed.new(_map, _knobs)
	add_child(_feed)


func after_test() -> void:
	_feed.free()


func _cameras() -> Array[MapMarker]:
	var out: Array[MapMarker] = []
	for m in _map.markers:
		if m.type == &"camera":
			out.append(m)
	return out


func _ceiling(volume: StringName) -> float:
	for v in _map.volumes:
		if v.id == volume:
			return v.box.end.y
	return NAN


func test_feed_starts_off_with_the_knob_resolution_and_no_shadows() -> void:
	assert_int(_feed.current).is_equal(Surveillance.OFF)
	assert_int(_feed.viewport.render_target_update_mode).is_equal(SubViewport.UPDATE_DISABLED)
	assert_bool(_feed.screen.visible).is_false()
	assert_int(_feed.viewport.size.y).is_equal(_knobs.facility.feed_resolution)
	assert_int(_feed.viewport.positional_shadow_atlas_size).is_equal(0)


func test_feed_shares_the_main_world() -> void:
	assert_bool(_feed.viewport.own_world_3d).is_false()
	assert_object(_feed.viewport.find_world_3d()).is_same(get_viewport().find_world_3d())


func test_each_camera_sits_at_its_marker_under_the_ceiling_facing_its_yaw() -> void:
	var cams := _cameras()
	assert_int(cams.size()).is_equal(4)
	for i in cams.size():
		_feed.on_camera(0, {"camera": i})
		var m := cams[i]
		assert_int(_feed.current).is_equal(i)
		assert_int(_feed.viewport.render_target_update_mode).is_equal(SubViewport.UPDATE_ALWAYS)
		assert_bool(_feed.screen.visible).is_true()
		assert_float(_feed.camera.position.x).is_equal(m.position.x)
		assert_float(_feed.camera.position.z).is_equal(m.position.z)
		assert_float(_feed.camera.position.y).is_equal_approx(
				_ceiling(m.volume) - SurveillanceFeed.MOUNT_BELOW_CEILING_M, 1e-4)
		assert_float(_feed.camera.rotation.y).is_equal_approx(deg_to_rad(m.yaw_deg), 1e-4)


func test_off_disables_the_viewport_and_hides_the_screen() -> void:
	_feed.on_camera(0, {"camera": 2})
	_feed.on_camera(0, {"camera": Surveillance.OFF})
	assert_int(_feed.current).is_equal(Surveillance.OFF)
	assert_int(_feed.viewport.render_target_update_mode).is_equal(SubViewport.UPDATE_DISABLED)
	assert_bool(_feed.screen.visible).is_false()


func test_a_bad_camera_payload_changes_nothing() -> void:
	_feed.on_camera(0, {"camera": 1})
	for bad: Dictionary in [{"camera": 4}, {"camera": -2}, {"camera": "1"}, {}]:
		_feed.on_camera(0, bad)
		assert_int(_feed.current).is_equal(1)


func test_the_feed_camera_does_not_draw_the_monitor_screen() -> void:
	assert_int(_feed.screen.layers & _feed.camera.cull_mask).is_equal(0)
	assert_int(_feed.screen.layers).is_not_equal(0)
