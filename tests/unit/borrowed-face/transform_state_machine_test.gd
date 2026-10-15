# Story borrowed-face/003: transform state machine, cooldown and FormChanged
# (design/gdd/borrowed-face.md rules 7-10, 14-15, Formulas "Form-change timing", Edge Cases "Stun
# lands on the tick ...", "Round ends mid-transformation", "Reveal scare suppressed ..."; ADR-0005).
# Hits land through the real SurvivorDefense.shock from a Hitter in the MATCH_FLOW_BEGIN slot; Survivor
# Defense (slot 200) locks the monster and emits MonsterStunned (survivor-defense story 012 retired the stub).
# Scare Events is a FormChanged subscriber on the bus. Sight and status sources are stubs.
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const S2 := 3
const SURVIVORS: Array[int] = [2, 3]
const EYE := Vector3(0.0, 1.6, 0.0)


## Lands a hit through SurvivorDefense.shock on MONSTER on each tick in `hit_ticks`, before its slot.
class Hitter extends RefCounted:
	var hit_ticks: Array[int] = []
	## Every hit's outcome: [tick, stunned] (SurvivorDefense.shock's result).
	var hits: Array = []
	var shock: Callable

	func setup(_tr: TickRunner, _bus: EventBus, _reg: StateRegistry, _k: Knobs) -> void:
		pass

	func server_tick(tick: int) -> void:
		if hit_ticks.has(tick):
			hits.append([tick, shock.call(MONSTER, tick)])


var _server: RoundServer
var _bf: BorrowedFace
var _defense: Hitter
var _def: SurvivorDefense
var _knobs: Knobs
var _transform_ticks: int
var _cooldown_ticks: int
var _observe_ticks: int
var _lock_ticks: int
## Every FormChanged the stub Scare Events subscriber received: [event, tick it was handled on].
var _changes: Array = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_server = null
	_changes = []


func _start(knobs: Knobs = _knobs) -> void:
	_transform_ticks = knobs.ticks(knobs.borrowed_face.transform_duration_s)
	_cooldown_ticks = knobs.ticks(knobs.borrowed_face.form_change_cooldown_s)
	_observe_ticks = knobs.ticks(knobs.borrowed_face.observe_time_s)
	_lock_ticks = knobs.ticks(knobs.defense.stun_duration_s)
	if _server == null:
		_server = auto_free(RoundServer.new())
		add_child(_server)
	_bf = BorrowedFace.new()
	_bf.set_roster(SURVIVORS, MONSTER)
	_def = SurvivorDefense.new()
	_def.set_roster(SURVIVORS, MONSTER)
	_def.set_form_source(_bf.form)
	_defense = Hitter.new()
	_defense.shock = _def.shock
	_bf.set_sight_sources(_eye_of, _yaw_of, _points_of, _sight, _def.locked)
	_bf.set_status_source(_status_of)
	assert_array(_server.start_round({TickOrder.MATCH_FLOW_BEGIN: _defense, TickOrder.SURVIVOR_DEFENSE: _def,
		TickOrder.BORROWED_FACE: _bf}, knobs)).is_empty()
	_server.bus.subscribe(&"FormChanged", _on_form_changed)
	_step(_observe_ticks)
	assert_bool(_bf.observed(S1) and _bf.observed(S2)).is_true()


func _eye_of(_p: int) -> Vector3:
	return EYE


func _yaw_of(_p: int) -> float:
	return 0.0


func _points_of(_p: int) -> PackedVector3Array:
	var chest := EYE + Vector3.FORWARD * 5.0
	return PackedVector3Array([chest + Vector3.UP * 0.4, chest, chest + Vector3.DOWN * 0.3])


func _sight(_eye: Vector3, _point: Vector3) -> bool:
	return true


func _status_of(_p: int) -> int:
	return MatchFlow.Status.HEALTHY


func _on_form_changed(e: ServerEvent) -> void:
	_changes.append([e, _server.tick_runner.current_tick()])


func _tick() -> int:
	return _server.tick_runner.current_tick()


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


## Requests `form` and steps one tick; returns whether it was accepted.
func _request(form: int) -> bool:
	var before := _bf.transforming()
	_bf.request_form_change(MONSTER, BorrowedFace.request_packet(form))
	_step(1)
	return _bf.transforming() and not before


## Requests `form`, runs the whole transformation; returns the completion tick.
func _become(form: int) -> int:
	assert_bool(_request(form)).is_true()
	_step(_transform_ticks)
	assert_int(_bf.form()).is_equal(form)
	return _tick()


## AC 1: completes transform_duration_s after acceptance, with one FormChanged at that tick.
func test_change_completes_transform_duration_after_acceptance() -> void:
	_start()
	assert_bool(_request(S1)).is_true()
	var accepted := _tick()
	_step(_transform_ticks - 1)
	assert_int(_bf.form()).is_equal(BorrowedFace.TRUE_FORM)
	assert_array(_changes).is_empty()
	_step(1)
	assert_int(_bf.form()).is_equal(S1)
	assert_bool(_bf.transforming()).is_false()
	assert_int(_changes.size()).is_equal(1)
	var e := _changes[0][0] as EvFormChanged
	assert_int(e.tick - accepted).is_equal(_transform_ticks)
	assert_float(e.server_time - float(accepted) / _knobs.net.sim_tick_hz) \
		.is_equal_approx(_knobs.borrowed_face.transform_duration_s, 1.0 / _knobs.net.sim_tick_hz)


## AC 1 and Formulas "Form-change timing": the next request is accepted exactly cooldown after completion.
func test_next_request_rejected_until_cooldown_after_completion() -> void:
	_start()
	var done := _become(S1)
	_step(_cooldown_ticks - 2)
	assert_bool(_request(S2)).is_false() # tick done + cooldown - 1
	assert_int(_tick()).is_equal(done + _cooldown_ticks - 1)
	assert_bool(_request(S2)).is_true() # tick done + cooldown
	assert_int(_tick()).is_equal(done + _cooldown_ticks)


## AC 2 and rule 10: a stun keeps the previous form, emits nothing and starts the cooldown at the interrupt.
func test_stun_during_transformation_keeps_form_and_starts_cooldown() -> void:
	_start()
	var done := _become(S1)
	_step(_cooldown_ticks - 1)
	assert_bool(_request(BorrowedFace.TRUE_FORM)).is_true()
	var stun := _tick() + _transform_ticks / 2
	_defense.hit_ticks = [stun]
	_step(stun - _tick())
	assert_bool(_bf.transforming()).is_false()
	assert_int(_bf.form()).is_equal(S1)
	_step(_transform_ticks)
	assert_int(_bf.form()).is_equal(S1)
	assert_int(_changes.size()).is_equal(1) # only the first change
	assert_int((_changes[0][0] as EvFormChanged).tick).is_equal(done)
	_step(_cooldown_ticks - _transform_ticks - 2)
	assert_bool(_request(S2)).is_false() # tick stun + cooldown - 1
	assert_bool(_request(S2)).is_true()
	assert_int(_tick()).is_equal(stun + _cooldown_ticks)


## AC 2 and rule 9: a stun on the tick the change would complete wins.
func test_stun_on_completion_tick_wins() -> void:
	_start()
	assert_bool(_request(S1)).is_true()
	_defense.hit_ticks = [_tick() + _transform_ticks]
	_step(_transform_ticks)
	assert_int(_bf.form()).is_equal(BorrowedFace.TRUE_FORM)
	assert_bool(_bf.transforming()).is_false()
	assert_array(_changes).is_empty()
	assert_bool(_request(S2)).is_false() # cooldown started at the interrupt


## AC 2 and rule 7: no transformation starts while Stunned, and the rejection costs no cooldown.
func test_no_transformation_starts_while_stunned() -> void:
	_start()
	_defense.hit_ticks = [_tick() + 1]
	_step(1)
	assert_bool(_def.locked(MONSTER)).is_true()
	assert_bool(_request(S1)).is_false()
	_step(_lock_ticks)
	assert_bool(_request(S1)).is_true()


## A stun outside a transformation starts no cooldown (rule 10 names only an interrupt).
func test_stun_while_not_transforming_costs_nothing() -> void:
	_start()
	_defense.hit_ticks = [_tick() + 1]
	_step(1 + _lock_ticks) # the shock lock (rule 14) bars requests; no cooldown follows it
	assert_bool(_request(S1)).is_true()


## AC 3: each completion emits one FormChanged (shapeshifter, previous, new, server time), and a change
## into true form reaches the Scare Events subscriber on its own tick. The stub suppresses the
## reveal (does nothing) and the form still changes on time.
func test_form_changed_payload_and_same_tick_reveal() -> void:
	_start()
	var first := _become(S1)
	_step(_cooldown_ticks - 1)
	var second := _become(BorrowedFace.TRUE_FORM)
	assert_int(_changes.size()).is_equal(2)
	var expect := [[BorrowedFace.TRUE_FORM, S1, first], [S1, BorrowedFace.TRUE_FORM, second]]
	for i in 2:
		var e := _changes[i][0] as EvFormChanged
		assert_int(e.player).is_equal(MONSTER)
		assert_int(e.previous).is_equal(expect[i][0])
		assert_int(e.form).is_equal(expect[i][1])
		assert_int(e.tick).is_equal(expect[i][2])
		assert_int(_changes[i][1]).is_equal(expect[i][2]) # handled the tick it was emitted
		assert_float(e.server_time).is_equal_approx(float(e.tick) / _knobs.net.sim_tick_hz, 1e-6)


## AC 4: a round ending mid-transformation discards it; the next round starts clean.
func test_round_end_mid_transformation_discards_it() -> void:
	_start()
	_become(S1)
	_step(_cooldown_ticks - 1)
	assert_bool(_request(S2)).is_true()
	_step(_transform_ticks / 2)
	_server.end_round()
	_changes = []
	_start()
	assert_int(_bf.form()).is_equal(BorrowedFace.TRUE_FORM)
	assert_bool(_bf.transforming()).is_false()
	assert_array(_changes).is_empty()
	assert_bool(_request(S1)).is_true() # no cooldown carried over


## AC 4: duration and cooldown come from BorrowedFaceKnobs.
func test_timings_come_from_knobs() -> void:
	var k := Knobs.load_all()
	k.borrowed_face.transform_duration_s = 1.0
	k.borrowed_face.form_change_cooldown_s = 6.0
	_start(k)
	assert_int(_transform_ticks).is_equal(k.net.sim_tick_hz)
	var done := _become(S1)
	_step(_cooldown_ticks - 1)
	assert_bool(_request(S2)).is_true()
	assert_int(_tick()).is_equal(done + 6 * k.net.sim_tick_hz)


## Emits an accepted activation of `ability` (MonsterAbilities' AbilityUsed) and steps one tick.
func _ability_used(ability: MonsterAbilities.Ability) -> void:
	var e := EvAbilityUsed.new()
	e.ability = ability
	_server.bus.emit(e)
	_step(1)


## Story monster-abilities/012 (rule 11, designer decision 2026-10-15): a Lunge accepted while Disguised
## reveals true form at once, with one FormChanged and no transformation or new cooldown; other abilities
## and a lunge in true form change nothing.
func test_lunge_from_disguise_reveals_true_form_instantly() -> void:
	_start()
	_become(S1)
	var cooldown_end := _bf.cooldown_end_tick()
	_changes.clear()
	_ability_used(MonsterAbilities.Ability.FALSE_SIGNAL)
	_ability_used(MonsterAbilities.Ability.BLACKOUT)
	assert_int(_bf.form()).is_equal(S1)
	assert_array(_changes).is_empty()
	_ability_used(MonsterAbilities.Ability.LUNGE)
	assert_int(_bf.form()).is_equal(BorrowedFace.TRUE_FORM)
	assert_bool(_bf.transforming()).is_false()
	assert_int(_bf.cooldown_end_tick()).is_equal(cooldown_end)
	assert_int(_changes.size()).is_equal(1)
	var c := _changes[0][0] as EvFormChanged
	assert_array([c.player, c.previous, c.form, _changes[0][1]]).is_equal([MONSTER, S1, BorrowedFace.TRUE_FORM, _tick()])
	_ability_used(MonsterAbilities.Ability.LUNGE)
	assert_int(_changes.size()).is_equal(1)
