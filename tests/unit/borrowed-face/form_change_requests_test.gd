# Story borrowed-face/002: form-change request validation and target persistence
# (design/gdd/borrowed-face.md rules 5-6, 13, Edge Cases "Target ..." rows, Acceptance Criteria on
# requests and targets). Survivor status is a stub of MatchFlow.status_of; sight sources are stubs.
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const S2 := 3
const S3 := 4
const SURVIVORS: Array[int] = [2, 3, 4]
const EYE := Vector3(0.0, 1.6, 0.0)
## observe_time_s 3 s and transform_duration_s 2 s at 60 Hz (data/knobs/borrowed_face.tres, net.tres).
const OBSERVE_TICKS := 180
const TRANSFORM_TICKS := 120

var _server: RoundServer
var _bf: BorrowedFace
## survivor -> MatchFlow.Status; absent = HEALTHY
var _status: Dictionary[int, int] = {}
## survivor -> [head, chest, pelvis]; S3 has none, so it is never observed
var _points: Dictionary[int, PackedVector3Array] = {}


func before_test() -> void:
	_status = {}
	_points = {}
	for s in [S1, S2]:
		var chest := EYE + Vector3.FORWARD * 5.0
		_points[s] = PackedVector3Array([chest + Vector3.UP * 0.4, chest, chest + Vector3.DOWN * 0.3])


## Starts a round and observes S1 and S2 (S3 stays unobserved).
func _start() -> void:
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_bf = BorrowedFace.new()
	_bf.set_roster(SURVIVORS, MONSTER)
	_bf.set_sight_sources(_eye_of, _yaw_of, _points_of, _sight)
	_bf.set_status_source(_status_of)
	assert_array(_server.start_round({TickOrder.BORROWED_FACE: _bf}, Knobs.load_all())).is_empty()
	_step(OBSERVE_TICKS)
	assert_bool(_bf.observed(S1) and _bf.observed(S2)).is_true()
	assert_bool(_bf.observed(S3)).is_false()


func _eye_of(_p: int) -> Vector3:
	return EYE


func _yaw_of(_p: int) -> float:
	return 0.0


func _points_of(p: int) -> PackedVector3Array:
	return _points.get(p, PackedVector3Array())


func _sight(_eye: Vector3, _point: Vector3) -> bool:
	return true


func _status_of(p: int) -> int:
	return _status.get(p, MatchFlow.Status.HEALTHY)


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


func _request(form: int, sender: int = MONSTER) -> void:
	_bf.request_form_change(sender, BorrowedFace.request_packet(form))
	_step(1)


## Requests `form` and runs the whole transformation.
func _become(form: int) -> void:
	_request(form)
	assert_bool(_bf.transforming()).is_true()
	_step(TRANSFORM_TICKS)
	assert_int(_bf.form()).is_equal(form)


func test_round_starts_in_true_form() -> void:
	_start()
	assert_int(_bf.form()).is_equal(BorrowedFace.TRUE_FORM)
	assert_bool(_bf.transforming()).is_false()


func test_unobserved_survivor_is_rejected() -> void:
	_start()
	_request(S3)
	assert_bool(_bf.transforming()).is_false()
	assert_int(_bf.form()).is_equal(BorrowedFace.TRUE_FORM)


func test_observed_eliminated_escaped_or_disconnected_survivor_is_rejected() -> void:
	_start()
	for st: int in [MatchFlow.Status.ELIMINATED, MatchFlow.Status.ESCAPED, MatchFlow.Status.DISCONNECTED,
			MatchFlow.Status.DID_NOT_ESCAPE]:
		_status[S1] = st
		_request(S1)
		assert_bool(_bf.transforming()).override_failure_message("status %d accepted" % st).is_false()


func test_observed_downed_survivor_is_accepted() -> void:
	_start()
	_status[S1] = MatchFlow.Status.DOWNED
	_request(S1)
	assert_bool(_bf.transforming()).is_true()
	assert_int(_bf.transform_target()).is_equal(S1)


## AC: the first request of a round needs only an observed target (no cooldown wait).
func test_first_request_is_accepted_at_once_and_completes_into_the_target() -> void:
	_start()
	_request(S1)
	assert_bool(_bf.transforming()).is_true()
	assert_int(_bf.transform_target()).is_equal(S1)
	assert_int(_bf.form()).is_equal(BorrowedFace.TRUE_FORM)
	_step(TRANSFORM_TICKS - 1)
	assert_bool(_bf.transforming()).is_true()
	_step(1)
	assert_bool(_bf.transforming()).is_false()
	assert_int(_bf.form()).is_equal(S1)


## Rule 13 and Edge Cases: the disguise stays whatever happens to the copied survivor.
func test_disguise_stays_when_the_target_is_downed_eliminated_escapes_or_disconnects() -> void:
	_start()
	_become(S1)
	for st: int in [MatchFlow.Status.DOWNED, MatchFlow.Status.ELIMINATED, MatchFlow.Status.ESCAPED,
			MatchFlow.Status.DISCONNECTED]:
		_status[S1] = st
		_step(30)
		assert_int(_bf.form()).override_failure_message("status %d dropped it" % st).is_equal(S1)


## Edge Cases: the target was valid at request time, so the change completes.
func test_target_eliminated_or_disconnected_mid_transformation_still_completes() -> void:
	for st: int in [MatchFlow.Status.ELIMINATED, MatchFlow.Status.DISCONNECTED]:
		_status = {}
		_start()
		_request(S1)
		_step(TRANSFORM_TICKS / 2)
		_status[S1] = st
		_step(TRANSFORM_TICKS)
		assert_int(_bf.form()).override_failure_message("status %d" % st).is_equal(S1)
		_server.end_round()


func test_no_new_transform_into_a_target_that_left_while_worn() -> void:
	_start()
	_become(S1)
	_become(S2)
	_status[S1] = MatchFlow.Status.ESCAPED
	_request(S1)
	assert_bool(_bf.transforming()).is_false()
	assert_int(_bf.form()).is_equal(S2)


func test_true_form_request_is_accepted_while_disguised() -> void:
	_start()
	_become(S1)
	_become(BorrowedFace.TRUE_FORM)


func test_request_into_the_current_form_is_rejected() -> void:
	_start()
	_request(BorrowedFace.TRUE_FORM)
	assert_bool(_bf.transforming()).is_false()
	_become(S1)
	_request(S1)
	assert_bool(_bf.transforming()).is_false()


func test_request_while_transforming_is_rejected() -> void:
	_start()
	_request(S1)
	_request(S2)
	assert_int(_bf.transform_target()).is_equal(S1)
	_step(TRANSFORM_TICKS)
	assert_int(_bf.form()).is_equal(S1)


func test_request_from_a_survivor_is_ignored() -> void:
	_start()
	_request(S2, S1)
	assert_bool(_bf.transforming()).is_false()


## Only the first request of a tick is kept; later ones that tick are dropped.
func test_one_request_per_tick() -> void:
	_start()
	_bf.request_form_change(MONSTER, BorrowedFace.request_packet(S3)) # unobserved: rejected
	_bf.request_form_change(MONSTER, BorrowedFace.request_packet(S1))
	_step(1)
	assert_bool(_bf.transforming()).is_false()


## Untrusted client bytes: oversize, garbage, wrong shape, wrong type and unknown ids do nothing.
func test_malformed_or_hostile_requests_are_rejected() -> void:
	_start()
	var big := BorrowedFace.request_packet(S1) # valid request padded past the cap
	big.resize(BorrowedFace.REQUEST_CAP_BYTES + 1)
	var bad: Array[PackedByteArray] = [
		big,
		PackedByteArray(),
		PackedByteArray([0xff, 0xff, 0xff, 0xff, 1, 2, 3]),
		var_to_bytes({"form": float(S1)}),
		var_to_bytes({"form": S1, "x": 1}),
		var_to_bytes({"face": S1}),
		var_to_bytes([S1]),
		var_to_bytes(S1),
		BorrowedFace.request_packet(MONSTER),
		BorrowedFace.request_packet(99),
		BorrowedFace.request_packet(-7),
	]
	for b in bad:
		_bf.request_form_change(MONSTER, b)
		_step(1)
		assert_bool(_bf.transforming()).override_failure_message("accepted %s" % b).is_false()
	assert_int(BorrowedFace.decode_request(big)).is_equal(BorrowedFace.INVALID_FORM)
	assert_int(BorrowedFace.decode_request(BorrowedFace.request_packet(S1))).is_equal(S1)
