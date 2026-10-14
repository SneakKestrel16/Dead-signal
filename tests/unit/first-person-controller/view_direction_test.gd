# Story controller-interaction/006: view direction, mouse look and input actions (ADR-0007 §11).
extends GdUnitTestSuite

const PID := 0
const ACTIONS: PackedStringArray = ["move_forward", "move_back", "move_left", "move_right", "sprint",
	"crouch", "interact", "use_item", "ping", "callout_wheel", "flashlight"]
const EPS := 0.0001

var _knobs: Knobs
var _net: NetAuthority
var _runner: TickRunner
var _sm: ServerMovement
var _view: ViewState
var _saved_hz: int
var _seq := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_saved_hz = Engine.physics_ticks_per_second
	_net = NetAuthority.new()
	_net.setup(_knobs, "test", null)
	_runner = TickRunner.new()
	_runner.fail_hard = false
	_runner.boot(_knobs)
	# The view needs no movement: a no-op step keeps this a unit test (no physics space).
	_sm = ServerMovement.new(_knobs, _net, SceneMultiplayer.new(), func(_b: Node, _f: InputFrame, _m: MovementModifiers) -> void: pass, PhysicsLayers.WORLD)
	_sm.attach(_runner)
	_sm.add_player(PID, auto_free(CharacterBody3D.new()), true)
	_view = ViewState.new(_sm)
	_seq = 0


func after_test() -> void:
	_sm.detach()
	_runner.free()
	_net.free()
	Engine.physics_ticks_per_second = _saved_hz


## One server tick with this input from the player.
func _send(yaw: float, pitch: float) -> void:
	_seq += 1
	var f := InputFrame.new()
	f.seq = _seq
	f.move = Vector2(0, 1)
	f.yaw = yaw
	f.pitch = pitch
	_sm.push_local(PID, f)
	_runner.step()


func test_yaw_covers_360_and_wraps() -> void:
	for deg in [0.0, 90.0, 179.0, -179.0, 270.0, 360.0, -360.0, 450.0]:
		_send(deg_to_rad(deg), 0.0)
		assert_float(_view.yaw_of(PID)).is_equal_approx(wrapf(deg_to_rad(deg), -PI, PI), EPS)
		assert_vector(_view.server_dir(PID)).is_equal_approx(ViewState.direction(deg_to_rad(deg), 0.0), Vector3.ONE * EPS)
	_send(deg_to_rad(360.0), 0.0)
	assert_vector(_view.server_dir(PID)).is_equal_approx(Vector3.FORWARD, Vector3.ONE * EPS) ## a full turn faces -Z again


func test_pitch_clamps_at_85_degrees_even_past_it_in_one_frame() -> void:
	_send(0.0, deg_to_rad(170.0))
	assert_float(_view.pitch_of(PID)).is_equal_approx(deg_to_rad(85.0), EPS)
	_send(0.0, deg_to_rad(-120.0))
	assert_float(_view.pitch_of(PID)).is_equal_approx(deg_to_rad(-85.0), EPS)
	_send(0.0, deg_to_rad(40.0))
	assert_float(_view.pitch_of(PID)).is_equal_approx(deg_to_rad(40.0), EPS)
	_sm.frame_of(PID).pitch = deg_to_rad(120.0) ## past InputQueue's clamp: ViewState clamps on its own
	assert_float(_view.pitch_of(PID)).is_equal_approx(deg_to_rad(85.0), EPS)
	_sm.frame_of(PID).pitch = deg_to_rad(40.0)
	assert_float(_view.server_dir(PID).y).is_equal_approx(sin(deg_to_rad(40.0)), EPS) ## positive looks up


## Root, slow and lock are the movement modifiers that Downed, Seized, Transforming and Holding apply
## through the controller arbitration (story 002/003); none of them reaches the view.
func test_view_follows_input_only_under_root_slow_and_lock() -> void:
	var mods := _sm.modifiers_of(PID)
	var cases := [["root", func() -> void: mods.rooted = true],
		["slow", func() -> void: mods.speed_scale = 0.3],
		["lock", func() -> void: mods.locked = true]]
	var yaw := 0.3
	for c in cases:
		mods.rooted = false
		mods.locked = false
		mods.speed_scale = 1.0
		c[1].call()
		yaw += 0.7
		_send(yaw, -0.2)
		assert_float(_view.yaw_of(PID)).override_failure_message("yaw under " + c[0]).is_equal_approx(wrapf(yaw, -PI, PI), EPS)
		assert_float(_view.pitch_of(PID)).override_failure_message("pitch under " + c[0]).is_equal_approx(-0.2, EPS)


func test_starved_tick_keeps_the_last_view() -> void:
	_send(1.0, 0.5)
	_runner.step() ## no frame arrived this tick
	assert_float(_view.yaw_of(PID)).is_equal_approx(1.0, EPS)
	assert_float(_view.pitch_of(PID)).is_equal_approx(0.5, EPS)


func test_mouse_look_uses_screen_relative_not_relative() -> void:
	var li: LocalInput = auto_free(LocalInput.new())
	var e := InputEventMouseMotion.new()
	e.relative = Vector2(10, 0) ## what a half-size canvas_items stretch would report
	e.screen_relative = Vector2(40, 0) ## the real screen pixels
	li.handle(e)
	assert_float(li.yaw).is_equal_approx(-40.0 * li.sensitivity, EPS)


func test_mouse_motion_is_ignored_while_the_mouse_is_not_captured() -> void:
	var li: LocalInput = auto_free(LocalInput.new()) ## not in the tree: _ready never captured it
	assert_int(Input.mouse_mode).is_not_equal(Input.MOUSE_MODE_CAPTURED)
	var e := InputEventMouseMotion.new()
	e.screen_relative = Vector2(40, 0)
	li._input(e)
	assert_float(li.yaw).is_equal(0.0)


func test_mouse_look_clamps_pitch_and_wraps_yaw() -> void:
	var li: LocalInput = auto_free(LocalInput.new())
	li.look(Vector2(0, -100000)) ## far past the clamp in one event
	assert_float(li.pitch).is_equal_approx(ViewState.PITCH_LIMIT, EPS)
	li.look(Vector2(PI / li.sensitivity * 3.0, 0)) ## three half turns
	assert_float(li.yaw).is_between(-PI, PI)
	assert_float(li.sample().pitch).is_equal_approx(ViewState.PITCH_LIMIT, EPS)


func test_input_map_holds_exactly_the_eleven_actions_and_no_jump() -> void:
	var game := PackedStringArray()
	for a in InputMap.get_actions():
		if not String(a).begins_with("ui_") and not String(a).contains("/"):
			game.append(String(a))
	game.sort()
	var want := ACTIONS.duplicate()
	want.sort()
	assert_array(game).is_equal(want)
	assert_bool(InputMap.has_action(&"jump")).is_false()
	for a in ACTIONS:
		assert_int(InputMap.action_get_events(a).size()).override_failure_message(a + " has no binding").is_greater(0)


# --- device == 0 -------------------------------------------------------------

## Lines that compare an event's device with 0 (4.7 changed device IDs; use the event type). A
## tripwire for the common forms: `device == 0`, `0 != x.device`; not `in [0]`, `match` or get("device").
static func device_zero_lines(src: String) -> PackedStringArray:
	var re := RegEx.create_from_string("\\bdevice\\s*(==|!=)\\s*0\\b|\\b0\\s*(==|!=)\\s*\\w*\\.?device\\b")
	var out := PackedStringArray()
	for line in src.split("\n"):
		if not line.strip_edges().begins_with("#") and re.search(line) != null:
			out.append(line.strip_edges())
	return out


func test_device_zero_scanner_catches_a_fixture() -> void:
	var fixture := "\n".join(["\tif event.device == 0:", "\tif 0 != e.device:", "\tif event is InputEventKey:",
		"\t# if event.device == 0: (comment)", "\tif event.device == InputEvent.DEVICE_ID_KEYBOARD:"])
	assert_array(device_zero_lines(fixture)).contains_exactly(["if event.device == 0:", "if 0 != e.device:"])


func test_no_script_under_src_compares_device_with_zero() -> void:
	var bad := PackedStringArray()
	var scanned := 0
	var dirs := ["res://src/"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			dirs.append(dir + sub + "/")
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				scanned += 1
				for line in device_zero_lines(FileAccess.get_file_as_string(dir + f)):
					bad.append("%s%s: %s" % [dir, f, line])
	assert_int(scanned).is_greater(10)
	assert_array(bad).is_empty()
