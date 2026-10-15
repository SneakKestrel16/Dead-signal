# Story borrowed-face/004: stun immunity during and after transformation
# (design/gdd/borrowed-face.md Acceptance Criteria on immune hits, Edge Cases "Immune taser hit during
# transformation ...", "Transformation into a disguise completes while Immune ..."; survivor-defense.md
# rules 9, 10, 14, 16; ADR-0005 tick order: Survivor Defense (slot 200) steps before Borrowed Face).
# Hits land through the real SurvivorDefense.shock from a Hitter in the MATCH_FLOW_BEGIN slot (survivor-defense
# story 012 retired the stand-in that modelled its rules 9, 10, 14 and 16).
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
## End of the latest stun's post-lock window (hit + stun_duration_s + stun_immunity_s, rule 14).
var _immune_end := 0
var _knobs: Knobs
var _transform_ticks: int
var _cooldown_ticks: int
var _lock_ticks: int
var _immunity_ticks: int
## Every event received by type: [event, tick handled].
var _events: Dictionary[StringName, Array] = {}


func before_test() -> void:
	_knobs = Knobs.load_all()
	_events = {&"FormChanged": [], &"MonsterStunned": [], &"PlayerShocked": []}
	_transform_ticks = _knobs.ticks(_knobs.borrowed_face.transform_duration_s)
	_cooldown_ticks = _knobs.ticks(_knobs.borrowed_face.form_change_cooldown_s)
	_lock_ticks = _knobs.ticks(_knobs.defense.stun_duration_s)
	_immunity_ticks = _knobs.ticks(_knobs.defense.stun_immunity_s)
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
		TickOrder.BORROWED_FACE: _bf}, _knobs)).is_empty()
	for t: StringName in _events:
		_server.bus.subscribe(t, _on_event)
	_step(_knobs.ticks(_knobs.borrowed_face.observe_time_s))
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


func _on_event(e: ServerEvent) -> void:
	_events[e.type()].append([e, _tick()])


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


## A real stun on the next tick, then steps until its lock has ended: the monster is now immune.
func _stun_and_wait_out_lock() -> void:
	_defense.hit_ticks.append(_tick() + 1)
	_step(1)
	assert_bool(_defense.hits.back()[1]).is_true()
	_immune_end = _tick() + _lock_ticks + _immunity_ticks
	_step(_lock_ticks)
	assert_bool(_def.locked(MONSTER)).is_false()
	assert_bool(_tick() < _immune_end).is_true()


## Accepts a change into `form`, an immune hit halfway, and checks it completes on time untouched.
func _assert_immune_hit_does_not_interrupt(form: int, previous: int) -> void:
	var stunned_before: int = _events[&"MonsterStunned"].size()
	assert_bool(_request(form)).is_true()
	var accepted := _tick()
	var hit := accepted + _transform_ticks / 2
	_defense.hit_ticks.append(hit)
	_step(hit - _tick())
	assert_bool(_defense.hits.back()[1]).is_false() # immune
	assert_int(_events[&"MonsterStunned"].size()).is_equal(stunned_before)
	assert_bool(_def.locked(MONSTER)).is_false() # no root, slow or lock
	assert_bool(_bf.transforming()).is_true()
	assert_int(_bf.form()).is_equal(previous)
	_step(accepted + _transform_ticks - _tick())
	assert_int(_bf.form()).is_equal(form)
	var e := _events[&"FormChanged"].back()[0] as EvFormChanged
	assert_int(e.tick).is_equal(accepted + _transform_ticks)
	assert_int(e.previous).is_equal(previous)


## AC 1, out of a disguise: the borrowed body shows the shock, the change still completes 2 s after acceptance.
func test_immune_hit_does_not_interrupt_transformation_out_of_disguise() -> void:
	assert_bool(_request(S1)).is_true()
	_step(_transform_ticks)
	assert_int(_bf.form()).is_equal(S1)
	_step(_cooldown_ticks)
	_stun_and_wait_out_lock()
	var shocks: int = _events[&"PlayerShocked"].size()
	_assert_immune_hit_does_not_interrupt(BorrowedFace.TRUE_FORM, S1)
	assert_int(_events[&"PlayerShocked"].size()).is_equal(shocks + 1) # full shock on the borrowed body


## AC 1, out of true form: the resisted hit is a PlayerShocked on the true-form body, no stun; completes on time.
func test_immune_hit_does_not_interrupt_transformation_out_of_true_form() -> void:
	_stun_and_wait_out_lock()
	_assert_immune_hit_does_not_interrupt(S1, BorrowedFace.TRUE_FORM)
	## the real module (survivor-defense story 005) sends the resisted hit as PlayerShocked on the true-form
	## body; clients tell it from a stun by the missing MonsterStunned and show the spark
	assert_int(_events[&"PlayerShocked"].size()).is_equal(1)
	assert_int((_events[&"PlayerShocked"][0][0] as EvPlayerShocked).player).is_equal(MONSTER)


## AC 2: an immune hit on a disguise changes nothing, and a request in the following stun_duration_s
## is not rejected on that account, even on the hit's own tick (Defense steps first, ADR-0005).
func test_immune_hit_on_disguise_does_not_block_a_request() -> void:
	assert_bool(_request(S1)).is_true()
	_step(_transform_ticks + _cooldown_ticks)
	_stun_and_wait_out_lock()
	_defense.hit_ticks.append(_tick() + 1)
	assert_bool(_request(S2)).is_true() # requested on the immune hit's tick
	assert_bool(_defense.hits.back()[1]).is_false()
	assert_int(_bf.form()).is_equal(S1)
	assert_int(_events[&"MonsterStunned"].size()).is_equal(1) # only the first, real stun


## AC 2: the same request on an immune hit inside the window, mid stun_duration_s after it, is accepted.
func test_request_mid_stun_duration_after_immune_hit_is_accepted() -> void:
	assert_bool(_request(S1)).is_true()
	_step(_transform_ticks + _cooldown_ticks)
	_stun_and_wait_out_lock()
	_defense.hit_ticks.append(_tick() + 1)
	_step(_lock_ticks / 2)
	assert_bool(_defense.hits.back()[1]).is_false()
	assert_bool(_request(S2)).is_true()


## AC 3: completing a change into a disguise inside stun_immunity_s ends immunity; the next hit stuns,
## locks (rule 14) and shows as a shock, so a request during the lock is rejected.
func test_disguise_completed_while_immune_is_stunned_by_next_hit() -> void:
	_stun_and_wait_out_lock()
	var window_end := _immune_end
	assert_bool(_request(S1)).is_true()
	_step(_transform_ticks)
	assert_int(_bf.form()).is_equal(S1)
	var done := _tick()
	assert_bool(done + 1 < window_end).is_true() # the hit lands inside the old immunity window
	_defense.hit_ticks.append(done + 1)
	_step(1)
	assert_bool(_defense.hits.back()[1]).is_true()
	assert_int(_events[&"MonsterStunned"].size()).is_equal(2)
	var e := _events[&"MonsterStunned"].back()[0] as EvMonsterStunned
	assert_bool(e.true_form).is_false()
	assert_int(_events[&"PlayerShocked"].back()[1]).is_equal(done + 1)
	assert_bool(_def.locked(MONSTER)).is_true()
	_step(_cooldown_ticks)
	assert_bool(_request(S2)).is_true() # lock and cooldown over: the stun cost only the lock
