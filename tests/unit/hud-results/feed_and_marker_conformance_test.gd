extends GdUnitTestSuite
## Story hud-results/007 (design/ux/hud.md H10, H12, H17, Visual Budget, Platform Adaptation, Accessibility;
## ADR-0014 §6, §7, §9): the feed shows 4 lines (older ones in scrollback) on an opaque 7:1 box as a polite
## live region; at most 6 markers (newest kept), one shape per ping type, 20 px labels; the right stick
## steers the wheel; at 21:9 the feed sits 64 px inside the centred 16:9 safe rect. Fed with fake server
## messages through HudModel.

const SERVER_PEER := 1
## C2's appearance id in the shipped cast (data/characters).
const SPEAKER := 2

var _knobs: Knobs
var _router: ClientEventRouter
var _model: HudModel
var _pings: PingReceiver
var _contexts: InputContextStack
var _camera: Camera3D
var _hud: PingCalloutHud


func before_test() -> void:
	_knobs = Knobs.load_all()
	_router = ClientEventRouter.new()
	_model = HudModel.new(MatchDisplay.new(_knobs), _knobs, _router)
	_pings = PingReceiver.new(_router)
	_contexts = InputContextStack.new()
	var audio: PlaceholderAudio = auto_free(PlaceholderAudio.new())
	add_child(audio)
	var view: SubViewport = auto_free(SubViewport.new())
	view.size = Vector2i(1920, 1080)
	add_child(view)
	_camera = Camera3D.new()
	view.add_child(_camera) # at the origin facing -Z
	_hud = auto_free(PingCalloutHud.new(_knobs, _pings, _model, CalloutReceiver.new(_router), _contexts, audio,
			_camera, {} as Dictionary[int, Node3D], _state_of, _now_tick, _no_item, _own, null))
	add_child(_hud)


func _state_of(_h: int) -> Dictionary:
	return {}


func _now_tick() -> float:
	return 100.0


func _no_item() -> int:
	return -1


func _own() -> int:
	return 1


func _deliver(tick: int, entry: Array) -> void:
	_router.on_packet(SERVER_PEER, EventBatch.build(tick, 0, [], [], Vector3.ZERO, null, -1, [entry]))


func _ping(tick: int, handle: int, kind: int = PingsCallouts.LOCATION) -> void:
	_deliver(tick, [EventBatch.PING, {"kind": kind, "point": Vector3(handle, 0, -10), "item": -1, "type": &"",
		"identity": -1, "from": SPEAKER, "handle": handle}])


func _texts(lines: Array[Dictionary]) -> Array:
	return lines.map(func(l: Dictionary) -> String: return l["text"])


func test_five_callouts_in_one_second_show_four_in_order_and_the_first_in_scrollback() -> void:
	var set := CalloutSet.load_shipped()
	var want: Array = []
	for i in 5:
		_deliver(100 + i * 5, [EventBatch.CALLOUT, {"line": set.lines[i], "identity": SPEAKER,
			"origin": Vector3(0, 0, -5), "gesture": false, "voice": &"C2"}])
		want.append("C2: %s" % set.texts[i])
	_hud.advance(0.1)
	assert_array(_texts(_hud.feed_lines())).is_equal(want.slice(1))
	_hud.scrollback = true
	assert_array(_texts(_hud.feed_lines())).is_equal(want)
	assert_array(Array(_hud.feed_history())).is_equal(want) # none dropped


func test_feed_box_is_opaque_at_seven_to_one_and_text_sizes_meet_the_floor() -> void:
	assert_float(PingCalloutHud.FEED_BACKING.a).is_equal(1.0)
	var hi := PingCalloutHud.FEED_TEXT.srgb_to_linear().get_luminance()
	var lo := PingCalloutHud.FEED_BACKING.srgb_to_linear().get_luminance()
	assert_float((maxf(hi, lo) + 0.05) / (minf(hi, lo) + 0.05)).is_greater_equal(7.0)
	assert_int(PingCalloutHud.FEED_FONT).is_greater_equal(28)
	assert_int(PingCalloutHud.MARKER_FONT).is_greater_equal(20)


func test_feed_is_a_polite_live_region_carrying_the_newest_line() -> void:
	assert_int(_hud.feed_region.accessibility_live).is_equal(AccessibilityServer.LIVE_POLITE)
	assert_int(_hud.accessibility_live).is_equal(AccessibilityServer.LIVE_OFF) # the rest (countdowns) never live
	_deliver(100, [EventBatch.CALLOUT, {"line": &"danger", "identity": SPEAKER, "origin": Vector3.ZERO,
		"gesture": false, "voice": &"C2"}])
	assert_str(_hud.feed_region.accessibility_name).is_equal("C2: Danger")


func test_at_most_six_markers_newest_kept() -> void:
	for h in 4: # 4 senders x 2 = 8 markers, each within ping_max_active
		_ping(90 + h, 10 + h)
	for h in 4:
		_ping(94 + h, 10 + h)
	var handles: Array = _model.markers_at(100).map(func(m: Dictionary) -> int: return m["handle"])
	assert_array(handles).is_equal([12, 13, 10, 11, 12, 13])
	_hud.ping() # a pending own ping is the newest: still 6 drawn, the oldest server marker goes
	var ms := _hud.markers_now()
	assert_int(ms.size()).is_equal(HudModel.MAX_MARKERS)
	assert_bool(ms[0]["pending"]).is_true()
	assert_int(ms.filter(func(m: Dictionary) -> bool: return m["point"] == Vector3(12, 0, -10)).size()).is_equal(1)


func test_each_ping_type_has_its_own_shape() -> void:
	var loc := PingCalloutHud.shape_of(PingsCallouts.LOCATION)
	var item := PingCalloutHud.shape_of(PingsCallouts.ITEM)
	var warn := PingCalloutHud.shape_of(PingsCallouts.WARNING_POINT)
	assert_array(Array(loc)).is_not_equal(Array(item))
	assert_array(Array(loc)).is_not_equal(Array(warn))
	assert_array(Array(item)).is_not_equal(Array(warn))
	assert_int(loc.size()).is_not_equal(warn.size()) # not just a resize: a different outline
	assert_array(Array(PingCalloutHud.shape_of(PingsCallouts.WARNING_PLAYER))).is_equal(Array(warn))
	_ping(100, 7, PingsCallouts.ITEM)
	assert_int(_hud.markers_now()[0]["kind"]).is_equal(PingsCallouts.ITEM)


func test_right_stick_steers_the_wheel() -> void:
	_hud.open_wheel()
	var ev := InputEventJoypadMotion.new()
	ev.axis = JOY_AXIS_RIGHT_X
	ev.axis_value = 1.0
	_hud._input(ev)
	assert_int(_hud.wheel_selection()).is_equal(2) # right
	ev.axis_value = 0.0
	_hud._input(ev)
	ev.axis = JOY_AXIS_RIGHT_Y
	ev.axis_value = 1.0
	_hud._input(ev)
	assert_int(_hud.wheel_selection()).is_equal(4) # down
	ev.axis_value = 0.05 # stick back in the dead zone: release cancels
	_hud._input(ev)
	assert_bool(_hud.close_wheel(true)).is_false()
	assert_int(_contexts.top()).is_equal(InputContextStack.Ctx.GAMEPLAY)


func test_feed_zone_keeps_64_px_from_the_16_9_safe_rect_at_21_9() -> void:
	var wide := PingCalloutHud.zone_rect(Vector2(2560, 1080))
	assert_float(wide.position.x).is_equal((2560.0 - 1920.0) / 2.0 + 64.0)
	assert_float(wide.end.x).is_equal(2560.0 - (2560.0 - 1920.0) / 2.0 - 64.0)
	assert_float(wide.end.y).is_equal(1080.0 - 64.0)
	var ref := PingCalloutHud.zone_rect(Vector2(1920, 1080))
	assert_that(ref).is_equal(Rect2(48, 48, 1920 - 96, 1080 - 96))
	assert_that(PingCalloutHud.zone_rect(Vector2(1920, 1200))).is_equal(Rect2(48, 48, 1920 - 96, 1200 - 96))


func test_a_caption_joins_the_feed_in_arrival_order_with_no_arrow() -> void:
	_hud.add_caption("PA: Ten seconds.")
	var lines := _hud.feed_lines()
	assert_array(_texts(lines)).contains_exactly(["PA: Ten seconds."])
	assert_bool(is_nan(lines[0]["angle"])).is_true()
