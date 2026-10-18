# Audio pass 2 (entity-inventory.md Audio rows 3, 14, 15, 18, 25): BodySfx turns each body's snapshot action
# into the takedown struggle, the release gasp after a stun, and the interact, barricade and rescue loops.
extends GdUnitTestSuite

const A := Vector3(1, 0, 1)
const B := Vector3(5, 0, 5)

var _sfx: BodySfx
var _ids: Array = []


func before_test() -> void:
	_ids = []
	var play := func(id: StringName, at: Vector3) -> void:
		_ids.append([id, at])
	_sfx = auto_free(BodySfx.new(SoundBank.new(), play))


func test_seizing_struggles_once_and_a_stun_release_gasps() -> void:
	var act := SnapshotCodec.Action
	_sfx.update(0.016, [[1, A, act.NONE]])
	_sfx.update(0.016, [[1, A, act.SEIZED]])
	_sfx.update(0.016, [[1, A, act.SEIZED]])
	_sfx.on_stunned(1, {"body": 9})
	_sfx.update(0.5, [[1, A, act.NONE]])
	assert_array(_ids).is_equal([[BodySfx.STRUGGLE, A], [BodySfx.GASP, A]])


func test_a_takedown_that_completes_does_not_gasp() -> void:
	var act := SnapshotCodec.Action
	_sfx.update(0.016, [[1, A, act.SEIZED]])
	_sfx.on_stunned(1, {"body": 9})
	_sfx.update(2.0, [[1, A, act.SEIZED]]) ## the window passes while still held
	_sfx.update(0.016, [[1, A, act.NONE]])
	assert_array(_ids).is_equal([[BodySfx.STRUGGLE, A]])


func test_loops_follow_each_bodys_action_and_stop_when_it_leaves() -> void:
	var act := SnapshotCodec.Action
	_sfx.update(0.016, [[1, A, act.INTERACT], [2, B, act.KNEEL]])
	assert_dict(_sfx.looping).is_equal({1: &"interact_loop", 2: &"rescue_loop"})
	_sfx.update(0.016, [[1, A, act.BARRICADE]])
	assert_dict(_sfx.looping).is_equal({1: &"barricade_loop"})
	_sfx.update(0.016, [[1, A, act.NONE]])
	assert_dict(_sfx.looping).is_empty()
