# Story survivor-defense/003: one shock lock, no refresh, post-lock window
# (design/gdd/survivor-defense.md rules 11, 14; ADR-0007 modifiers, ADR-0008 set_barred).
# Hits are applied directly through SurvivorDefense.shock except AC-3, which runs real shots.
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const S2 := 3
const S3 := 4
const S4 := 5
const SURVIVORS: Array[int] = [2, 3, 4, 5]
const H := 1.8
const R := 0.3
const CHARGES := 3


class StubItem extends Interactable:
	var log: Array[String] = []

	func eligible(_actor: int) -> bool:
		return true

	func start_progress_s() -> float:
		return 0.0

	func on_complete(_actor: int) -> void:
		log.append("complete")

	func on_cancel(_actor: int, _progress_s: float, reason: StringName) -> void:
		log.append("cancel:%s" % reason)


var _server: RoundServer
var _def: SurvivorDefense
var _knobs: Knobs
var _holds: HoldService
var _lc: LagCompensation
var _history: RewindHistory
var _mods: Dictionary[int, MovementModifiers] = {}
var _frame := InputFrame.new()
var _pos: Dictionary[int, Vector3] = {}
var _aim := -1
var _press := false


func before_test() -> void:
	_knobs = Knobs.load_all()
	_knobs.defense.stun_item_charges = CHARGES
	_frame = InputFrame.new()
	_aim = -1
	_press = false
	_mods = {}
	for p: int in SURVIVORS + [MONSTER]:
		_mods[p] = MovementModifiers.new()
	# S1 at the origin; S2 and S3 behind it facing -Z, either side of its axis (AC-3 shooters).
	_pos = {S1: Vector3.ZERO, S2: Vector3(0.3, 0.0, 3.0), S3: Vector3(-0.3, 0.0, 3.0),
		S4: Vector3(100.0, 0.0, 100.0), MONSTER: Vector3(-100.0, 0.0, 100.0)}
	_history = RewindHistory.new(_knobs.net.history_ticks)
	_lc = LagCompensation.new(_knobs, _history, _frame_of)
	_holds = HoldService.new(_knobs, _players, _frames, _centre_of, _sight, _aim_of)
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_def = SurvivorDefense.new()
	_def.set_roster(SURVIVORS, MONSTER)
	_def.set_trace(_lc, _eye_of, _frame_of)
	_def.set_modifiers(_modifiers_of)
	_def.set_holds(_holds)
	_holds.set_barred(_def.locked)
	assert_array(_server.start_round({TickOrder.SURVIVOR_DEFENSE: _def}, _knobs)).is_empty()
	_server.tick_runner.history_stage = _push


func after_test() -> void:
	if _server != null:
		_server.end_round()


func _players() -> Array[int]:
	return SURVIVORS


func _frames(_actor: int) -> Array:
	var f := InputFrame.new()
	f.interact = _press
	f.interact_target = _aim
	return [f]


func _centre_of(_actor: int) -> Vector3:
	return Vector3.ZERO


func _sight(_actor: int, _i: Interactable) -> bool:
	return true


func _aim_of(_actor: int) -> int:
	return _aim


func _modifiers_of(p: int) -> MovementModifiers:
	return _mods.get(p)


func _push(tick: int) -> void:
	for id: int in _pos:
		_history.push(tick, id, _pos[id], H, R, _pos[id] + Vector3(0.0, H - R, 0.0))


func _frame_of(_player: int) -> InputFrame:
	return _frame


func _eye_of(player: int) -> Vector3:
	return _pos[player] + Vector3(0.0, 1.5, 0.0)


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


func _now() -> int:
	return _server.tick_runner.current_tick()


func _t(seconds: float) -> int:
	return _knobs.ticks(seconds)


func _item() -> StubItem:
	var i := StubItem.new()
	i.point = Vector3.ZERO
	i.range_m = 2.0
	i.duration_s = 5.0
	_holds.register(i)
	return i


## S1 presses interact on `i` and the Holds step runs once.
func _start_hold(i: StubItem) -> void:
	_aim = i.net_id
	_press = true
	_holds.server_tick(_now())


## S1's lock state on the current tick through the SHOCK_STUN_LOCK view (pings and callouts read it).
func _view_locked(p: int) -> bool:
	var v := _server.registry.view(StateKeys.SHOCK_STUN_LOCK, SurvivorDefense.ShockLockView) \
		as SurvivorDefense.ShockLockView
	return v.locked(p)


# AC-1 -------------------------------------------------------------------------------------------

func test_hit_roots_then_slows_until_stun_duration() -> void:
	_step(1)
	var hit := _now()
	assert_bool(_def.shock(S1, hit)).is_true()
	var m := _mods[S1]
	assert_bool(m.rooted).is_true()
	_step(_t(_knobs.defense.stun_root_s) - 1)
	assert_bool(m.rooted).is_true()
	_step(1)
	assert_bool(m.rooted).is_false()
	assert_float(m.speed_scale).is_equal(_knobs.defense.stun_slow_mult)
	_step(hit + _t(_knobs.defense.stun_duration_s) - 1 - _now())
	assert_float(m.speed_scale).is_equal(_knobs.defense.stun_slow_mult)
	_step(1)
	assert_float(m.effective_scale()).is_equal(1.0)


func test_hit_cancels_rescue_objective_and_barricade_holds() -> void:
	_step(1)
	# One HoldService carries rescue, objective and barricade holds; each kind is cancelled the same way.
	for i in 3:
		var item := _item()
		_step(_t(_knobs.defense.stun_duration_s + _knobs.defense.stun_immunity_s))
		_start_hold(item)
		assert_dict(_holds.hold_of(S1)).is_not_empty()
		_def.shock(S1, _now())
		assert_dict(_holds.hold_of(S1)).is_empty()
		assert_array(item.log).contains(["cancel:shocked"])
		_press = false
		_holds.server_tick(_now())


func test_hit_on_the_first_tick_of_a_hold_cancels_it() -> void:
	var item := _item()
	_step(1)
	_start_hold(item)
	_def.shock(S1, _now())
	assert_dict(_holds.hold_of(S1)).is_empty()
	assert_array(item.log).is_equal(["cancel:shocked"])


# AC-2 -------------------------------------------------------------------------------------------

func test_lock_blocks_interact_item_and_view_until_first_free_tick() -> void:
	var item := _item()
	_step(1)
	var hit := _now()
	_def.shock(S1, hit)
	_step(hit + _t(_knobs.defense.stun_duration_s) - 1 - _now()) # last locked tick
	assert_bool(_view_locked(S1)).is_true()
	assert_bool(_def.can_fire(S1, _now())).is_false()
	_start_hold(item) # doors, interact and barricades all start through HoldService
	assert_dict(_holds.hold_of(S1)).is_empty()
	_press = false
	_holds.server_tick(_now())
	_step(1) # first free tick
	assert_bool(_view_locked(S1)).is_false()
	assert_bool(_def.can_fire(S1, _now())).is_true()
	_start_hold(item)
	assert_dict(_holds.hold_of(S1)).is_not_empty()


func test_locked_survivor_fire_intent_spends_nothing() -> void:
	_step(1)
	_def.shock(S1, _now())
	_def.request_intent(S1, SurvivorDefense.fire_packet())
	_step(1)
	assert_int(_def.charges(S1)).is_equal(CHARGES)


# AC-3 -------------------------------------------------------------------------------------------

func test_four_hits_half_a_second_apart_lock_once_and_spend_four_charges() -> void:
	_step(1)
	var gap := _t(0.5)
	var delay := _t(_knobs.defense.stun_use_delay_s)
	var first := -1
	var locks := []
	for k in 4:
		var shooter := S2 if k % 2 == 0 else S3
		var fire := _now() + 1
		_frame.view_tick = fire
		_frame.ack_snapshot_tick = fire
		_def.request_intent(shooter, SurvivorDefense.fire_packet())
		_step(1 + delay)
		var shots := _def.resolved_shots()
		assert_int(shots.size()).is_equal(1)
		assert_int(shots[0].hit).is_equal(S1)
		locks.append(shots[0].locked)
		if first < 0:
			first = _now()
		_step(gap - 1 - delay)
	assert_array(locks).is_equal([true, false, false, false])
	assert_int(_def.charges(S2) + _def.charges(S3)).is_equal(2 * CHARGES - 4)
	_step(first + _t(_knobs.defense.stun_duration_s) - 1 - _now())
	assert_bool(_view_locked(S1)).is_true()
	_step(1)
	assert_bool(_view_locked(S1)).is_false()


func test_hit_exactly_at_lock_end_adds_nothing() -> void:
	_step(1)
	var hit := _now()
	_def.shock(S1, hit)
	_step(_t(_knobs.defense.stun_duration_s))
	assert_bool(_def.shock(S1, _now())).is_false()
	assert_bool(_view_locked(S1)).is_false()
	assert_float(_mods[S1].effective_scale()).is_equal(1.0)


# AC-4 -------------------------------------------------------------------------------------------

func test_eight_hits_two_seconds_apart_lock_only_at_0_and_8() -> void:
	var item := _item()
	_step(1)
	var start := _now()
	var applied := []
	for k in 8:
		_step(start + _t(2.0 * k) - _now())
		_start_hold(item)
		applied.append(_def.shock(S1, _now()))
		assert_dict(_holds.hold_of(S1)).is_empty() # every hit cancels the hold, window or not
		if not applied[k]:
			assert_bool(_mods[S1].rooted).is_false()
			assert_float(_mods[S1].effective_scale()).is_equal(1.0)
			assert_bool(_view_locked(S1)).is_false()
		_press = false
		_holds.server_tick(_now())
	assert_array(applied).is_equal([true, false, false, false, true, false, false, false])


func test_hit_on_the_last_window_tick_is_ignored_and_the_next_tick_locks() -> void:
	_step(1)
	var hit := _now()
	_def.shock(S1, hit)
	var edge := hit + _t(_knobs.defense.stun_duration_s) + _t(_knobs.defense.stun_immunity_s)
	_step(edge - 1 - _now())
	assert_bool(_def.shock(S1, _now())).is_false()
	_step(1)
	assert_bool(_def.shock(S1, _now())).is_true()
	assert_bool(_view_locked(S1)).is_true()
