# Story borrowed-face/005: action restrictions while Disguised or Transforming (design/gdd/borrowed-face.md
# rules 7, 8, 11, Edge Cases "Lunge requested while Disguised" (since monster-abilities 012: accepted, reveals), "Transform requested during a Lunge
# takedown commit"; ADR-0008 §2, §7; ADR-0005). BorrowedFace runs in a RoundServer with stub sight and
# status sources. Story monster-abilities/006 retired StubAbilities: the real MonsterAbilities is the
# ability request handler (status sources from the TRANSFORMING view), and Borrowed Face's attack source
# is its LungeView.is_attacking (StateKeys.LUNGE_STATE). A real HoldService (no physics: stub centre and sight) is the Holds step,
# barred through the same view; movement is MovementStep.gait with MoveState.transforming from the view.
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const SURVIVORS: Array[int] = [2, 3]
const EYE := Vector3(0.0, 1.6, 0.0)


## Logs callbacks; always eligible, so only HoldService's bar can refuse it.
class StubItem extends Interactable:
	var log: Array[String] = []

	func eligible(_actor: int) -> bool:
		return true

	func start_progress_s() -> float:
		return 0.0

	func on_start(_actor: int) -> void:
		log.append("start")

	func on_complete(_actor: int) -> void:
		log.append("complete")

	func on_cancel(_actor: int, _progress_s: float, reason: StringName) -> void:
		log.append("cancel:" + reason)


## The Holds step (ControllerAuthority's job, minus movement): runs HoldService at TickOrder.HOLDS.
class HoldsStep extends RefCounted:
	var _holds: HoldService

	func _init(holds: HoldService) -> void:
		_holds = holds

	func setup(_tr: TickRunner, _bus: EventBus, _reg: StateRegistry, _k: Knobs) -> void:
		pass

	func server_tick(tick: int) -> void:
		_holds.server_tick(tick)


var _server: RoundServer
var _bf: BorrowedFace
var _view: TransformView
var _knobs: Knobs
var _transform_ticks: int
var _ma: MonsterAbilities
var _holds: HoldService
var _item: StubItem
## MONSTER's input frame for this tick (repeated while unchanged, as InputQueue does when starved).
var _frame := InputFrame.new()


func before_test() -> void:
	_knobs = Knobs.load_all()
	_frame = InputFrame.new()
	_transform_ticks = _knobs.ticks(_knobs.borrowed_face.transform_duration_s)
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_bf = BorrowedFace.new()
	_bf.set_roster(SURVIVORS, MONSTER)
	_bf.set_sight_sources(_eye_of, _yaw_of, _points_of, _sight)
	_bf.set_status_source(_status_of)
	_ma = MonsterAbilities.new()
	_ma.set_monster(MONSTER)
	_holds = HoldService.new(_knobs, _players, _frames, _centre_of, _clear, _aim, Callable(), _is_monster)
	_holds.set_barred(_barred)
	_item = StubItem.new()
	_item.point = Vector3.ZERO
	_item.range_m = 2.0
	_item.duration_s = 5.0
	assert_array(_server.start_round({TickOrder.BORROWED_FACE: _bf, TickOrder.MONSTER_ABILITIES: _ma,
			TickOrder.HOLDS: HoldsStep.new(_holds)}, _knobs)).is_empty()
	_holds.register(_item)
	_view = _server.registry.view(StateKeys.TRANSFORMING, TransformView) as TransformView
	assert_object(_view).is_not_null()
	var lunge := _server.registry.view(StateKeys.LUNGE_STATE, LungeView) as LungeView
	assert_object(lunge).is_not_null()
	_ma.set_status_sources(_view.get_form, _view.get_transforming)
	_bf.set_attack_source(lunge.is_attacking)
	_step(_knobs.ticks(_knobs.borrowed_face.observe_time_s))
	assert_bool(_bf.observed(S1)).is_true()


func after_test() -> void:
	_server.end_round()


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


## Whether the real module would accept `ability` on the next tick (its request path's own check).
func _can(ability: MonsterAbilities.Ability) -> bool:
	return _ma.can_activate(ability, _server.tick_runner.current_tick() + 1)


## Sends a real Lunge request and steps one tick; true when the wind-up started.
func _lunge() -> bool:
	_ma.request_ability(MONSTER, MonsterAbilities.request_packet(MonsterAbilities.Ability.LUNGE))
	_step(1)
	return _ma.lunge_state() == MonsterAbilities.Lunge.WIND_UP


func _players() -> Array[int]:
	return [MONSTER]


func _frames(_a: int) -> Array[InputFrame]:
	return [_frame]


func _centre_of(_a: int) -> Vector3:
	return Vector3(0.0, 0.0, 1.0)


func _clear(_a: int, _i: Interactable) -> bool:
	return true


func _aim(_a: int) -> int:
	return _item.net_id


func _is_monster(a: int) -> bool:
	return a == MONSTER


## The composition root's wiring: the shapeshifter cannot interact while Transforming (rule 8).
func _barred(a: int) -> bool:
	return a == MONSTER and _view.get_transforming()


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


## Requests `form` and steps one tick; returns whether it was accepted.
func _request(form: int) -> bool:
	var before: bool = _view.get_transforming()
	_bf.request_form_change(MONSTER, BorrowedFace.request_packet(form))
	_step(1)
	return _view.get_transforming() and not before


func _become(form: int) -> void:
	assert_bool(_request(form)).is_true()
	_step(_transform_ticks)
	assert_int(_view.get_form()).is_equal(form)


func _interact(on: bool) -> void:
	var f := InputFrame.new()
	f.interact = on
	f.interact_target = _item.net_id
	_frame = f


func _gait(sprint: bool) -> MovementStep.Gait:
	var f := InputFrame.new()
	f.sprint = sprint
	f.move = Vector2(0.0, 1.0)
	var st := MovementStep.MoveState.new()
	st.transforming = _view.get_transforming()
	st.true_form = _view.get_form() == BorrowedFace.TRUE_FORM
	return MovementStep.gait(f, st)


## AC 1 (Edge Case "Lunge requested while Disguised", monster-abilities story 012, designer decision
## 2026-10-15): accepted, and the wind-up's first tick already shows true form (instant reveal).
func test_lunge_while_disguised_reveals_true_form_at_wind_up_start() -> void:
	_become(S1)
	assert_bool(_can(MonsterAbilities.Ability.FALSE_SIGNAL)).override_failure_message("False Signal and Blackout stay allowed while Disguised").is_true()
	assert_bool(_can(MonsterAbilities.Ability.BLACKOUT)).is_true()
	assert_bool(_lunge()).override_failure_message("a real request did not start a lunge while Disguised").is_true()
	assert_int(_view.get_form()).is_equal(BorrowedFace.TRUE_FORM)
	assert_bool(_view.get_transforming()).is_false()


## AC 1 (Edge Case "Transform requested during a Lunge takedown commit"): rejected, no cooldown cost.
## The attack is a real lunge's wind-up and dash (no hit sources: it misses and resolves into Cooldown).
func test_transform_during_an_attack_is_rejected_at_no_cooldown_cost() -> void:
	assert_bool(_lunge()).is_true()
	assert_bool(_request(S1)).is_false()
	for i in _knobs.ticks(_knobs.ability.lunge_windup_s) + _knobs.ticks(_knobs.ability.lunge_dash_s) + 1:
		if _ma.lunge_state() == MonsterAbilities.Lunge.COOLDOWN:
			break
		assert_bool(_request(S1)).override_failure_message("transform accepted mid-lunge").is_false()
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.COOLDOWN)
	assert_bool(_request(S1)).override_failure_message("rejected request started a cooldown").is_true()


## AC 2: Transforming caps the gait at walk and rejects ability requests; both return on completion.
func test_transforming_walks_but_cannot_sprint_or_use_abilities() -> void:
	assert_int(_gait(true)).is_equal(MovementStep.Gait.SPRINT)
	assert_bool(_request(S1)).is_true()
	assert_int(_gait(true)).is_equal(MovementStep.Gait.WALK)
	assert_float(MovementStep.gait_speed(_gait(true), MovementStep.MoveState.new(), _knobs)).is_greater(0.0)
	assert_bool(_can(MonsterAbilities.Ability.FALSE_SIGNAL)).is_false()
	assert_bool(_can(MonsterAbilities.Ability.LUNGE)).is_false()
	_step(_transform_ticks)
	assert_bool(_view.get_transforming()).is_false()
	assert_int(_gait(true)).is_equal(MovementStep.Gait.SPRINT)
	assert_bool(_can(MonsterAbilities.Ability.FALSE_SIGNAL)).is_true()


## AC 2: an interact Start while Transforming is rejected, a fake included; it works once complete.
func test_interact_start_is_rejected_while_transforming() -> void:
	assert_bool(_request(S1)).is_true()
	_interact(true)
	_step(1)
	assert_dict(_holds.hold_of(MONSTER)).is_empty()
	_item.fakeable = true
	_interact(false)
	_step(1)
	_interact(true)
	_step(1)
	assert_dict(_holds.hold_of(MONSTER)).override_failure_message("fake hold while Transforming").is_empty()
	_interact(false)
	_step(_transform_ticks)
	_interact(true)
	_step(1)
	assert_dict(_holds.hold_of(MONSTER)).is_not_empty()
	assert_array(_item.log).is_empty() ## the accepted hold is a fake: the owner never hears of it


## AC 2: a hold running when the transformation starts is cancelled on the next Holds step.
func test_a_running_hold_is_cancelled_when_transforming_starts() -> void:
	_interact(true)
	_step(1)
	assert_array(_item.log).is_equal(["start"])
	assert_bool(_request(S1)).is_true()
	assert_array(_item.log).is_equal(["start", "cancel:ineligible"])
	assert_dict(_holds.hold_of(MONSTER)).is_empty()
