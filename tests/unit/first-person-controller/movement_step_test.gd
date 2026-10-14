# Story controller-interaction/002: the shared movement step and gaits (first-person-controller.md Formulas).
# Headless on a flat box floor, no networking: each tick awaits a physics frame and calls MovementStep.step,
# as TickRunner's movement phase does. Speeds are read from the body's horizontal velocity.
extends GdUnitTestSuite

const SPEED_TOL := 0.05 ## AC: ±0.05 m/s
const FLOOR_SIZE := 200.0
const SETTLE_TICKS := 5

var _knobs: Knobs
var _saved_hz: int
var _world: Node3D
var _body: PlayerBody


func before_test() -> void:
	_knobs = Knobs.load_all()
	_saved_hz = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = _knobs.net.sim_tick_hz
	_world = auto_free(Node3D.new())
	add_child(_world)
	TestMoveStep.add_box(_world, Vector3(0, -0.5, 0), Vector3(FLOOR_SIZE, 1.0, FLOOR_SIZE))
	_body = PlayerBody.new()
	_body.setup(_knobs, PhysicsLayers.MOVE_SERVER)
	_world.add_child(_body)
	_body.global_position = Vector3.ZERO
	await _idle(SETTLE_TICKS) ## lands and gets a floor contact


func after_test() -> void:
	Engine.physics_ticks_per_second = _saved_hz


func _frame(move: Vector2, sprint := false) -> InputFrame:
	var f := InputFrame.new()
	f.move = move
	f.sprint = sprint
	return f


## Input `degrees` off facing (0 = straight ahead, 90 = strafe right, 180 = backpedal), full length.
func _at(degrees: float) -> Vector2:
	return Vector2(sin(deg_to_rad(degrees)), cos(deg_to_rad(degrees)))


func _idle(ticks: int) -> void:
	await _run(_frame(Vector2.ZERO), MovementStep.MoveState.new(), ticks)


func _run(frame: InputFrame, state: MovementStep.MoveState, ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame
		MovementStep.step(_body, frame, state, _knobs)


func _hspeed() -> float:
	return Vector2(_body.velocity.x, _body.velocity.z).length()


## Speed after one second of ticks with `frame` and `state`.
func _speed_after_1s(frame: InputFrame, state := MovementStep.MoveState.new()) -> float:
	await _run(frame, state, _knobs.net.sim_tick_hz)
	return _hspeed()


func _state(downed := false, crouched := false, holding := false, transforming := false, true_form := false) -> MovementStep.MoveState:
	var s := MovementStep.MoveState.new()
	s.downed = downed
	s.crouched = crouched
	s.holding = holding
	s.transforming = transforming
	s.true_form = true_form
	return s


# --- AC1: gait speeds ----------------------------------------------------------

func test_one_second_of_each_gait_reaches_its_formula_speed() -> void:
	var cases := [
		["crawl", _frame(_at(0)), _state(true), 1.0],
		["crouch", _frame(_at(0)), _state(false, true), 2.0],
		["walk", _frame(_at(0)), _state(), 4.0],
		["survivor sprint", _frame(_at(0), true), _state(), 5.0],
		["true-form sprint", _frame(_at(0), true), _state(false, false, false, false, true), 5.75],
	]
	for c in cases:
		_body.velocity = Vector3.ZERO
		var v: float = await _speed_after_1s(c[1], c[2])
		assert_float(v).override_failure_message("%s: %.3f m/s, expected %.2f" % [c[0], v, c[3]]).is_equal_approx(c[3], SPEED_TOL)


# --- AC2: sprint cone and gait order -------------------------------------------

func test_sprint_held_inside_the_45_degree_cone_sprints_outside_it_walks() -> void:
	var cases := [[30.0, 5.0], [45.0, 5.0], [45.0 + MovementStep.SPRINT_CONE_EPS_DEG * 0.5, 5.0], [46.0, 4.0], [180.0, 4.0]]
	for c in cases:
		_body.velocity = Vector3.ZERO
		var v: float = await _speed_after_1s(_frame(_at(c[0]), true))
		assert_float(v).override_failure_message("%s°: %.3f m/s" % [c[0], v]).is_equal_approx(c[1], SPEED_TOL)


func test_sprint_held_while_crouched_downed_transforming_or_holding_uses_the_gait_order() -> void:
	var cases := [["crouched", _state(false, true), 2.0], ["downed", _state(true), 1.0],
		["transforming", _state(false, false, false, true), 4.0], ["holding", _state(false, false, true), 4.0]]
	for c in cases:
		_body.velocity = Vector3.ZERO
		var v: float = await _speed_after_1s(_frame(_at(0), true), c[1])
		assert_float(v).override_failure_message("%s: %.3f m/s" % [c[0], v]).is_equal_approx(c[2], SPEED_TOL)


func test_gait_order_downed_beats_crouched_beats_holding() -> void:
	var sprint := _frame(_at(0), true)
	assert_int(MovementStep.gait(sprint, _state(true, true, true))).is_equal(MovementStep.Gait.CRAWL)
	assert_int(MovementStep.gait(sprint, _state(false, true, true))).is_equal(MovementStep.Gait.CROUCH)
	assert_int(MovementStep.gait(sprint, _state(false, false, true))).is_equal(MovementStep.Gait.WALK)
	assert_int(MovementStep.gait(_frame(Vector2.ZERO, true), _state())).is_equal(MovementStep.Gait.WALK) ## no input, no cone


# --- AC3: move input cap -------------------------------------------------------

func test_diagonal_key_input_of_length_1_41_walks_at_walk_speed() -> void:
	var v: float = await _speed_after_1s(_frame(Vector2(1, 1)))
	assert_float(v).is_equal_approx(4.0, SPEED_TOL)


# --- AC4: acceleration ---------------------------------------------------------

func _ticks_to_reach(speed: float) -> int:
	_body.velocity = Vector3.ZERO
	var f := _frame(_at(0))
	var state := MovementStep.MoveState.new()
	for t in range(1, _knobs.net.sim_tick_hz + 1):
		await _run(f, state, 1)
		if _hspeed() >= speed - 1e-3:
			return t
	return -1


func test_from_rest_walk_speed_is_reached_in_accel_time() -> void:
	for accel: float in [0.05, 0.09]:
		_knobs.controller.accel_time_s = accel
		await _idle(SETTLE_TICKS)
		var ticks := await _ticks_to_reach(4.0)
		var expected: float = accel * _knobs.net.sim_tick_hz
		assert_float(float(ticks)).override_failure_message("accel %.2f s: %d ticks" % [accel, ticks]).is_between(expected - 1.0, expected + 1.0)


func test_zero_input_decelerates_to_rest_in_accel_time() -> void:
	await _run(_frame(_at(0), true), MovementStep.MoveState.new(), _knobs.net.sim_tick_hz)
	await _run(_frame(Vector2.ZERO), MovementStep.MoveState.new(), ceili(_knobs.controller.accel_time_s * _knobs.net.sim_tick_hz) + 1)
	assert_float(_hspeed()).is_equal_approx(0.0, 1e-4)


# --- body settings and modifiers -----------------------------------------------

func test_body_floor_and_slide_settings_come_from_knobs() -> void:
	var c := _knobs.controller
	assert_float(rad_to_deg(_body.floor_max_angle)).is_equal_approx(c.floor_max_angle_deg, 1e-4)
	assert_float(_body.floor_snap_length).is_equal_approx(c.floor_snap_length_m, 1e-6) ## the engine stores float32
	assert_float(_body.safe_margin).is_equal_approx(c.safe_margin_m, 1e-6)
	assert_int(_body.max_slides).is_equal(c.max_slides)
	assert_float(rad_to_deg(_body.wall_min_slide_angle)).is_equal_approx(c.wall_min_slide_angle_deg, 1e-4)
	assert_bool(_body.floor_stop_on_slope and _body.floor_constant_speed and _body.floor_block_on_wall).is_true()


## Out (Eliminated, Escaped) is not the step's: ServerMovement.set_frozen stops the step and
## PlayerBody.set_out removes collision (GDD Edge Cases).
func test_root_stops_a_sprinting_body_on_the_next_tick() -> void:
	var state := MovementStep.MoveState.new()
	await _run(_frame(_at(0), true), state, _knobs.net.sim_tick_hz)
	state.modifiers.rooted = true
	await _run(_frame(_at(0), true), state, 1)
	assert_float(_hspeed()).is_equal(0.0)


func test_sprint_resumes_after_a_root_ends_without_a_re_press() -> void:
	var state := MovementStep.MoveState.new()
	var f := _frame(_at(0), true)
	state.modifiers.rooted = true
	await _run(f, state, 10)
	state.modifiers.rooted = false
	await _run(f, state, _knobs.net.sim_tick_hz)
	assert_float(_hspeed()).is_equal_approx(5.0, SPEED_TOL)


func test_velocity_follows_yaw_and_stays_level_on_the_floor() -> void:
	var f := _frame(_at(0))
	f.yaw = PI / 2.0 ## facing -X (yaw 0 faces -Z, positive yaw turns left)
	await _run(f, MovementStep.MoveState.new(), _knobs.net.sim_tick_hz)
	assert_vector(_body.velocity).is_equal_approx(Vector3(-4.0, 0.0, 0.0), Vector3(SPEED_TOL, 1e-6, SPEED_TOL))
	assert_bool(_body.is_on_floor()).is_true()


func test_zero_accel_time_reaches_speed_on_the_first_tick() -> void:
	_knobs.controller.accel_time_s = 0.0
	await _run(_frame(_at(0)), MovementStep.MoveState.new(), 1)
	assert_float(_hspeed()).is_equal_approx(4.0, 1e-4)
