# Story survivor-defense/004: monster stun, immunity and cancels (design/gdd/survivor-defense.md rules 1,
# 9, 10, 15, 16; ADR-0005 tick order: Survivor Defense (200) flushes MonsterStunned before Borrowed Face
# (300), Monster Abilities (400) and Downing (500) complete). Real Borrowed Face, Monster Abilities and
# Downing consume the event; SurvivorHit is emitted directly (MA-6 and SD-12 re-run it end to end).
# AC-1 and AC-3 fire real shots; the rest land hits through a Hitter in the MATCH_FLOW_BEGIN slot.
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const S2 := 3
const S3 := 4
const S4 := 5
const SURVIVORS: Array[int] = [2, 3, 4, 5]
const H := 1.8
const R := 0.3
const EYE := Vector3(0.0, 1.6, 0.0)
const FAR := Vector3(100.0, 0.0, 100.0)


## Lands a hit on MONSTER through SurvivorDefense.shock on each tick in `at`, before Survivor Defense's slot.
class Hitter extends RefCounted:
	var at: Array[int] = []
	var shock: Callable

	func setup(_tr: TickRunner, _bus: EventBus, _reg: StateRegistry, _k: Knobs) -> void:
		pass

	func server_tick(tick: int) -> void:
		if at.has(tick):
			shock.call(MONSTER, tick)


class StubItem extends Interactable:
	var log: Array[String] = []

	func eligible(_actor: int) -> bool:
		return true

	func start_progress_s() -> float:
		return 0.0

	func on_complete(_actor: int) -> void:
		log.append("complete")

	func on_cancel(_actor: int, progress_s: float, reason: StringName) -> void:
		log.append("cancel:%s:%s" % [reason, progress_s > 0.0])


var _server: RoundServer
var _def: SurvivorDefense
var _bf: BorrowedFace
var _ma: MonsterAbilities
var _d: Downing
var _hitter: Hitter
var _knobs: Knobs
var _holds: HoldService
var _lc: LagCompensation
var _history: RewindHistory
var _frame := InputFrame.new()
var _pos: Dictionary[int, Vector3] = {}
var _ma_form := BorrowedFace.TRUE_FORM
var _aim := -1
var _press := false
## Every event received by type: [event, tick handled].
var _events: Dictionary[StringName, Array] = {}


func before_test() -> void:
	_knobs = Knobs.load_all()
	_frame = InputFrame.new()
	_ma_form = BorrowedFace.TRUE_FORM
	_aim = -1
	_press = false
	_events = {&"MonsterStunned": [], &"FormChanged": [], &"SurvivorHit": [], &"SurvivorDowned": []}
	_pos = {S1: Vector3.ZERO, S2: Vector3(0.6, 0.0, 0.0), S3: Vector3(-0.6, 0.0, 0.0), S4: FAR,
		MONSTER: Vector3(0.0, 0.0, -3.0)}
	_history = RewindHistory.new(_knobs.net.history_ticks)
	_lc = LagCompensation.new(_knobs, _history, _frame_of)
	_holds = HoldService.new(_knobs, _players, _frames, _centre_of, _sight_item, _aim_of)
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_def = SurvivorDefense.new()
	_def.set_roster(SURVIVORS, MONSTER)
	_def.set_trace(_lc, _eye_of, _frame_of)
	_def.set_holds(_holds)
	_bf = BorrowedFace.new()
	_bf.set_roster(SURVIVORS, MONSTER)
	_bf.set_sight_sources(_bf_eye, _bf_yaw, _points_of, _sight, _def.locked)
	_bf.set_status_source(_status_of)
	_def.set_form_source(_bf.form)
	_ma = MonsterAbilities.new()
	_ma.set_monster(MONSTER)
	_ma.set_status_sources(_ma_form_of, _bf.transforming, _def.locked)
	_d = Downing.new()
	_d.set_roster(SURVIVORS, MONSTER)
	_d.set_positions(_position_of)
	_hitter = Hitter.new()
	_hitter.shock = _def.shock
	assert_array(_server.start_round({TickOrder.MATCH_FLOW_BEGIN: _hitter, TickOrder.SURVIVOR_DEFENSE: _def,
		TickOrder.BORROWED_FACE: _bf, TickOrder.MONSTER_ABILITIES: _ma, TickOrder.DOWNING: _d}, _knobs)).is_empty()
	_server.tick_runner.history_stage = _push
	for t: StringName in _events:
		_server.bus.subscribe(t, _on_event)
	_step(1)


func after_test() -> void:
	if _server != null:
		_server.end_round()


func _on_event(e: ServerEvent) -> void:
	_events[e.type()].append([e, _now()])


func _players() -> Array[int]:
	return [MONSTER]


func _frames(_actor: int) -> Array:
	var f := InputFrame.new()
	f.interact = _press
	f.interact_target = _aim
	return [f]


func _centre_of(_actor: int) -> Vector3:
	return Vector3.ZERO


func _sight_item(_actor: int, _i: Interactable) -> bool:
	return true


func _aim_of(_actor: int) -> int:
	return _aim


func _position_of(p: int) -> Vector3:
	return _pos.get(p, FAR)


func _push(tick: int) -> void:
	for id: int in _pos:
		_history.push(tick, id, _pos[id], H, R, _pos[id] + Vector3(0.0, H - R, 0.0))


func _frame_of(_player: int) -> InputFrame:
	return _frame


func _eye_of(player: int) -> Vector3:
	return _pos[player] + Vector3(0.0, 1.5, 0.0)


func _bf_eye(_p: int) -> Vector3:
	return EYE


func _bf_yaw(_p: int) -> float:
	return 0.0


func _points_of(_p: int) -> PackedVector3Array:
	var chest := EYE + Vector3.FORWARD * 5.0
	return PackedVector3Array([chest + Vector3.UP * 0.4, chest, chest + Vector3.DOWN * 0.3])


func _sight(_eye: Vector3, _point: Vector3) -> bool:
	return true


func _status_of(_p: int) -> int:
	return MatchFlow.Status.HEALTHY


func _ma_form_of() -> int:
	return _ma_form


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


func _now() -> int:
	return _server.tick_runner.current_tick()


func _t(seconds: float) -> int:
	return _knobs.ticks(seconds)


func _lock() -> int:
	return _t(_knobs.defense.stun_duration_s)


func _immunity() -> int:
	return _t(_knobs.defense.stun_immunity_s)


## `shooters` fire on the next tick; steps until their shots resolve.
func _fire(shooters: Array[int]) -> void:
	for s in shooters:
		_def.request_intent(s, SurvivorDefense.fire_packet())
	_step(1 + _t(_knobs.defense.stun_use_delay_s))


## Hits MONSTER on the tick `n` ticks from now and steps to it.
func _hit_in(n: int) -> void:
	_hitter.at.append(_now() + n)
	_step(n)


func _stuns() -> int:
	return _events[&"MonsterStunned"].size()


func _observe_all() -> void:
	_step(_t(_knobs.borrowed_face.observe_time_s))
	assert_bool(_bf.observed(S1)).is_true()


# AC-1 -------------------------------------------------------------------------------------------

func test_true_form_hit_within_range_stuns_for_stun_duration_and_emits() -> void:
	_fire([S1])
	assert_int(_stuns()).is_equal(1)
	var e := _events[&"MonsterStunned"][0][0] as EvMonsterStunned
	assert_int(e.monster).is_equal(MONSTER)
	assert_bool(e.true_form).is_true()
	assert_bool(_def.locked(MONSTER)).is_true()
	_step(_lock() - 1)
	assert_bool(_def.locked(MONSTER)).is_true()
	_step(1)
	assert_bool(_def.locked(MONSTER)).is_false()


func test_hit_at_exactly_stun_range_stuns() -> void:
	_pos[MONSTER] = Vector3(0.0, 0.0, -_knobs.defense.stun_range_m)
	_fire([S1])
	assert_int(_stuns()).is_equal(1)


func test_out_of_range_missed_or_shielded_shot_does_not_stun() -> void:
	_pos[MONSTER] = Vector3(0.0, 0.0, -_knobs.defense.stun_range_m - 0.1)
	_fire([S1])
	assert_str(_def.resolved_shots()[0].reason).is_equal(SurvivorDefense.SHOT_RANGE)
	_pos[MONSTER] = Vector3(0.0, 0.0, 3.0) # behind S1: a miss
	_step(_t(_knobs.defense.stun_item_reuse_s))
	_fire([S1])
	assert_str(_def.resolved_shots()[0].reason).is_equal(SurvivorDefense.SHOT_MISSED)
	_pos[MONSTER] = Vector3(0.0, 0.0, -4.0)
	_pos[S4] = Vector3(0.6, 0.0, -2.0) # S4 shields it from S2
	_fire([S2])
	assert_int(_def.resolved_shots()[0].hit).is_equal(S4)
	assert_int(_stuns()).is_equal(0)


# AC-2 -------------------------------------------------------------------------------------------

func test_stun_in_lunge_wind_up_resolves_the_lunge_with_no_survivor_hit() -> void:
	_ma.request_ability(MONSTER, MonsterAbilities.request_packet(MonsterAbilities.Ability.LUNGE))
	_step(1)
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.WIND_UP)
	_hit_in(1)
	assert_bool(_ma.attacking()).is_false()
	_step(_t(_knobs.ability.lunge_windup_s + _knobs.ability.lunge_dash_s))
	assert_array(_events[&"SurvivorHit"]).is_empty()


func _seize(s: int) -> int:
	var hit := EvSurvivorHit.new()
	hit.survivor = s
	_server.bus.emit(hit)
	_server.bus.flush()
	assert_int(_d.life_state(s)).is_equal(Downing.LifeState.SEIZED)
	return hit.tick + _t(_knobs.downing.takedown_commit_s)


func test_stun_in_takedown_commit_frees_the_victim() -> void:
	_seize(S1)
	_hit_in(2)
	assert_bool(_d.committing()).is_false()
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.HEALTHY)


func test_stun_on_the_commit_completion_tick_beats_the_down() -> void:
	var end := _seize(S1)
	_hit_in(end - _now())
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.HEALTHY)
	assert_array(_events[&"SurvivorDowned"]).is_empty()


func test_stun_one_tick_after_the_commit_completes_leaves_the_down() -> void:
	var end := _seize(S1)
	_hit_in(end + 1 - _now())
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.DOWNED)


func test_stun_cancels_a_transformation_and_beats_its_completion_tick() -> void:
	_observe_all()
	_bf.request_form_change(MONSTER, BorrowedFace.request_packet(S1))
	_step(1)
	assert_bool(_bf.transforming()).is_true()
	_hit_in(_t(_knobs.borrowed_face.transform_duration_s))  # the completion tick
	assert_bool(_bf.transforming()).is_false()
	assert_int(_bf.form()).is_equal(BorrowedFace.TRUE_FORM)
	assert_array(_events[&"FormChanged"]).is_empty()


# AC-3 -------------------------------------------------------------------------------------------

func test_second_hit_inside_immunity_is_resisted_and_hit_at_its_end_stuns() -> void:
	_hit_in(1)
	var first := _now()
	_hit_in(_lock() + _immunity() - 1)
	assert_int(_stuns()).is_equal(1)
	assert_bool(_def.locked(MONSTER)).is_false()
	_hit_in(first + _lock() + _immunity() - _now())
	assert_int(_stuns()).is_equal(2)


func test_two_survivors_on_the_same_tick_stun_once_and_spend_two_charges() -> void:
	var before := _def.charges(S1) + _def.charges(S2)
	_fire([S1, S2])
	assert_int(_def.resolved_shots().size()).is_equal(2)
	assert_int(_stuns()).is_equal(1)
	assert_int(_def.charges(S1) + _def.charges(S2)).is_equal(before - 2)


# AC-4 -------------------------------------------------------------------------------------------

func test_lunge_wind_up_inside_immunity_ends_it_and_a_stun_on_it_applies() -> void:
	_hit_in(1)
	_step(_lock() + _t(2.0))
	_ma.request_ability(MONSTER, MonsterAbilities.request_packet(MonsterAbilities.Ability.LUNGE))
	_step(1)
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.WIND_UP)
	_hit_in(1)
	assert_int(_stuns()).is_equal(2)
	assert_bool(_ma.attacking()).is_false()


func test_rejected_wind_up_leaves_immunity_in_place() -> void:
	_observe_all()
	_hit_in(1)
	_step(_lock() + _t(2.0))
	_bf.request_form_change(MONSTER, BorrowedFace.request_packet(S1))
	_step(1)
	assert_bool(_bf.transforming()).is_true() # Transforming rejects the Lunge (since monster-abilities 012 a disguise does not)
	_ma.request_ability(MONSTER, MonsterAbilities.request_packet(MonsterAbilities.Ability.LUNGE))
	_step(1)
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.READY)
	_hit_in(1)
	assert_int(_stuns()).is_equal(1)


func test_completed_change_into_a_disguise_ends_immunity() -> void:
	_observe_all()
	_hit_in(1)
	_step(_lock())
	_bf.request_form_change(MONSTER, BorrowedFace.request_packet(S1))
	_step(1 + _t(_knobs.borrowed_face.transform_duration_s))
	assert_int(_bf.form()).is_equal(S1)
	_hit_in(1)
	assert_int(_stuns()).is_equal(2)
	assert_bool((_events[&"MonsterStunned"][1][0] as EvMonsterStunned).true_form).is_false()


# AC-5 -------------------------------------------------------------------------------------------

func _monster_hold() -> StubItem:
	var i := StubItem.new()
	i.point = Vector3.ZERO
	i.range_m = 2.0
	i.duration_s = 1.0
	_holds.register(i)
	_aim = i.net_id
	_press = true
	_holds.server_tick(_now())
	assert_dict(_holds.hold_of(MONSTER)).is_not_empty()
	return i


func test_stun_interrupts_a_search_or_break_keeping_progress() -> void:
	var i := _monster_hold()
	for n in 3:
		_step(1)
		_holds.server_tick(_now())
	_hit_in(1)
	assert_dict(_holds.hold_of(MONSTER)).is_empty()
	assert_array(i.log).is_equal(["cancel:shocked:true"])


## Steps a monster hold to the tick before its final one; returns it.
func _hold_to_final_tick() -> StubItem:
	var i := _monster_hold()
	var last := _now() + _t(i.duration_s)
	while _now() < last - 2:
		_step(1)
		_holds.server_tick(_now())
	assert_array(i.log).is_empty()
	return i


func test_unstunned_hold_completes_on_its_final_tick() -> void:
	var i := _hold_to_final_tick()
	_step(1)
	_holds.server_tick(_now())
	assert_array(i.log).is_equal(["complete"])


func test_stun_on_the_final_break_tick_interrupts_it() -> void:
	var i := _hold_to_final_tick()
	_hit_in(1)
	_holds.server_tick(_now()) # the Holds step (550) runs after the stun's flush
	assert_array(i.log).is_equal(["cancel:shocked:true"])
