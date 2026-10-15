# Story controller-interaction/009: hold continuation, cancels and movement while Holding (ADR-0008 §4,
# §5, §7; first-person-controller.md rules 14, 16). HoldService runs on stub Interactables with fed
# frames, centres and sight, as in hold_service_start_test.gd; the movement checks run the real
# MovementStep on a real PlayerBody.
extends GdUnitTestSuite

const A := 1
const HOLD_S := 1.0 ## 60 ticks at the shipped 60 Hz: long enough to break mid-hold
const RANGE_M := 1.5

var _knobs: Knobs
var _holds: HoldService
var _feed: Dictionary = {}
var _centres: Dictionary = {}
var _blind: Dictionary = {}
var _aimed: Dictionary = {} ## actor -> net id the server's ray picks now; absent = the claimed target
var _tick := 0
var _world: Node3D


class Stub extends Interactable:
	var log: Array[String] = []
	var allowed := true

	func eligible(_actor: int) -> bool:
		return allowed

	func start_progress_s() -> float:
		return 0.0

	func on_start(actor: int) -> void:
		log.append("start:%d" % actor)

	func on_complete(actor: int) -> void:
		log.append("complete:%d" % actor)

	func on_cancel(actor: int, progress_s: float, reason: StringName) -> void:
		log.append("cancel:%d:%.3f:%s" % [actor, progress_s, reason])


## Becomes ineligible as soon as a hold starts on it.
class ClosingStub extends Stub:
	func on_start(actor: int) -> void:
		super(actor)
		allowed = false


func before_test() -> void:
	_knobs = Knobs.load_all()
	_feed = {}
	_centres = {A: Vector3.ZERO}
	_blind = {}
	_aimed = {}
	_tick = 0
	_world = null
	_holds = HoldService.new(_knobs, func() -> Array: return _centres.keys(),
		func(actor: int) -> Array: return _feed.get(actor, []),
		func(actor: int) -> Vector3: return _centres[actor],
		func(actor: int, _i: Interactable) -> bool: return not _blind.has(actor),
		func(actor: int) -> int: return _aimed[actor] if _aimed.has(actor) else _claimed(actor))


func after_test() -> void:
	if _world != null:
		_world.free()


func _claimed(actor: int) -> int:
	var id := -1
	for f: InputFrame in _feed.get(actor, []):
		if f.interact:
			id = f.interact_target
	return id


func _stub(roots := false) -> Stub:
	var s := Stub.new()
	s.point = Vector3(0.0, 0.0, -1.0)
	s.range_m = RANGE_M
	s.duration_s = HOLD_S
	s.roots_actor = roots
	_holds.register(s)
	return s


func _f(interact: bool, target := 0, yaw := 0.0) -> InputFrame:
	var f := InputFrame.new()
	f.interact = interact
	f.interact_target = target
	f.yaw = yaw
	return f


func _step(frames: Array = []) -> void:
	if not frames.is_empty():
		_feed[A] = frames
	_holds.server_tick(_tick)
	_tick += 1


## Starts A's hold on `s` and runs `ticks` more held ticks; returns the elapsed ticks of the hold.
func _hold(s: Stub, ticks: int) -> int:
	_step([_f(true, s.net_id)])
	for i in ticks:
		_step([_f(true, s.net_id)])
	assert_int(_holds.hold_of(A).get("net_id", -1)).is_equal(s.net_id)
	return _holds.hold_of(A).elapsed_ticks


## The point sits at (0, 0, -1); this places A's capsule centre `d` metres from it, behind.
func _at_distance(d: float) -> void:
	_centres[A] = Vector3(0.0, 0.0, -1.0 + d)


# --- AC1: continues ------------------------------------------------------------------------

## Rule 14: a hold survives looking away. HoldService reads neither the view nor the server's aim
## while holding (aim is read on the Start only), so this pins that by omission.
func test_a_hold_ignores_aim_and_view_through_a_180_degree_turn() -> void:
	var s := _stub()
	_hold(s, 5)
	_aimed[A] = -1 ## the server's ray now sees nothing there
	for i in 10:
		_step([_f(true, s.net_id, PI)])
	assert_int(_holds.hold_of(A).net_id).is_equal(s.net_id)
	assert_array(s.log).is_equal(["start:1"])


func test_a_hold_continues_at_range_plus_02() -> void:
	assert_float(_knobs.controller.hold_range_tolerance_m).is_equal(0.25) ## the GDD's +0.2 / +0.25 cases
	var s := _stub()
	_hold(s, 5)
	_at_distance(RANGE_M + 0.2)
	for i in 10:
		_step()
	assert_int(_holds.hold_of(A).net_id).is_equal(s.net_id)


func test_a_hold_continues_exactly_at_range_plus_tolerance() -> void:
	var s := _stub()
	_hold(s, 5)
	_at_distance(RANGE_M + _knobs.controller.hold_range_tolerance_m)
	_step()
	assert_int(_holds.hold_of(A).net_id).is_equal(s.net_id)


# --- AC2: cancels on that tick, with its reason --------------------------------------------

## Each break happens after 10 held ticks; the cancel lands on the next tick with the progress so far.
func _breaks(s: Stub, reason: String, broken: Callable, frames: Array = []) -> void:
	var elapsed := _hold(s, 10)
	broken.call()
	_step(frames)
	assert_dict(_holds.hold_of(A)).is_empty()
	assert_array(s.log).is_equal(["start:1", "cancel:1:%.3f:%s" % [elapsed / float(_knobs.net.sim_tick_hz), reason]])


func test_beyond_range_plus_025_cancels_that_tick() -> void:
	var s := _stub()
	_breaks(s, "range", func() -> void: _at_distance(RANGE_M + 0.26))


func test_lost_line_of_sight_cancels_that_tick() -> void:
	var s := _stub()
	_breaks(s, "sight", func() -> void: _blind[A] = true)


func test_released_input_cancels_that_tick() -> void:
	var s := _stub()
	_breaks(s, "released", func() -> void: pass, [_f(false, s.net_id)])


func test_an_owner_interrupt_cancels_with_the_owners_reason() -> void:
	var s := _stub()
	var elapsed := _hold(s, 10)
	_holds.cancel(A, &"shocked") ## e.g. PlayerShocked's owner (wired by its epic)
	assert_dict(_holds.hold_of(A)).is_empty()
	assert_array(s.log).is_equal(["start:1", "cancel:1:%.3f:shocked" % (elapsed / float(_knobs.net.sim_tick_hz))])
	_step() ## nothing more happens
	assert_array(s.log).has_size(2)


func test_starting_another_hold_cancels_the_first() -> void:
	var s := _stub()
	var t := _stub()
	t.point = s.point
	var elapsed := _hold(s, 10)
	_step([_f(false, s.net_id), _f(true, t.net_id)]) ## release and press on the other in one tick
	assert_int(_holds.hold_of(A).net_id).is_equal(t.net_id)
	assert_array(s.log).is_equal(["start:1", "cancel:1:%.3f:replaced" % (elapsed / float(_knobs.net.sim_tick_hz))]) ## rule 16
	assert_array(t.log).is_equal(["start:1"])


## No release between the two presses: no rising edge, so the second target is never read and the
## first hold continues (ADR-0008 §3: the target is read on the rising edge only).
func test_pressing_another_target_without_releasing_changes_nothing() -> void:
	var s := _stub()
	var t := _stub()
	_hold(s, 5)
	_step([_f(true, t.net_id)])
	assert_int(_holds.hold_of(A).net_id).is_equal(s.net_id)
	assert_array(s.log).is_equal(["start:1"])
	assert_array(t.log).is_empty()


## An owner whose on_start makes the actor ineligible for a new Start (a drive marked "being held")
## does not cancel its own hold on that tick (code review 2026-10-14).
func test_an_owner_changing_eligibility_in_on_start_keeps_the_hold_that_tick() -> void:
	var s := ClosingStub.new()
	s.point = Vector3(0.0, 0.0, -1.0)
	s.range_m = RANGE_M
	s.duration_s = HOLD_S
	_holds.register(s)
	_step([_f(true, s.net_id)])
	assert_int(_holds.hold_of(A).get("net_id", -1)).is_equal(s.net_id)
	assert_array(s.log).is_equal(["start:1"])


# --- AC4: the target's owner state changes mid-hold -----------------------------------------

func test_target_picked_up_mid_hold_the_owner_cancels_with_its_rule() -> void:
	var s := _stub()
	var elapsed := _hold(s, 10)
	_holds.cancel(A, &"picked_up") ## the owner moved the drive into someone's hands
	assert_str(s.log.back()).is_equal("cancel:1:%.3f:picked_up" % (elapsed / float(_knobs.net.sim_tick_hz)))


func test_target_no_longer_eligible_mid_hold_cancels_that_tick() -> void:
	var s := _stub()
	_breaks(s, "ineligible", func() -> void: s.allowed = false) ## e.g. the Downed survivor was rescued


# --- AC3: movement while Holding ------------------------------------------------------------

func _body() -> PlayerBody:
	_world = Node3D.new()
	add_child(_world)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = PhysicsLayers.WORLD
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	(cs.shape as BoxShape3D).size = Vector3(40, 1, 40)
	floor_body.add_child(cs)
	_world.add_child(floor_body)
	floor_body.global_position = Vector3(0, -0.5, 0)
	var b := PlayerBody.new()
	b.setup(_knobs, PhysicsLayers.MOVE_SERVER)
	_world.add_child(b)
	return b


## Sprints forward for 30 ticks with `state`; returns the horizontal speed reached.
func _sprint(b: PlayerBody, state: MovementStep.MoveState) -> float:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var f := InputFrame.new()
	f.move = Vector2(0, 1)
	f.sprint = true
	for i in 30:
		await get_tree().physics_frame
		MovementStep.step(b, f, state, _knobs)
	return Vector2(b.velocity.x, b.velocity.z).length()


func test_sprint_while_holding_gives_walk_speed() -> void:
	var state := MovementStep.MoveState.new()
	state.holding = true
	assert_float(await _sprint(_body(), state)).is_equal_approx(_knobs.controller.walk_speed, 0.001)
	assert_float(_knobs.controller.walk_speed).is_equal(4.0) ## the GDD's 4.0 m/s


func test_a_rooting_hold_gives_0() -> void:
	var state := MovementStep.MoveState.new()
	state.holding = true
	state.hold_roots = true
	var b := _body()
	assert_float(await _sprint(b, state)).is_equal(0.0)
	assert_float(b.global_position.z).is_equal_approx(0.0, 0.001)


func test_crouch_input_while_holding_leaves_posture_unchanged() -> void:
	var b := _body()
	await get_tree().physics_frame
	var state := MovementStep.MoveState.new()
	state.holding = true
	var crouch := InputFrame.new()
	crouch.crouch = true
	var stand := InputFrame.new()
	b.set_low(MovementStep.wants_low(crouch, state, false)) ## standing: stays standing
	assert_float(b.capsule().height).is_equal_approx(_knobs.controller.capsule_height_m, 0.0001)
	b.set_low(true) ## crouched before the hold
	b.set_low(MovementStep.wants_low(stand, state, true)) ## crouch released while holding: stays low
	assert_float(b.capsule().height).is_equal_approx(_knobs.controller.capsule_low_height_m, 0.0001)
	state.holding = false
	b.set_low(MovementStep.wants_low(stand, state, true)) ## the hold ended: the input counts again
	assert_float(b.capsule().height).is_equal_approx(_knobs.controller.capsule_height_m, 0.0001)


## The hold's own snapshot fields drive the step: hold_of().roots is what the caller copies.
func test_hold_of_reports_roots_for_the_movement_step() -> void:
	var s := _stub(true)
	_hold(s, 1)
	assert_bool(_holds.hold_of(A).roots).is_true()
