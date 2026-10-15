extends GdUnitTestSuite
## ADR-0014 Verification Required items 1, 2, 4, 5 and 6 on the installed engine (evidence:
## production/qa/evidence/ui-input-focus/adr-0014-verification.md). Events go through Input.parse_input_event,
## the same dispatch path as OS input. Numbers are printed with an "ADR14" prefix for the evidence file.
## Items 2 (hover, click) and 4 need a real window (headless ignores Input.mouse_mode and its root window has no
## size): run this suite once without --headless.

const FRAMES := 1000
const MARKERS := 40
const BUDGET_US := 200.0


func _key(code: Key, pressed: bool, unicode: int = 0) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.unicode = unicode if pressed else 0
	e.pressed = pressed
	e.device = InputEvent.DEVICE_ID_KEYBOARD
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _pad(button: JoyButton, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	e.device = 0
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _motion(at: Vector2, rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	e.relative = rel
	e.screen_relative = rel
	e.device = InputEvent.DEVICE_ID_MOUSE
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _click(at: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = at
	e.global_position = at
	e.button_index = MOUSE_BUTTON_LEFT
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	e.pressed = pressed
	e.device = InputEvent.DEVICE_ID_MOUSE
	Input.parse_input_event(e)
	Input.flush_buffered_events()


## Verification 1: a focused LineEdit consumes W (it types it), and polling still reports it held.
func test_v1_polling_reports_keys_a_focused_control_consumes() -> void:
	var field: LineEdit = auto_free(LineEdit.new())
	field.size = Vector2(200, 30)
	add_child(field)
	field.grab_focus()
	await get_tree().process_frame
	_key(KEY_W, true, 119)
	await get_tree().process_frame
	var typed := field.text
	var held := Input.is_action_pressed(&"move_forward")
	var vec := Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	_key(KEY_W, false)
	await get_tree().process_frame
	var after := Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	prints("ADR14 V1 focused=%s typed='%s' is_action_pressed=%s get_vector=%s after_release=%s"
		% [field.has_focus(), typed, held, vec, after])
	assert_str(typed).is_equal("w") # the GUI consumed the key
	assert_bool(held).is_true()
	assert_vector(vec).is_equal(Vector2(0, 1))
	assert_vector(after).is_equal(Vector2.ZERO)


## Verification 2: push grabs focus; keyboard and pad navigation start there; hover does not move focus; a
## click does; pop restores the control focused before the push.
func test_v2_push_focus_nav_hover_click_pop() -> void:
	var lower: Button = auto_free(Button.new())
	lower.text = "lower"
	lower.position = Vector2(10, 300)
	lower.size = Vector2(100, 40)
	add_child(lower)
	var box: VBoxContainer = auto_free(VBoxContainer.new())
	box.position = Vector2(10, 10)
	add_child(box)
	var b: Array[Button] = []
	for i in 4:
		var btn := Button.new()
		btn.text = "b%d" % i
		btn.custom_minimum_size = Vector2(120, 40)
		box.add_child(btn)
		b.append(btn)
	await get_tree().process_frame
	lower.grab_focus()
	var stack := InputContextStack.new(InputContextStack.Ctx.MENU)
	stack.viewport = get_viewport()
	stack.push(InputContextStack.Ctx.OVERLAY, b[0])
	await get_tree().process_frame
	var on_push := get_viewport().gui_get_focus_owner()
	_key(KEY_DOWN, true)
	_key(KEY_DOWN, false)
	await get_tree().process_frame
	var after_key := get_viewport().gui_get_focus_owner()
	_pad(JOY_BUTTON_DPAD_DOWN, true)
	_pad(JOY_BUTTON_DPAD_DOWN, false)
	await get_tree().process_frame
	var after_pad := get_viewport().gui_get_focus_owner()
	var over := b[3].get_global_rect().get_center()
	_motion(over, Vector2(5, 5))
	await get_tree().process_frame
	var hovered := b[3].is_hovered()
	var after_hover := get_viewport().gui_get_focus_owner()
	_click(over, true)
	_click(over, false)
	await get_tree().process_frame
	var after_click := get_viewport().gui_get_focus_owner()
	stack.pop(InputContextStack.Ctx.OVERLAY)
	await get_tree().process_frame
	var after_pop := get_viewport().gui_get_focus_owner()
	prints("ADR14 V2 push=%s key_down=%s pad_down=%s hover(b3 hovered=%s)=%s click=%s pop=%s" % [
		_n(on_push), _n(after_key), _n(after_pad), hovered, _n(after_hover), _n(after_click), _n(after_pop)])
	assert_object(on_push).is_same(b[0])
	assert_object(after_key).is_same(b[1])
	assert_object(after_pad).is_same(b[2])
	assert_object(after_pop).is_same(lower)
	if DisplayServer.get_name() == "headless": # the headless root window has no size, so no hover or click
		prints("ADR14 V2 hover/click not assessable headless; run this suite windowed")
		return
	assert_bool(hovered).is_true()
	assert_object(after_hover).is_same(b[2])
	assert_object(after_click).is_same(b[3])


func _n(c: Control) -> String:
	return "null" if c == null else (c as Button).text


## Verification 4 (window only): CAPTURED -> VISIBLE -> CAPTURED through the context stack; the first relative
## motion after the recapture must not turn the view (ADR-0014 §3).
func test_v4_first_motion_after_recapture_is_discarded() -> void:
	if DisplayServer.get_name() == "headless":
		prints("ADR14 V4 skipped: headless ignores Input.mouse_mode; run this suite windowed")
		return
	var li: LocalInput = auto_free(LocalInput.new())
	var stack := InputContextStack.new()
	li.contexts = stack
	add_child(li)
	await get_tree().process_frame
	var mode_start := Input.mouse_mode
	_motion(Vector2(100, 100), Vector2(10, 0))
	var normal := li.yaw
	stack.push(InputContextStack.Ctx.OVERLAY, null)
	var mode_overlay := Input.mouse_mode
	var yaw_before := li.yaw
	stack.pop(InputContextStack.Ctx.OVERLAY)
	var mode_back := Input.mouse_mode
	# A large first motion, as the cursor's travel while visible would report on recapture.
	_motion(Vector2(100, 100), Vector2(400, 0))
	var jump := li.yaw - yaw_before
	_motion(Vector2(100, 100), Vector2(10, 0))
	var second := li.yaw - yaw_before - jump
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	prints("ADR14 V4 modes %d->%d->%d; normal 10px motion yaw=%.4f rad; first motion after recapture (400px) "
		% [mode_start, mode_overlay, mode_back, normal] + "yaw change=%.4f rad; next 10px=%.4f rad" % [jump, second])
	assert_int(mode_overlay).is_equal(Input.MOUSE_MODE_VISIBLE)
	assert_int(mode_back).is_equal(Input.MOUSE_MODE_CAPTURED)
	assert_float(absf(second)).is_greater(0.0) # motion after the first one turns the view
	assert_float(jump).is_equal_approx(0.0, 1e-6) # the first one is discarded (BUG-0014)


## Verification 5a: 40 markers through PingCalloutHud.place (the _draw path) per frame, timed over FRAMES.
func test_v5_forty_markers_projected_and_clamped_under_budget() -> void:
	var view: SubViewport = auto_free(SubViewport.new())
	view.size = Vector2i(1920, 1080)
	add_child(view)
	var cam := Camera3D.new()
	view.add_child(cam)
	cam.position = Vector3(0, 1.6, 0)
	var points: Array[Vector3] = []
	for i in MARKERS: # a ring around the camera: on screen, off the sides and behind
		var a := TAU * i / MARKERS
		points.append(Vector3(sin(a) * (5.0 + i), 1.0 + (i % 5), -cos(a) * (5.0 + i)))
	var size := Vector2(view.size)
	var samples: Array[float] = []
	var sink := Vector2.ZERO
	for f in FRAMES:
		var t0 := Time.get_ticks_usec()
		for p in points:
			sink += PingCalloutHud.place(cam, p, size, PingCalloutHud.INSET_PX)[0]
		samples.append(float(Time.get_ticks_usec() - t0))
	samples.sort()
	var median := samples[FRAMES / 2]
	var p99 := samples[int(FRAMES * 0.99)]
	var worst := samples[FRAMES - 1]
	prints("ADR14 V5 %d markers x %d frames: median %.0f us, p99 %.0f us, max %.0f us (budget %.0f us) %s"
		% [MARKERS, FRAMES, median, p99, worst, BUDGET_US, sink.is_finite()])
	assert_float(p99).is_less(BUDGET_US)


## Verification 5b: markers land on their targets at content_scale_factor 1.0 and 1.5. place() works in the
## space of get_viewport_rect() (as _draw passes it); the window's final transform maps that to physical
## pixels, which must equal an independent projection of the target into the physical window.
func test_v5_markers_land_on_targets_at_scale_1_and_1_5() -> void:
	for scale in [1.0, 1.5]:
		var win: Window = auto_free(Window.new())
		win.size = Vector2i(1920, 1080)
		win.content_scale_factor = scale
		add_child(win)
		var cam := Camera3D.new()
		win.add_child(cam)
		cam.position = Vector3(0, 1.6, 0)
		cam.rotation = Vector3(-0.1, 0.3, 0.0)
		var probe := Control.new() # stands in for PingCalloutHud: same get_viewport_rect() call
		win.add_child(probe)
		await get_tree().process_frame
		var size := probe.get_viewport_rect().size
		var to_phys := win.get_final_transform()
		var phys := Vector2(win.size)
		var worst := 0.0
		for target in [Vector3(-1.5, 1.0, -6.0), Vector3(2.0, 2.5, -10.0), Vector3(0.5, 0.2, -3.0)]:
			var pl := PingCalloutHud.place(cam, target, size, PingCalloutHud.INSET_PX)
			assert_bool(pl[1]).is_false() # on screen, not clamped
			var v: Vector3 = cam.get_camera_transform().affine_inverse() * target
			var clip: Vector4 = cam.get_camera_projection() * Vector4(v.x, v.y, v.z, 1.0)
			var ndc := Vector2(clip.x, clip.y) / clip.w
			var expected := Vector2((ndc.x + 1.0) * 0.5 * phys.x, (1.0 - ndc.y) * 0.5 * phys.y)
			worst = maxf(worst, (to_phys * (pl[0] as Vector2)).distance_to(expected))
		prints("ADR14 V5 scale %.1f: viewport_rect %s, physical %s, worst marker-to-target error %.3f px"
			% [scale, size, phys, worst])
		assert_float(worst).is_less(1.0)
		win.queue_free()
		await get_tree().process_frame


## Verification 6: the API names ADR-0014 §3 and §9 write exist in this editor.
func test_v6_api_names_exist() -> void:
	var mouse := ClassDB.class_get_enum_constants(&"Input", &"MouseMode")
	var live := ClassDB.class_get_enum_constants(&"AccessibilityServer", &"AccessibilityLiveMode")
	var ctrl_live := ClassDB.class_get_property_list(&"Control").filter(
		func(p: Dictionary) -> bool: return p["name"] == "accessibility_live")
	prints("ADR14 V6 Input.mouse_mode property=%s MouseMode=%s AccessibilityServer=%s AccessibilityLiveMode=%s "
		% [ClassDB.class_has_method(&"Input", &"get_mouse_mode"), mouse, ClassDB.class_exists(&"AccessibilityServer"),
		live] + "Control.accessibility_live=%s" % [ctrl_live])
	assert_bool("mouse_mode" in Input).is_true()
	assert_array(mouse).contains([&"MOUSE_MODE_VISIBLE", &"MOUSE_MODE_CAPTURED"])
	assert_array(live).contains([&"LIVE_OFF", &"LIVE_POLITE", &"LIVE_ASSERTIVE"])
	assert_int(ctrl_live.size()).is_equal(1)
	assert_int(Input.MOUSE_MODE_CAPTURED).is_equal(2)
	assert_int(AccessibilityServer.LIVE_POLITE).is_not_equal(AccessibilityServer.LIVE_OFF)
