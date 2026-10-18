# Story controller-interaction/015: chase closing and the controller's server tick budget (ADR-0002,
# ADR-0007; first-person-controller.md Chase closing and Performance ACs, Formulas chase_close_time).
# Integration: real Jolt PlayerBodies moved by the shared MovementStep inside the physics frame.
# The chase is asserted in ticks (simulated time = ticks / sim_tick_hz), so CPU contention from other
# Godot processes cannot change it. The budget is wall clock by nature (the AC asks for ms at p95);
# see test_controller_server_cost_fits_the_tick_budget for how contention is kept out of it.
extends GdUnitTestSuite

## GDD Chase closing example: v_s 5.0 and v_m 5.75 from 10 m close to catch_gap 1.0 m in 12 s; a
## walking survivor (4.0) gives catch_gap 1.9 m, closed in 4.6 s. Tolerances are the AC's.
const START_GAP_M := 10.0
const SPRINT_CLOSE_S := 12.0
const SPRINT_TOL_S := 0.5
const WALK_CLOSE_S := 4.6
const WALK_TOL_S := 0.3
## AC Performance: controller server cost <= 0.5 ms per tick at p95 over 600 ticks. Placeholder budget
## (GDD: technical-director pins the real one with the Network Authority ADR's tick rate).
const BUDGET_P95_USEC := 500
const PROFILE_TICKS := 600
## Unmeasured ticks first: the holds start and every body reaches its gait speed.
const WARMUP_TICKS := 60
## Contention only ever adds time, so the least-contended of up to this many 600-tick profiles is the
## estimate. The threshold is never widened: a real regression fails every attempt.
const PROFILE_ATTEMPTS := 3
const HOLD_RANGE_M := 1.5
## Long enough that no hold completes during the warm-up and every profile attempt.
const HOLD_S := 60.0

var _knobs: Knobs
var _world: Node3D

# Budget scenario state, read by HoldService through the named methods below.
var _ids: Array[int] = []
var _bodies: Dictionary[int, PlayerBody] = {}
var _frames: Dictionary[int, InputFrame] = {}
var _items: Array[Hold] = []
var _queries: MapQueries
var _rules: MapQueries.InteractRules


class Hold extends Interactable:
	func eligible(_actor: int) -> bool:
		return true

	func start_progress_s() -> float:
		return 0.0

	func on_complete(_actor: int) -> void:
		pass

	func on_cancel(_actor: int, _progress_s: float, _reason: StringName) -> void:
		pass


func before_test() -> void:
	_knobs = Knobs.load_all()
	_world = Node3D.new()
	add_child(_world)
	_ids = []
	_bodies = {}
	_frames = {}
	_items = []


func after_test() -> void:
	_world.free()


func _box(center: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = PhysicsLayers.WORLD
	b.collision_mask = PhysicsLayers.NONE
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	cs.shape.size = size
	b.add_child(cs)
	_world.add_child(b)
	b.global_position = center


func _body(pos: Vector3) -> PlayerBody:
	var b := PlayerBody.new()
	b.setup(_knobs, PhysicsLayers.MOVE_SERVER)
	_world.add_child(b)
	b.global_position = pos
	return b


func _hgap(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()


## first-person-controller.md Formulas, catch_gap (the same expression as Knobs.errors()' load check).
func _catch_gap(v_s: float) -> float:
	var a := _knobs.ability
	return a.lunge_distance_m + a.lunge_hit_radius_m + _knobs.controller.player_radius_m \
		- v_s * (a.lunge_windup_s + a.lunge_dash_s)


# --- AC1: chase closing ---------------------------------------------------------------------

## A straight corridor; the survivor START_GAP_M ahead of a true-form shapeshifter, both already at
## their gait speed (the chase starts mid-run), both running -Z. Returns
## [ticks until the gap first reaches catch_gap or -1 by `max_s`, v_s, v_m, catch_gap].
func _chase(survivor_sprints: bool, max_s: float) -> Array:
	_box(Vector3(0, -0.5, -55), Vector3(3, 1, 120))
	_box(Vector3(-1.6, 1.5, -55), Vector3(0.2, 3, 120))
	_box(Vector3(1.6, 1.5, -55), Vector3(0.2, 3, 120))
	var s := _body(Vector3(0, 0, -START_GAP_M))
	var m := _body(Vector3.ZERO)
	var ss := MovementStep.MoveState.new()
	var ms := MovementStep.MoveState.new()
	ms.true_form = true
	var idle := InputFrame.new()
	var fs := InputFrame.new()
	fs.move = Vector2(0, 1)
	fs.sprint = survivor_sprints
	var fm := InputFrame.new()
	fm.move = Vector2(0, 1)
	fm.sprint = true
	await get_tree().physics_frame
	await get_tree().physics_frame ## bodies are in the broadphase before the first step
	for i in 2: ## settle onto the floor
		await get_tree().physics_frame
		MovementStep.step(s, idle, ss, _knobs)
		MovementStep.step(m, idle, ms, _knobs)
	assert_bool(s.is_on_floor() and m.is_on_floor()).is_true()
	assert_float(_hgap(s, m)).is_equal_approx(START_GAP_M, 0.001)
	var v_s := MovementStep.gait_speed(MovementStep.gait(fs, ss), ss, _knobs)
	var v_m := MovementStep.gait_speed(MovementStep.gait(fm, ms), ms, _knobs)
	var catch_gap := _catch_gap(v_s)
	s.velocity = Vector3(0, 0, -v_s)
	m.velocity = Vector3(0, 0, -v_m)
	var max_ticks := ceili(max_s * _knobs.net.sim_tick_hz)
	for tick in range(1, max_ticks + 1):
		await get_tree().physics_frame
		MovementStep.step(s, fs, ss, _knobs)
		MovementStep.step(m, fm, ms, _knobs)
		if _hgap(s, m) <= catch_gap:
			return [tick, v_s, v_m, catch_gap]
	return [-1, v_s, v_m, catch_gap]


func test_a_sprinting_survivor_is_closed_to_catch_gap_in_12_s() -> void:
	var r: Array = await _chase(true, SPRINT_CLOSE_S + SPRINT_TOL_S)
	assert_float(r[1]).is_equal_approx(5.0, 1e-4) ## the GDD's speeds, from the shipped data
	assert_float(r[2]).is_equal_approx(5.75, 1e-4)
	assert_float(r[3]).is_equal_approx(1.0, 1e-4)
	var close_s: float = r[0] / float(_knobs.net.sim_tick_hz)
	print("chase closing, sprinting survivor: %d ticks = %.3f s" % [r[0], close_s])
	assert_int(r[0]).is_greater(0)
	assert_float(close_s).is_between(SPRINT_CLOSE_S - SPRINT_TOL_S, SPRINT_CLOSE_S + SPRINT_TOL_S)


func test_a_walking_survivor_is_closed_to_catch_gap_in_46_s() -> void:
	var r: Array = await _chase(false, WALK_CLOSE_S + WALK_TOL_S)
	assert_float(r[1]).is_equal_approx(4.0, 1e-4)
	assert_float(r[2]).is_equal_approx(5.75, 1e-4)
	assert_float(r[3]).is_equal_approx(1.9, 1e-4)
	var close_s: float = r[0] / float(_knobs.net.sim_tick_hz)
	print("chase closing, walking survivor: %d ticks = %.3f s" % [r[0], close_s])
	assert_int(r[0]).is_greater(0)
	assert_float(close_s).is_between(WALK_CLOSE_S - WALK_TOL_S, WALK_CLOSE_S + WALK_TOL_S)


# --- AC2: controller server cost --------------------------------------------------------------

## HoldService collaborators (named methods, not capturing lambdas).
func _players() -> Array:
	return _ids


func _frames_of(actor: int) -> Array:
	return [_frames[actor]]


func _centre_of(actor: int) -> Vector3:
	return _bodies[actor].global_position + Vector3.UP * _bodies[actor].capsule().height / 2.0


func _eye_of(actor: int) -> Vector3:
	return _bodies[actor].global_position + Vector3.UP * _knobs.controller.eye_height_m


## The server's sight callable: MapQueries.clear_line, one PROJECTILE ray per holder per tick.
func _sight(actor: int, i: Interactable) -> bool:
	return _queries.clear_line(_eye_of(actor), i.point, i.net_id, _rules,
		_bodies[actor].get_world_3d().direct_space_state, [_bodies[actor].get_rid()])


## Stand-in for the server's aim ray on a Start: the stub interactables are not on the map, so the
## claimed id is accepted here; the per-tick aim ray is cast (and timed) in _controller_tick instead.
func _aim(actor: int) -> int:
	return _frames[actor].interact_target


## The controller's server work for one tick: per player the hold flag copy, the shared movement step
## and one interaction ray; then the Holds step (whose sight rays are the real clear_line). Casting the
## aim ray for every player every tick is an upper bound (inference: the server casts it on a Start
## only; ADR-0008 §2 settles how often).
func _controller_tick(tick: int, holds: HoldService, states: Dictionary[int, MovementStep.MoveState],
		turn: Dictionary[int, float]) -> void:
	for id in _ids:
		var f := _frames[id]
		f.yaw = wrapf(f.yaw + turn[id], -PI, PI) ## circling: the heading turns by v / r per tick
		var st := states[id]
		st.holding = not holds.hold_of(id).is_empty()
		MovementStep.step(_bodies[id], f, st, _knobs)
		var b := _bodies[id]
		_queries.interactable_on_ray(_eye_of(id), ViewState.direction(f.yaw, f.pitch), _centre_of(id), _rules,
			b.get_world_3d().direct_space_state, [b.get_rid()])
	holds.server_tick(tick)


## 6 players (max_players) on circles: 2 walking a radius-1 m circle round the point they hold, 1 slowed
## (ability.miss_slow_multiplier), 2 sprinting survivors and a sprinting true-form shapeshifter.
## Gates only on an idle machine (BUG-0004, AD-250): parallel Godot processes push p95 past the budget
## while p50 stays near 350 us. A failure with other Godot or agent processes running is not a regression.
func test_controller_server_cost_fits_the_tick_budget() -> void:
	assert_int(Engine.physics_ticks_per_second).is_equal(_knobs.net.sim_tick_hz)
	_box(Vector3(0, -0.5, 0), Vector3(60, 1, 60))
	_queries = MapQueries.new(MapData.load_map())
	_rules = MapQueries.InteractRules.from_knobs(_knobs)
	var holds := HoldService.new(_knobs, _players, _frames_of, _centre_of, _sight, _aim)
	var states: Dictionary[int, MovementStep.MoveState] = {}
	var turn: Dictionary[int, float] = {}
	var radius := [1.0, 1.0, 2.0, 3.0, 3.0, 3.0]
	for id in 6:
		var centre := Vector3(-15.0 + 15.0 * (id % 3), 0.0, -8.0 + 16.0 * (id / 3))
		_ids.append(id)
		_bodies[id] = _body(centre + Vector3(radius[id], 0, 0)) ## heading -Z turning left circles `centre`
		var f := InputFrame.new()
		f.move = Vector2(0, 1)
		f.sprint = id >= 3
		_frames[id] = f
		var st := MovementStep.MoveState.new()
		st.true_form = id == 5
		if id == 2:
			st.modifiers.add(&"slow", MovementModifiers.Kind.SLOW, _knobs.ability.miss_slow_multiplier)
		states[id] = st
		if id < 2:
			var h := Hold.new()
			h.point = centre + Vector3.UP * _knobs.controller.capsule_height_m / 2.0
			h.range_m = HOLD_RANGE_M
			h.duration_s = HOLD_S
			holds.register(h)
			_items.append(h)
			f.interact = true
			f.interact_target = h.net_id
			st.holding = true ## gait walk from the first tick, as once the hold has started
		var v := MovementStep.gait_speed(MovementStep.gait(f, st), st, _knobs) * st.modifiers.effective_scale()
		turn[id] = v / radius[id] / _knobs.net.sim_tick_hz
	await get_tree().physics_frame
	await get_tree().physics_frame ## bodies are in the broadphase before the first step
	var tick := 0
	for i in WARMUP_TICKS:
		await get_tree().physics_frame
		_controller_tick(tick, holds, states, turn)
		tick += 1
	var p95s: Array[int] = []
	for attempt in PROFILE_ATTEMPTS:
		var samples := PackedInt64Array()
		for i in PROFILE_TICKS:
			await get_tree().physics_frame
			var t0 := Time.get_ticks_usec()
			_controller_tick(tick, holds, states, turn)
			samples.append(Time.get_ticks_usec() - t0)
			tick += 1
		samples.sort()
		p95s.append(samples[ceili(0.95 * PROFILE_TICKS) - 1])
		print("controller server cost, attempt %d: p50 %d us, p95 %d us, max %d us over %d ticks (budget p95 <= %d us)"
			% [attempt + 1, samples[PROFILE_TICKS / 2], p95s.back(), samples[PROFILE_TICKS - 1], PROFILE_TICKS, BUDGET_P95_USEC])
		if p95s.back() <= BUDGET_P95_USEC:
			break
	# The profiled scenario is the AC's: both holds ran throughout, everyone moved at its gait speed.
	for id in 2:
		assert_int(holds.hold_of(id).get("net_id", -1)).is_equal(_items[id].net_id)
		assert_int(holds.hold_of(id).elapsed_ticks).is_greater_equal(PROFILE_TICKS * p95s.size())
	var c := _knobs.controller
	var expect := [c.walk_speed, c.walk_speed, c.walk_speed * _knobs.ability.miss_slow_multiplier,
		c.walk_speed * c.sprint_mult, c.walk_speed * c.sprint_mult, c.walk_speed * c.sprint_mult * c.monster_sprint_mult]
	for id in 6:
		var b := _bodies[id]
		assert_float(Vector2(b.velocity.x, b.velocity.z).length()).is_equal_approx(expect[id], 0.01)
	assert_int(p95s.min()).override_failure_message(
		"min p95 %d us > budget %d us: re-run on an idle machine before calling it a regression (BUG-0004)"
		% [p95s.min(), BUDGET_P95_USEC]).is_less_equal(BUDGET_P95_USEC)
