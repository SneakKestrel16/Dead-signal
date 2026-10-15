extends GdUnitTestSuite
## Story pings-and-callouts/008 (design/gdd/pings-and-callouts.md rules 2, 7, 10, 12; design/ux/hud.md H9,
## H10, H12, H17; ADR-0014 §1, §7): the client ping/callout presenter fed with fake server messages.

const SERVER_PEER := 1
## C2's appearance id in the shipped cast (data/characters); the test reads its name and colour from there.
const SPEAKER := 2

var _knobs: Knobs
var _router: ClientEventRouter
var _pings: PingReceiver
var _callouts: CalloutReceiver
var _contexts: InputContextStack
var _audio: PlaceholderAudio
var _camera: Camera3D
var _remotes: Dictionary[int, Node3D] = {}
var _states: Dictionary = {}
var _now := 100.0
var _hud: PingCalloutHud


func before_test() -> void:
	_knobs = Knobs.load_all()
	_router = ClientEventRouter.new()
	_pings = PingReceiver.new(_router)
	_callouts = CalloutReceiver.new(_router)
	_contexts = InputContextStack.new()
	_audio = auto_free(PlaceholderAudio.new())
	add_child(_audio)
	# A fixed-size viewport, so unproject_position has a known space (the headless window has none).
	var view: SubViewport = auto_free(SubViewport.new())
	view.size = Vector2i(1920, 1080)
	add_child(view)
	_camera = Camera3D.new()
	view.add_child(_camera) # at the origin facing -Z
	_remotes = {}
	_states = {}
	_now = 100.0
	_hud = auto_free(PingCalloutHud.new(_knobs, _pings, HudModel.new(MatchDisplay.new(_knobs), _knobs, _router),
			_callouts, _contexts,
			_audio, _camera, _remotes, _state_of, _now_tick, _no_item, _own, null))
	add_child(_hud)


func _state_of(h: int) -> Dictionary:
	return _states.get(h, {})


func _now_tick() -> float:
	return _now


func _no_item() -> int:
	return -1


func _own() -> int:
	return 1


func _deliver(tick: int, entry: Array) -> void:
	_router.on_packet(SERVER_PEER, EventBatch.build(tick, 0, [], [], Vector3.ZERO, null, -1, [entry]))


func _name(appearance: int) -> String:
	for c in CharacterDef.load_all():
		if c.appearance_id == appearance:
			return String(c.id)
	return ""


func test_press_shows_pending_then_server_marker_replaces_it() -> void:
	_hud.ping()
	var ms := _hud.markers_now()
	assert_int(ms.size()).is_equal(1)
	assert_bool(ms[0]["pending"]).is_true()
	_deliver(101, [EventBatch.PING, {"kind": PingsCallouts.LOCATION, "point": Vector3(0, 0, -10), "item": -1,
		"type": &"", "identity": -1, "from": 1, "handle": 9, "own": true}])
	ms = _hud.markers_now()
	assert_int(ms.size()).is_equal(1)
	assert_bool(ms[0]["pending"]).is_false()
	assert_str(ms[0]["label"]).is_equal("%s  10 m" % _name(1))


func test_rejection_drops_pending_and_shows_too_fast_tick() -> void:
	_hud.ping()
	var req: Dictionary = _pings.pending[0].duplicate()
	_deliver(101, [EventBatch.PING_REJECTED, req])
	_hud.advance(0.0)
	assert_int(_hud.markers_now().size()).is_equal(0)
	assert_float(_hud.too_fast_s).is_greater(0.0)
	assert_int(_audio.played.size()).is_equal(1)
	_hud.advance(PingCalloutHud.TOO_FAST_S + 0.01)
	assert_float(_hud.too_fast_s).is_equal(0.0)


func test_marker_names_sender_colour_distance_and_fades_at_expiry() -> void:
	_deliver(100, [EventBatch.PING, {"kind": PingsCallouts.LOCATION, "point": Vector3(3, 0, -4), "item": -1,
		"type": &"", "identity": -1, "from": SPEAKER, "handle": 4, "not_you": true}])
	var life := _knobs.ticks(_knobs.ping.ping_lifetime_s)
	var m: Dictionary = _hud.markers_now()[0]
	assert_str(m["label"]).is_equal("%s  5 m (not you)" % _name(SPEAKER))
	assert_that(m["colour"]).is_equal(_hud.colour_of(SPEAKER))
	assert_float(m["alpha"]).is_equal(1.0)
	_now = 100 + life - _knobs.ticks(PingCalloutHud.FADE_S) / 2.0
	assert_float(_hud.markers_now()[0]["alpha"]).is_equal_approx(0.5, 0.05)
	_now = 100 + life
	assert_int(_hud.markers_now().size()).is_equal(0)


func test_off_screen_and_behind_targets_clamp_to_the_edge_pointing_the_right_way() -> void:
	var size := _camera.get_viewport().get_visible_rect().size # unproject_position's space
	var ahead := PingCalloutHud.place(_camera, Vector3(0, 0, -10), size, 48.0)
	assert_bool(ahead[1]).is_false()
	# Behind and to the right: clamped, and the arrow points right (not mirrored to the left).
	var behind := PingCalloutHud.place(_camera, Vector3(5, 0, 10), size, 48.0)
	assert_bool(behind[1]).is_true()
	assert_float((behind[0] as Vector2).x).is_greater(size.x / 2.0)
	assert_float(cos(behind[2])).is_greater(0.0)
	var left := PingCalloutHud.place(_camera, Vector3(-50, 0, -1), size, 48.0)
	assert_bool(left[1]).is_true()
	assert_float((left[0] as Vector2).x).is_equal_approx(48.0, 0.5)


func test_wheel_pushes_its_context_picks_a_sector_and_pops_on_release() -> void:
	_hud.open_wheel()
	assert_int(_contexts.top()).is_equal(InputContextStack.Ctx.WHEEL)
	assert_bool(_contexts.allows_look()).is_false()
	assert_bool(_contexts.allows_move()).is_true()
	assert_int(PingCalloutHud.wheel_pick(Vector2(0, -100), 8)).is_equal(0)
	assert_int(PingCalloutHud.wheel_pick(Vector2(100, 0), 8)).is_equal(2)
	assert_int(PingCalloutHud.wheel_pick(Vector2(-100, -100), 8)).is_equal(7)
	assert_int(PingCalloutHud.wheel_pick(Vector2(5, 5), 8)).is_equal(-1)
	_hud.aim_wheel(Vector2(0, 200))
	assert_int(_hud.wheel_selection()).is_equal(4)
	assert_bool(_hud.close_wheel(true)).is_true()
	assert_int(_contexts.top()).is_equal(InputContextStack.Ctx.GAMEPLAY)
	_hud.open_wheel()
	assert_bool(_hud.close_wheel(true)).is_false() # released in the dead zone: cancelled
	assert_int(_contexts.top()).is_equal(InputContextStack.Ctx.GAMEPLAY)


func test_callout_feed_line_audio_arrow_and_not_you() -> void:
	var origin := Vector3(10, 0, 0) # to the camera's right
	_deliver(100, [EventBatch.CALLOUT, {"line": &"danger", "identity": SPEAKER, "origin": origin,
		"gesture": false, "voice": &"C2", "not_you": true}])
	_hud.advance(0.0)
	var lines := _hud.feed_lines()
	assert_int(lines.size()).is_equal(1)
	assert_str(lines[0]["text"]).is_equal("%s: Danger (not you)" % _name(SPEAKER))
	assert_float(cos(lines[0]["angle"])).is_equal_approx(1.0, 0.01)
	assert_array(_audio.played.back()).is_equal([&"callout/C2/danger", origin])
	assert_str(String((_audio.get_child(_audio.get_child_count() - 1) as AudioStreamPlayer3D).bus)) \
			.is_equal(String(PingCalloutHud.VOICE_BUS))


## hud-results/007: 4 of the 10 retained lines are visible (hud.md Feedback & Notification Systems); the
## rest are in scrollback.
func test_feed_keeps_ten_lines_shows_four_each_visible_eight_seconds() -> void:
	for i in 12:
		_deliver(100 + i, [EventBatch.CALLOUT, {"line": &"wait", "identity": SPEAKER, "origin": Vector3.ZERO,
			"gesture": false, "voice": &"C2"}])
	_hud.advance(0.0)
	assert_int(_hud.feed_history().size()).is_equal(PingCalloutHud.FEED_SCROLLBACK)
	assert_int(_hud.feed_lines().size()).is_equal(PingCalloutHud.FEED_VISIBLE)
	_hud.advance(PingCalloutHud.FEED_HOLD_S - 0.1)
	assert_int(_hud.feed_lines().size()).is_equal(PingCalloutHud.FEED_VISIBLE)
	_hud.advance(0.2)
	assert_int(_hud.feed_lines().size()).is_equal(0)
	assert_int(_hud.feed_history().size()).is_equal(PingCalloutHud.FEED_SCROLLBACK)


func test_monster_audio_only_plays_without_a_feed_line() -> void:
	_deliver(100, [EventBatch.CALLOUT_AUDIO, {"line": &"wait", "voice": &"C2", "origin": Vector3(1, 0, 0)}])
	_hud.advance(0.0)
	assert_int(_hud.feed_lines().size()).is_equal(0)
	assert_array(_audio.played.back()).is_equal([&"callout/C2/wait", Vector3(1, 0, 0)])


func test_real_callout_gestures_on_the_speaker_body_only() -> void:
	var speaker: Node3D = auto_free(Node3D.new())
	var other: Node3D = auto_free(Node3D.new())
	add_child(speaker)
	add_child(other)
	speaker.position = Vector3(4, 0, 0)
	other.position = Vector3(4.5, 0, 0)
	_remotes[7] = speaker
	_remotes[8] = other
	_states[7] = {"appearance": SPEAKER}
	_states[8] = {"appearance": 3}
	_deliver(100, [EventBatch.CALLOUT, {"line": &"wait", "identity": SPEAKER, "origin": Vector3(4, 0, 0),
		"gesture": true, "voice": &"C2"}])
	_hud.advance(0.0)
	assert_object(speaker.get_node_or_null(^"Gesture")).is_not_null()
	assert_object(other.get_node_or_null(^"Gesture")).is_null()
	_hud.advance(PingCalloutHud.GESTURE_S + 0.01)
	await get_tree().process_frame
	assert_object(speaker.get_node_or_null(^"Gesture")).is_null()
	_deliver(101, [EventBatch.CALLOUT, {"line": &"wait", "identity": SPEAKER, "origin": Vector3(4, 0, 0),
		"gesture": false, "voice": &"C2"}])
	_hud.advance(0.0)
	assert_object(speaker.get_node_or_null(^"Gesture")).is_null()
