# Story monster-abilities/002: Lunge wind-up root and dash (design/gdd/monster-abilities.md rules 5-6;
# ADR-0007: root, turn caps and the dash are controller modifiers read by the one movement step).
# MonsterAbilities writes its "lunge" entry into the monster's MovementModifiers (the ServerMovement set,
# here a Dictionary); the round's movement phase runs the controller's MovementStep on a PlayerBody, as
# the composer's server step does. Physics tests tick on physics frames (TickRunner._physics_process).
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const FLOOR_SIZE := 200.0
const SETTLE_TICKS := 5
const POS_TOL := 1e-3
const DIST_TOL := 0.02
const ANGLE_EPS := 1e-4
## A turn request far beyond either cap: 1 rad per tick.
const FAST_TURN := 1.0
const WALL_THICK := 0.4

var _knobs: Knobs
var _server: RoundServer
var _ma: MonsterAbilities
var _mods: Dictionary[int, MovementModifiers]
var _states: Array = [] ## [Lunge, tick] per transition
var _saved_hz: int = 0
var _mover: Mover
var _world: Node3D
var _hit := false


func _start(knobs: Knobs = Knobs.load_all()) -> void:
	_knobs = knobs
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_ma = MonsterAbilities.new()
	_ma.set_monster(MONSTER)
	_mods = {MONSTER: MovementModifiers.new(), S1: MovementModifiers.new()}
	_ma.set_modifiers(_mod_of)
	_ma.on_lunge_state = _on_state
	_states = []
	var errs := _server.start_round({TickOrder.MONSTER_ABILITIES: _ma}, knobs)
	assert_array(errs).is_empty()


func after_test() -> void:
	if _server != null:
		_server.end_round()
	_mover = null
	if _saved_hz > 0:
		Engine.physics_ticks_per_second = _saved_hz
		_saved_hz = 0


func _mod_of(p: int) -> MovementModifiers:
	return _mods.get(p)


func _on_state(state: MonsterAbilities.Lunge, tick: int) -> void:
	_states.append([state, tick])


func _on_hit(_e: ServerEvent) -> void:
	_hit = true


func _tick_of(state: MonsterAbilities.Lunge) -> int:
	for s: Array in _states:
		if s[0] == state:
			return s[1]
	return -1


func _request() -> void:
	_ma.request_ability(MONSTER, MonsterAbilities.request_packet(MonsterAbilities.Ability.LUNGE))


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## The monster's PlayerBody at the origin on a floor, moved by the round's movement phase.
func _monster_body(frame: InputFrame) -> PlayerBody:
	_saved_hz = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = _knobs.net.sim_tick_hz
	_world = auto_free(Node3D.new())
	add_child(_world)
	TestMoveStep.add_box(_world, Vector3(0, -0.5, 0), Vector3(FLOOR_SIZE, 1.0, FLOOR_SIZE))
	var body := _player_body(Vector3.ZERO)
	_mover = Mover.new(body, frame, _mods[MONSTER], _knobs)
	_server.tick_runner.movement_stage = _mover.move
	return body


func _player_body(pos: Vector3) -> PlayerBody:
	var body := PlayerBody.new()
	body.setup(_knobs, PhysicsLayers.MOVE_SERVER)
	_world.add_child(body)
	body.global_position = pos
	return body


## A wall-like box `layer` across the -Z path whose near face is `gap` m ahead of the monster's capsule.
func _obstacle(layer: int, gap: float) -> void:
	var b := TestMoveStep.add_box(_world, Vector3(0, 1.0, -(_knobs.controller.player_radius_m + gap + WALL_THICK / 2.0)),
		Vector3(4.0, 2.0, WALL_THICK))
	b.collision_layer = layer


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


# AC-1: wind-up timing --------------------------------------------------------------------------

func test_dash_begins_windup_ticks_after_acceptance() -> void:
	_start()
	var w := _knobs.ticks(_knobs.ability.lunge_windup_s)
	assert_int(w).override_failure_message("0.6 s at the shipped tick rate").is_equal(roundi(0.6 * _knobs.net.sim_tick_hz))
	_request()
	_server.tick_runner.step()
	var t := _tick_of(MonsterAbilities.Lunge.WIND_UP)
	assert_int(t).is_equal(_server.tick_runner.current_tick())
	for i in w - 1:
		_server.tick_runner.step()
	assert_int(_ma.lunge_state()).override_failure_message("one tick before the boundary").is_equal(MonsterAbilities.Lunge.WIND_UP)
	_server.tick_runner.step()
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.ACTIVE)
	assert_int(_tick_of(MonsterAbilities.Lunge.ACTIVE)).is_equal(t + w)


func test_windup_roots_and_dash_forces_the_monster_modifiers() -> void:
	_start()
	_request()
	_server.tick_runner.step()
	var m := _mods[MONSTER]
	assert_bool(m.rooted).is_true()
	assert_float(m.turn_cap).is_equal_approx(deg_to_rad(_knobs.ability.lunge_windup_turn_deg_s), 1e-6)
	for i in _knobs.ticks(_knobs.ability.lunge_windup_s):
		_server.tick_runner.step()
	assert_bool(m.rooted).is_false()
	assert_float(m.turn_cap).is_equal_approx(deg_to_rad(_knobs.ability.lunge_dash_turn_deg_s), 1e-6)
	assert_float(m.dash_speed).is_greater(0.0)
	assert_bool(_mods[S1].rooted or _mods[S1].dash_speed > 0.0).override_failure_message("only the monster").is_false()


# AC-2: wind-up root and turn cap ---------------------------------------------------------------

func _windup_turn(per_tick: float) -> Array[float]:
	_start()
	var f := InputFrame.new()
	var b := _monster_body(f)
	await _physics(SETTLE_TICKS)
	_request()
	await _physics(1)
	f.move = Vector2(0, 1)
	f.sprint = true
	var at := b.global_position
	var yaws: Array[float] = [f.yaw]
	for i in _knobs.ticks(_knobs.ability.lunge_windup_s) - 1:
		f.yaw = f.yaw + per_tick
		await _physics(1)
		assert_float(_flat(b.global_position - at).length()).override_failure_message("rooted: no movement").is_less(POS_TOL)
		yaws.append(f.yaw)
	return yaws


func test_windup_holds_position_and_caps_turn_rate() -> void:
	var yaws := await _windup_turn(FAST_TURN)
	var cap := deg_to_rad(_knobs.ability.lunge_windup_turn_deg_s) / _knobs.net.sim_tick_hz
	for i in range(1, yaws.size()):
		var turned := absf(angle_difference(yaws[i - 1], yaws[i]))
		assert_float(turned).override_failure_message("tick %d turned %f rad" % [i, turned]).is_less_equal(cap + ANGLE_EPS)
		assert_float(turned).override_failure_message("a capped turn still turns").is_greater(cap - ANGLE_EPS)


func test_windup_turn_input_exactly_at_the_cap_is_applied_in_full() -> void:
	var cap := deg_to_rad(Knobs.load_all().ability.lunge_windup_turn_deg_s) / Knobs.load_all().net.sim_tick_hz
	var yaws := await _windup_turn(cap)
	assert_float(angle_difference(yaws[0], yaws[-1])).is_equal_approx(cap * (yaws.size() - 1), ANGLE_EPS)


# AC-3: dash distance and turn cap --------------------------------------------------------------

## Runs a whole lunge on open floor facing `yaw`, turning `per_tick` during the dash. Returns the
## monster's displacement and the dash's per-tick yaws.
func _dash(knobs: Knobs, yaw: float, per_tick: float) -> Array:
	_start(knobs)
	var f := InputFrame.new()
	f.yaw = yaw
	var b := _monster_body(f)
	await _physics(SETTLE_TICKS)
	_request()
	await _physics(_knobs.ticks(_knobs.ability.lunge_windup_s) + 1)
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.ACTIVE)
	var at := b.global_position
	var yaws: Array[float] = [f.yaw]
	for i in _knobs.ticks(_knobs.ability.lunge_dash_s):
		f.yaw = f.yaw + per_tick
		await _physics(1)
		yaws.append(f.yaw)
	assert_int(_ma.lunge_state()).override_failure_message("dash ran its full length").is_equal(MonsterAbilities.Lunge.COOLDOWN)
	return [b.global_position - at, yaws]


func test_dash_travels_lunge_distance_along_windup_end_facing() -> void:
	var yaw := 0.3
	var r: Array = await _dash(Knobs.load_all(), yaw, 0.0)
	var moved: Vector3 = r[0]
	assert_float(_flat(moved).length()).is_equal_approx(_knobs.ability.lunge_distance_m, DIST_TOL)
	var dir := _flat(Basis(Vector3.UP, yaw) * Vector3.FORWARD)
	assert_float(_flat(moved).normalized().dot(dir)).is_greater(0.9999)


func test_dash_distance_survives_tick_quantisation() -> void:
	var k := Knobs.load_all()
	k.ability.lunge_dash_s = 0.31 ## not a whole number of ticks
	var r: Array = await _dash(k, 0.0, 0.0)
	assert_float(_flat(r[0]).length()).is_equal_approx(k.ability.lunge_distance_m, DIST_TOL)


func test_dash_caps_turn_rate() -> void:
	var r: Array = await _dash(Knobs.load_all(), 0.0, FAST_TURN)
	var yaws: Array[float] = r[1]
	var cap := deg_to_rad(_knobs.ability.lunge_dash_turn_deg_s) / _knobs.net.sim_tick_hz
	for i in range(1, yaws.size()):
		assert_float(absf(angle_difference(yaws[i - 1], yaws[i]))).is_less_equal(cap + ANGLE_EPS)
	assert_float(_flat(r[0]).length()).is_equal_approx(_knobs.ability.lunge_distance_m, DIST_TOL)


# AC-4: obstacles stop the dash -----------------------------------------------------------------

## Lunges at an obstacle on `layer` whose near face is `gap` m ahead (or a survivor body when
## `layer` is PLAYERS). Returns the distance travelled; asserts a miss that resolved by the dash end.
func _dash_into(layer: int, gap: float) -> float:
	_start()
	var f := InputFrame.new()
	var b := _monster_body(f)
	if layer == PhysicsLayers.PLAYERS:
		_player_body(Vector3(0, 0, -(2.0 * _knobs.controller.player_radius_m + gap)))
	else:
		_obstacle(layer, gap)
	await _physics(SETTLE_TICKS)
	var at := b.global_position
	_request()
	_hit = false
	_server.bus.subscribe(&"SurvivorHit", _on_hit)
	await _physics(_knobs.ticks(_knobs.ability.lunge_windup_s) + _knobs.ticks(_knobs.ability.lunge_dash_s) + 1)
	assert_int(_ma.lunge_state()).override_failure_message("resolved as a miss").is_equal(MonsterAbilities.Lunge.COOLDOWN)
	assert_bool(_tick_of(MonsterAbilities.Lunge.TAKEDOWN_COMMIT) == -1 and not _hit).is_true()
	var m := _mods[MONSTER]
	assert_bool(m.rooted or m.dash_speed > 0.0 or m.turn_cap < INF).override_failure_message("lunge modifiers removed").is_false()
	return _flat(b.global_position - at).length()


func test_wall_stops_dash_early_as_a_miss() -> void:
	var gap := 2.0
	var d := await _dash_into(PhysicsLayers.WORLD, gap)
	assert_float(d).is_equal_approx(gap, DIST_TOL * 2.0)
	assert_int(_tick_of(MonsterAbilities.Lunge.COOLDOWN)).override_failure_message("resolves on contact, before the dash ends").is_less(
		_tick_of(MonsterAbilities.Lunge.ACTIVE) + _knobs.ticks(_knobs.ability.lunge_dash_s))


func test_closed_door_blocker_stops_dash() -> void:
	assert_float(await _dash_into(PhysicsLayers.DOORS, 1.5)).is_equal_approx(1.5, DIST_TOL * 2.0)


## Inference: a barricaded door keeps its DOORS blocker enabled (physics_layers.gd "enabled while closed
## or barricaded"); the barricade itself adds no other collider. Barricade story settles it.
func test_barricaded_door_blocker_stops_dash() -> void:
	assert_float(await _dash_into(PhysicsLayers.DOORS, 3.0)).is_equal_approx(3.0, DIST_TOL * 2.0)


func test_non_target_survivor_body_stops_dash() -> void:
	assert_float(await _dash_into(PhysicsLayers.PLAYERS, 1.0)).is_equal_approx(1.0, DIST_TOL * 2.0)


func test_obstacle_at_zero_metres_stops_dash_at_once() -> void:
	assert_float(await _dash_into(PhysicsLayers.WORLD, 0.0)).is_less(DIST_TOL * 2.0)
	assert_int(_tick_of(MonsterAbilities.Lunge.COOLDOWN)).is_equal(_tick_of(MonsterAbilities.Lunge.ACTIVE) + 1)


func test_obstacle_at_exactly_lunge_distance_ends_at_it() -> void:
	var d := await _dash_into(PhysicsLayers.WORLD, Knobs.load_all().ability.lunge_distance_m)
	assert_float(d).is_equal_approx(_knobs.ability.lunge_distance_m, DIST_TOL * 2.0)


## Stands in for the composer's server step: the controller's MovementStep on the monster's body.
class Mover extends RefCounted:
	var _body: PlayerBody
	var _frame: InputFrame
	var _state := MovementStep.MoveState.new()
	var _knobs: Knobs

	func _init(body: PlayerBody, frame: InputFrame, mods: MovementModifiers, knobs: Knobs) -> void:
		_body = body
		_frame = frame
		_state.modifiers = mods
		_state.true_form = true
		_knobs = knobs

	func move(_tick: int) -> void:
		MovementStep.step(_body, _frame, _state, _knobs)
