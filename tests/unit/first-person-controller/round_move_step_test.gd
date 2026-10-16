# BUG-0017: the shipped round's move step (RoundMoveStep) is MovementStep.step behind the
# Callable(body, frame, modifiers) that ServerMovement and OwnerPredictor call: gaits from the frame, the
# owner's modifiers, the Lunge dash, and one MoveState per body.
extends GdUnitTestSuite

const SPEED_TOL := 0.05
const FLOOR_SIZE := 200.0
const SETTLE_TICKS := 5
const DASH_SPEED := 10.0 ## any speed well above sprint

var _knobs: Knobs
var _saved_hz: int
var _world: Node3D
var _apply: Callable


func before_test() -> void:
	_knobs = Knobs.load_all()
	_saved_hz = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = _knobs.net.sim_tick_hz
	_world = auto_free(Node3D.new())
	add_child(_world)
	TestMoveStep.add_box(_world, Vector3(0, -0.5, 0), Vector3(FLOOR_SIZE, 1.0, FLOOR_SIZE))
	_apply = RoundMoveStep.step_for(_knobs)


func after_test() -> void:
	Engine.physics_ticks_per_second = _saved_hz


func _body(pos := Vector3.ZERO) -> CharacterBody3D:
	var b: CharacterBody3D = RoundMoveStep.body_maker(_knobs).call(_world, pos)
	return b


func _frame(move: Vector2, sprint := false, crouch := false, yaw := 0.0) -> InputFrame:
	var f := InputFrame.new()
	f.move = move
	f.sprint = sprint
	f.crouch = crouch
	f.yaw = yaw
	return f


func _run(body: CharacterBody3D, frame: InputFrame, mods: MovementModifiers, ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame
		_apply.call(body, frame, mods)


func _hspeed(body: CharacterBody3D) -> float:
	return Vector2(body.velocity.x, body.velocity.z).length()


func _speed_after_1s(frame: InputFrame, mods := MovementModifiers.new()) -> float:
	var body := _body()
	await _run(body, _frame(Vector2.ZERO), mods, SETTLE_TICKS)
	await _run(body, frame, mods, _knobs.net.sim_tick_hz)
	return _hspeed(body)


## BUG-0018: walls, glass and closed doors, on the server as in prediction (players never block each other).
func test_body_is_a_player_body_on_players_layer_colliding_with_walls_glass_and_doors() -> void:
	var body := _body(Vector3(1, 2, 3))
	assert_bool(body is PlayerBody).is_true()
	assert_int(body.collision_layer).is_equal(PhysicsLayers.PLAYERS)
	assert_int(body.collision_mask).is_equal(PhysicsLayers.MOVE_PREDICT)
	assert_vector(body.global_position).is_equal(Vector3(1, 2, 3))
	assert_float(body.floor_max_angle).is_equal_approx(deg_to_rad(_knobs.controller.floor_max_angle_deg), 1e-5)


func test_sprint_reaches_walk_times_sprint_mult() -> void:
	var c := _knobs.controller
	assert_float(await _speed_after_1s(_frame(Vector2(0, 1), true))).is_equal_approx(
			c.walk_speed * c.sprint_mult, SPEED_TOL)


func test_crouch_reaches_walk_times_crouch_mult() -> void:
	var c := _knobs.controller
	assert_float(await _speed_after_1s(_frame(Vector2(0, 1), true, true))).is_equal_approx(
			c.walk_speed * c.crouch_speed_mult, SPEED_TOL)


func test_walk_scaled_by_slow_and_zero_when_rooted() -> void:
	var mods := MovementModifiers.new()
	mods.add(&"slow", MovementModifiers.Kind.SLOW, 0.5)
	assert_float(await _speed_after_1s(_frame(Vector2(0, 1)), mods)).is_equal_approx(
			_knobs.controller.walk_speed * 0.5, SPEED_TOL)
	var rooted := MovementModifiers.new()
	rooted.add(&"root", MovementModifiers.Kind.ROOT)
	assert_float(await _speed_after_1s(_frame(Vector2(0, 1), true), rooted)).is_equal(0.0)


func test_dash_moves_along_facing_at_dash_speed_ignoring_input() -> void:
	var body := _body()
	var mods := MovementModifiers.new()
	await _run(body, _frame(Vector2.ZERO), mods, SETTLE_TICKS)
	mods.set_dash(&"lunge", DASH_SPEED)
	await _run(body, _frame(Vector2(1, 0), false, false, 0.0), mods, 3)
	assert_vector(body.velocity).is_equal_approx(Vector3(0, 0, -DASH_SPEED), Vector3.ONE * 1e-3)


func test_each_body_keeps_its_own_move_state() -> void:
	var a := _body(Vector3(-5, 0, 0))
	var b := _body(Vector3(5, 0, 0))
	assert_object(RoundMoveStep.state_of(a)).is_not_same(RoundMoveStep.state_of(b))
	assert_object(RoundMoveStep.state_of(a)).is_same(RoundMoveStep.state_of(a))
