extends GdUnitTestSuite
## BUG-0016: PingCalloutHud.place on a point in the camera plane (zero depth: the camera's own position, or
## level with it). Camera3D.unproject_position divides by that depth and logs `p.d == 0`; place must not call
## it there, and must report the point off-screen, edge-clamped, pointing the way it lies.

const INSET := 48.0

var _camera: Camera3D
var _size: Vector2


func before_test() -> void:
	var view: SubViewport = auto_free(SubViewport.new())
	view.size = Vector2i(1920, 1080)
	add_child(view)
	_camera = Camera3D.new()
	view.add_child(_camera) # at the origin facing -Z
	_size = _camera.get_viewport().get_visible_rect().size


func _place(point: Vector3) -> Array:
	return PingCalloutHud.place(_camera, point, _size, INSET)


func test_marker_at_the_camera_position_logs_no_error_and_is_off_screen() -> void:
	await assert_error(func() -> void: _place(Vector3.ZERO)).is_success()
	var pl := _place(Vector3.ZERO)
	assert_bool(pl[1]).is_true()
	var at: Vector2 = pl[0]
	assert_bool(Rect2(Vector2.ONE * INSET, _size - Vector2.ONE * INSET * 2.0).grow(0.5).has_point(at)).is_true()
	assert_bool(at.is_equal_approx(_size / 2.0)).is_false() # clamped to an edge, not left in the centre


func test_marker_level_with_the_camera_to_the_right_clamps_to_the_right_edge_pointing_right() -> void:
	await assert_error(func() -> void: _place(Vector3(5, 0, 0))).is_success()
	var pl := _place(Vector3(5, 0, 0))
	assert_bool(pl[1]).is_true()
	assert_float((pl[0] as Vector2).x).is_equal_approx(_size.x - INSET, 0.5)
	assert_float((pl[0] as Vector2).y).is_equal_approx(_size.y / 2.0, 0.5)
	assert_float(pl[2]).is_equal_approx(0.0, 1e-3)
