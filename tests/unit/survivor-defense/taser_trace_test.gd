# Story survivor-defense/002: taser trace along the view ray with rewind
# (design/gdd/survivor-defense.md rule 8; ADR-0003 §3-6). Monster Abilities' takedown is stood in for
# by an Emitter until MA-6 and SD-12 re-run against both real modules.
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const S2 := 3
const S3 := 4
const S4 := 5
const SURVIVORS: Array[int] = [2, 3, 4, 5]
const EYE_Y := 1.5
const H := 1.8
const R := 0.3
const CHARGES := 3
## Where bodies not in a test's line of fire stand.
const AWAY := Vector3(100.0, 0.0, 100.0)

var _server: RoundServer
var _def: SurvivorDefense
var _d: Downing
var _abilities: Emitter
var _knobs: Knobs
var _lc: LagCompensation
var _history: RewindHistory
var _frame := InputFrame.new()
var _pos: Dictionary[int, Vector3] = {}
## Test wall: blocks a segment ending beyond z < _wall_z (0 = no wall).
var _wall_z := 0.0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_wall_z = 0.0
	_frame = InputFrame.new()
	_knobs.defense.stun_item_charges = CHARGES
	_history = RewindHistory.new(_knobs.net.history_ticks)
	_lc = LagCompensation.new(_knobs, _history, _frame_of)
	_pos = {S1: Vector3.ZERO}
	for i in [S2, S3, S4, MONSTER]:
		_pos[i] = AWAY + Vector3(i * 10.0, 0.0, 0.0)
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_d = Downing.new()
	_d.set_roster(SURVIVORS, MONSTER)
	_def = SurvivorDefense.new()
	_def.set_roster(SURVIVORS, MONSTER)
	_def.set_locked(_d.action_locked)
	_def.set_trace(_lc, _eye_of, _frame_of, _blocked)
	_abilities = Emitter.new()
	var errs := _server.start_round({TickOrder.SURVIVOR_DEFENSE: _def,
		TickOrder.MONSTER_ABILITIES: _abilities, TickOrder.DOWNING: _d}, _knobs)
	assert_array(errs).is_empty()
	_server.tick_runner.history_stage = _push


func after_test() -> void:
	if _server != null:
		_server.end_round()


func _push(tick: int) -> void:
	for id: int in _pos:
		_history.push(tick, id, _pos[id], H, R, _pos[id] + Vector3(0.0, H - R, 0.0))


func _frame_of(_player: int) -> InputFrame:
	return _frame


func _eye_of(player: int) -> Vector3:
	return _pos[player] + Vector3(0.0, EYE_Y, 0.0)


func _blocked(_from: Vector3, to: Vector3) -> bool:
	return _wall_z < 0.0 and to.z < _wall_z


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


func _now() -> int:
	return _server.tick_runner.current_tick()


func _delay() -> int:
	return _knobs.ticks(_knobs.defense.stun_use_delay_s)


## Ahead of S1 (facing -Z) at `dist` m, `deg` degrees to the right.
func _ahead(dist: float, deg: float = 0.0) -> Vector3:
	var a := deg_to_rad(deg)
	return Vector3(sin(a), 0.0, -cos(a)) * dist


## S1 fires; the shot resolves `_delay()` ticks later with the view `view_lag` ticks behind. Returns the
## result. Asserts nothing resolves before the delay ends.
func _shoot(view_lag: float = 4.0) -> Dictionary:
	var resolve := _now() + 1 + _delay()
	_frame.view_tick = resolve - view_lag
	_frame.ack_snapshot_tick = int(resolve - view_lag)
	_def.request_intent(S1, SurvivorDefense.fire_packet())
	_step(_delay())
	assert_array(_def.resolved_shots()).is_empty()
	_step(1)
	var shots := _def.resolved_shots()
	assert_int(shots.size()).is_equal(1)
	assert_int(shots[0].shooter).is_equal(S1)
	_step(_knobs.ticks(_knobs.defense.stun_item_reuse_s))
	return shots[0]


func _seize(survivor: int) -> int:
	var hit := EvSurvivorHit.new()
	hit.survivor = survivor
	var t := _now() + 1
	_abilities.at(t, hit)
	_step(1)
	assert_int(_d.life_state(survivor)).is_equal(Downing.LifeState.SEIZED)
	return t + _knobs.ticks(_knobs.downing.takedown_commit_s)


# AC-1 -------------------------------------------------------------------------------------------

func test_exactly_5_m_and_exactly_10_degrees_hit() -> void:
	_check_cases([[5.0, 0.0, MONSTER, "hit"], [5.0 * cos(deg_to_rad(10.0)), 10.0, MONSTER, "hit"]])


func test_beyond_5_m_or_outside_10_degrees_hit_nothing_and_spend_a_cartridge() -> void:
	_check_cases([[5.1, 0.0, -1, "range"], [4.0, 11.0, -1, "missed"]])


## Each case [distance, degrees, expected hit, expected reason]; every shot spends one cartridge.
func _check_cases(cases: Array) -> void:
	var spent := 0
	for c: Array in cases:
		_pos[MONSTER] = _ahead(c[0], c[1])
		var r := _shoot()
		spent += 1
		assert_int(r.hit).override_failure_message("case %s" % [c]).is_equal(c[2])
		assert_str(r.reason).override_failure_message("case %s" % [c]).is_equal(c[3])
		assert_int(_def.charges(S1)).is_equal(CHARGES - spent)


func test_trace_ray_inside_radius_counts_at_close_range() -> void:
	# 1 m ahead and 0.25 m aside: 14 degrees off the axis, but the ray grazes the 0.3 m capsule.
	_pos[MONSTER] = Vector3(0.25, 0.0, -1.0)
	assert_int(_shoot().hit).is_equal(MONSTER)


# AC-2 -------------------------------------------------------------------------------------------

func test_survivor_in_front_shields_monster() -> void:
	_pos[S2] = _ahead(2.5)
	_pos[MONSTER] = _ahead(4.0)
	var r := _shoot()
	assert_int(r.hit).is_equal(S2)
	assert_str(r.reason).is_equal(SurvivorDefense.SHOT_HIT)


func test_two_survivors_in_line_nearest_is_hit() -> void:
	_pos[S3] = _ahead(3.5)
	_pos[S2] = _ahead(2.0, 3.0)
	_pos[MONSTER] = _ahead(4.5)
	assert_int(_shoot().hit).is_equal(S2)


func test_wall_blocks_the_dart() -> void:
	_pos[MONSTER] = _ahead(4.0)
	_wall_z = -2.0
	var r := _shoot()
	assert_int(r.hit).is_equal(-1)
	assert_str(r.reason).is_equal(SurvivorDefense.SHOT_BLOCKED)


# AC-3 -------------------------------------------------------------------------------------------

func test_seized_and_downed_survivors_pass_through_to_monster() -> void:
	_step(_seize(S3) - _now())
	assert_int(_d.life_state(S3)).is_equal(Downing.LifeState.DOWNED)
	_seize(S2)
	_pos[S2] = _ahead(1.5)
	_pos[S3] = _ahead(2.5)
	_pos[MONSTER] = _ahead(4.0)
	assert_int(_shoot().hit).is_equal(MONSTER)


func test_all_bodies_skipped_and_nothing_behind_misses() -> void:
	_step(_seize(S3) - _now())
	_seize(S2)
	_pos[S2] = _ahead(1.5)
	_pos[S3] = _ahead(2.5)
	var r := _shoot()
	assert_int(r.hit).is_equal(-1)
	assert_str(r.reason).is_equal(SurvivorDefense.SHOT_MISSED)
	assert_int(_def.charges(S1)).is_equal(CHARGES - 1)


# AC-4 -------------------------------------------------------------------------------------------

## The monster stands in line through 4 ticks before the shot resolves, then steps 3 m aside: a view
## 4 ticks old hits it there; a current view (no rewind) misses.
func test_target_moved_after_view_tick_is_still_hit() -> void:
	for lag: float in [4.0, 0.0]:
		_pos[MONSTER] = _ahead(4.0)
		var resolve := _now() + 1 + _delay()
		_frame.view_tick = resolve - lag
		_frame.ack_snapshot_tick = int(resolve - lag)
		_def.request_intent(S1, SurvivorDefense.fire_packet())
		_step(resolve - 4 - _now())
		_pos[MONSTER] = _ahead(4.0) + Vector3(3.0, 0.0, 0.0)
		_step(resolve - _now())
		var r: Dictionary = _def.resolved_shots()[0]
		assert_int(r.hit).override_failure_message("lag %s" % lag).is_equal(MONSTER if lag > 0.0 else -1)
		_step(_knobs.ticks(_knobs.defense.stun_item_reuse_s))


## view_tick unset (0): the rewind clamps to max_rewind_ms (NA-7). In line through the oldest tick the
## capped rewind reads, aside after: only the capped rewind still hits.
func test_unset_view_tick_clamps_rewind_to_cap() -> void:
	var cap := _knobs.ability.max_rewind_ms * _knobs.net.sim_tick_hz / 1000.0
	_pos[MONSTER] = _ahead(4.0)
	var resolve := _now() + 1 + _delay()
	_frame.view_tick = 0.0
	_frame.ack_snapshot_tick = 0
	_def.request_intent(S1, SurvivorDefense.fire_packet())
	_step(resolve - floori(cap) - _now())
	_pos[MONSTER] = _ahead(4.0) + Vector3(3.0, 0.0, 0.0)
	_step(resolve - _now())
	assert_int(_def.resolved_shots()[0].hit).is_equal(MONSTER)
	var clamped := _lc.records.filter(func(e: Dictionary) -> bool: return e.kind == "clamped")
	assert_int(clamped.size()).is_equal(1)
	assert_float(clamped[0].applied).is_equal_approx(cap, 0.0001)


## Emits each scheduled event in its own tick slot (stands in for Monster Abilities).
class Emitter extends RefCounted:
	var _bus: EventBus
	var _due: Dictionary[int, Array] = {}

	func setup(_runner: TickRunner, bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
		_bus = bus

	func at(tick: int, e: ServerEvent) -> void:
		if not _due.has(tick):
			_due[tick] = []
		_due[tick].append(e)

	func server_tick(tick: int) -> void:
		for e: ServerEvent in _due.get(tick, []):
			_bus.emit(e)
