# Story controller-interaction/010: shapeshifter fake holds (ADR-0008 §6, §8; first-person-controller.md
# rule 17; survivor-objectives.md rule 25). HoldService runs on stub Interactables with fed frames,
# centres and sight, as in hold_service_start_test.gd. The observers' `holding` pose bit is
# hold_of(actor) being non-empty: no snapshot writes the bit yet (inference: the body snapshot story
# settles it), so AC3 asserts the source the bit is read from.
extends GdUnitTestSuite

const SHIFTER := 1
const SURVIVOR := 2
const HOLD_S := 0.5 ## 30 ticks at the shipped 60 Hz

var _knobs: Knobs
var _holds: HoldService
var _feed: Dictionary = {}
var _centres: Dictionary = {}
var _tick := 0


## Logs every owner call, eligible() included: a fake must make none.
class Stub extends Interactable:
	var log: Array[String] = []
	var shifter := SHIFTER

	func eligible(actor: int) -> bool:
		log.append("eligible:%d" % actor)
		return actor != shifter ## objectives refuse the shapeshifter's real work

	func start_progress_s() -> float:
		log.append("progress")
		return 0.0

	func on_start(actor: int) -> void:
		log.append("start:%d" % actor)

	func on_complete(actor: int) -> void:
		log.append("complete:%d" % actor)

	func on_cancel(actor: int, progress_s: float, reason: StringName) -> void:
		log.append("cancel:%d:%.2f:%s" % [actor, progress_s, reason])


func before_test() -> void:
	_knobs = Knobs.load_all()
	_feed = {}
	_centres = {SHIFTER: Vector3.ZERO, SURVIVOR: Vector3.ZERO}
	_tick = 0
	_holds = HoldService.new(_knobs, func() -> Array: return _centres.keys(),
		func(actor: int) -> Array: return _feed.get(actor, []),
		func(actor: int) -> Vector3: return _centres[actor],
		func(_actor: int, _i: Interactable) -> bool: return true,
		func(actor: int) -> int: return _claimed(actor),
		Callable(),
		func(actor: int) -> bool: return actor == SHIFTER)


func _claimed(actor: int) -> int:
	var id := -1
	for f: InputFrame in _feed.get(actor, []):
		if f.interact:
			id = f.interact_target
	return id


func _stub(fakeable := true) -> Stub:
	var s := Stub.new()
	s.point = Vector3(0.0, 0.0, -1.0)
	s.range_m = 1.5
	s.duration_s = HOLD_S
	s.lock_key = &"drive_slot" ## exclusive
	s.roots_actor = true
	s.fakeable = fakeable
	_holds.register(s)
	return s


func _f(interact: bool, target := 0) -> InputFrame:
	var f := InputFrame.new()
	f.interact = interact
	f.interact_target = target
	return f


func _step(frames: Dictionary = {}) -> void:
	for actor: int in frames:
		_feed[actor] = frames[actor]
	_holds.server_tick(_tick)
	_tick += 1


# --- AC1: no progress, no lock, no owner call -------------------------------------

func test_fake_past_duration_has_zero_progress_no_lock_and_no_owner_call() -> void:
	var s := _stub()
	_step({SHIFTER: [_f(true, s.net_id)]})
	for i in _knobs.ticks(HOLD_S) * 2: # the repeat frame keeps it pressed
		_step()
	var h := _holds.hold_of(SHIFTER)
	assert_bool(h.fake).is_true()
	assert_int(h.elapsed_ticks).is_equal(0) # never completes
	assert_array(s.log).is_empty()
	_step({SHIFTER: [_f(false)]})
	assert_dict(_holds.hold_of(SHIFTER)).is_empty()
	assert_array(s.log).is_empty() # the release calls no on_cancel either


# --- AC2: a survivor's Start cancels the fake --------------------------------------

func test_survivor_start_takes_the_target_and_cancels_the_fake() -> void:
	var s := _stub()
	_step({SHIFTER: [_f(true, s.net_id)]})
	_step({SURVIVOR: [_f(true, s.net_id)]})
	assert_array(s.log).is_equal(["eligible:%d" % SURVIVOR, "progress", "start:%d" % SURVIVOR])
	assert_dict(_holds.hold_of(SHIFTER)).is_empty()
	assert_bool(_holds.hold_of(SURVIVOR).fake).is_false()


# --- AC3: same pose bit; non-fakeable rejects --------------------------------------

func test_observers_see_the_same_hold_for_a_fake_as_for_a_real_hold() -> void:
	var s := _stub()
	var t := _stub()
	t.lock_key = &"other"
	_step({SHIFTER: [_f(true, s.net_id)], SURVIVOR: [_f(true, t.net_id)]})
	var fake := _holds.hold_of(SHIFTER)
	var real := _holds.hold_of(SURVIVOR)
	assert_bool(fake.is_empty()).is_equal(real.is_empty()) # the `holding` bit
	assert_bool(fake.is_empty()).is_false()
	assert_bool(fake.roots).is_equal(real.roots) # same pose: rooted alike


func test_non_fakeable_target_rejects_the_shapeshifters_start() -> void:
	var s := _stub(false)
	_step({SHIFTER: [_f(true, s.net_id)]})
	assert_array(s.log).is_equal(["eligible:%d" % SHIFTER])
	assert_dict(_holds.hold_of(SHIFTER)).is_empty()
