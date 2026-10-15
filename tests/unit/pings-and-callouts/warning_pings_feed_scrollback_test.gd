extends GdUnitTestSuite
## Story pings-and-callouts/011 (design/gdd/pings-and-callouts.md rule 5; design/ux/hud.md H10, H12;
## interaction-patterns P5, P9; ADR-0014 §1): warning pings and the hold-to-show feed scrollback, fed with
## fake inputs and fake server messages.

const SERVER_PEER := 1
## C2's appearance id in the shipped cast (data/characters).
const C2 := 2
const HANDLE := 77

var _knobs: Knobs
var _router: ClientEventRouter
var _pings: PingReceiver
var _callouts: CalloutReceiver
var _camera: Camera3D
var _remotes: Dictionary[int, Node3D] = {}
var _states: Dictionary = {}
var _hud: PingCalloutHud


func before_test() -> void:
	_knobs = Knobs.load_all()
	_router = ClientEventRouter.new()
	_pings = PingReceiver.new(_router)
	_callouts = CalloutReceiver.new(_router)
	var audio: PlaceholderAudio = auto_free(PlaceholderAudio.new())
	add_child(audio)
	var view: SubViewport = auto_free(SubViewport.new())
	view.size = Vector2i(1920, 1080)
	add_child(view)
	_camera = Camera3D.new()
	view.add_child(_camera) # at the origin facing -Z
	_remotes = {}
	_states = {}
	_hud = auto_free(PingCalloutHud.new(_knobs, _pings, PingMarkers.new(_router, _knobs), _callouts,
			InputContextStack.new(), audio, _camera, _remotes, _state_of, _now_tick, _no_item, _own, null))
	add_child(_hud)


func _state_of(h: int) -> Dictionary:
	return _states.get(h, {})


func _now_tick() -> float:
	return 100.0


func _no_item() -> int:
	return -1


func _own() -> int:
	return 1


## A drawn remote body with its feet at `at` (the camera's eye is at y 0, so feet below it).
func _body(at: Vector3, shown: bool = true) -> void:
	var n: Node3D = auto_free(Node3D.new())
	n.position = at
	n.visible = shown
	_remotes[HANDLE] = n
	_states[HANDLE] = {"appearance": C2}


func _deliver(entry: Dictionary) -> void:
	_router.on_packet(SERVER_PEER, EventBatch.build(100, 0, [], [], Vector3.ZERO, null, -1,
			[[EventBatch.PING, entry]]))


func test_actions_are_in_the_project() -> void:
	assert_bool(InputMap.has_action(&"warning_ping")).is_true()
	assert_bool(InputMap.has_action(&"feed_scrollback")).is_true()


func test_warn_at_nothing_sends_warning_point() -> void:
	_hud.warn()
	assert_int(_pings.pending.size()).is_equal(1)
	assert_int(_pings.pending[0]["kind"]).is_equal(PingsCallouts.WARNING_POINT)
	assert_int(_pings.pending[0]["target"]).is_equal(-1)


func test_warn_at_visible_body_sends_warning_player_by_handle() -> void:
	_body(Vector3(0.1, -1.6, -6))
	_hud.warn()
	assert_int(_pings.pending[0]["kind"]).is_equal(PingsCallouts.WARNING_PLAYER)
	assert_int(_pings.pending[0]["target"]).is_equal(HANDLE)
	var m: Dictionary = _hud.markers_now()[0]
	assert_bool(m["warning"]).is_true()
	assert_str(m["label"]).contains("C2")


func test_warn_skips_hidden_and_off_ray_bodies() -> void:
	_body(Vector3(0, -1.6, -6), false)
	_hud.warn()
	_body(Vector3(2.0, -1.6, -6))
	_hud.warn()
	assert_int(_pings.pending[0]["kind"]).is_equal(PingsCallouts.WARNING_POINT)
	assert_int(_pings.pending[1]["kind"]).is_equal(PingsCallouts.WARNING_POINT)


func test_pick_body_stops_at_the_wall() -> void:
	_body(Vector3(0, -1.6, -6))
	var h := _knobs.controller.capsule_height_m
	assert_int(PingCalloutHud.pick_body(Vector3.ZERO, Vector3.FORWARD, 10.0, _remotes, 0.3, h)).is_equal(HANDLE)
	assert_int(PingCalloutHud.pick_body(Vector3.ZERO, Vector3.FORWARD, 4.0, _remotes, 0.3, h)).is_equal(0)


func test_server_warning_marker_names_the_target_and_monster() -> void:
	_deliver({"kind": PingsCallouts.WARNING_PLAYER, "point": Vector3(0, 0, -10), "item": -1, "type": &"",
		"identity": CharacterDef.TRUE_FORM_APPEARANCE_ID, "from": C2, "handle": 9})
	_deliver({"kind": PingsCallouts.WARNING_PLAYER, "point": Vector3(0, 0, -12), "item": -1, "type": &"",
		"identity": C2, "from": 1, "handle": 8})
	_deliver({"kind": PingsCallouts.LOCATION, "point": Vector3(0, 0, -14), "item": -1, "type": &"",
		"identity": -1, "from": 1, "handle": 8})
	var ms := _hud.markers_now()
	assert_bool(ms[0]["warning"]).is_true()
	assert_str(ms[0]["label"]).contains("Monster")
	assert_that(ms[0]["colour"]).is_equal(PingCalloutHud.WARNING_COLOUR)
	assert_str(ms[1]["label"]).contains("C2")
	assert_bool(ms[2]["warning"]).is_false()


func test_scrollback_shows_last_ten_regardless_of_age() -> void:
	for i in 12:
		_callouts.received.append({"origin": Vector3(0, 0, -5), "identity": C2, "line": &"danger"})
	_hud.advance(0.1)
	assert_int(_hud.feed_lines().size()).is_equal(10)
	_hud.advance(PingCalloutHud.FEED_HOLD_S + 1.0)
	assert_int(_hud.feed_lines().size()).is_equal(0)
	_hud.scrollback = true
	assert_int(_hud.feed_lines().size()).is_equal(PingCalloutHud.FEED_SCROLLBACK)
	_hud.scrollback = false
	assert_int(_hud.feed_lines().size()).is_equal(0)
