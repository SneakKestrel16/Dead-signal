extends GdUnitTestSuite
## BUG-0005 (match-flow.md rule 10 spectators; ADR-0002 rules 6-7; ADR-0004 §8): a spectator's own snapshot
## entry carries the watched survivor's state. OwnerPredictor must not replay or send the spectator's input
## on it, and SpectatorCamera puts the camera on the watched survivor's interpolated pose at eye height.

const OWN_ID := 1
const WATCHED := 7
const OTHER := 9
const EYE_M := 1.6
const TICKS := 30

var _knobs: Knobs
var _world: Node3D
var _body: CharacterBody3D
var _visual: Node3D
var _steps := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_world = auto_free(Node3D.new())
	add_child(_world)
	_body = TestMoveStep.make_body(_world, Vector3.ZERO)
	_visual = Node3D.new()
	_body.add_child(_visual)
	_steps = 0


func _counting_step(body: CharacterBody3D, frame: InputFrame, mods: MovementModifiers) -> void:
	_steps += 1
	TestMoveStep.apply(body, frame, mods)


func _snap(tick: int, id: int, pos: Vector3, yaw: float = 0.0) -> Dictionary:
	var own: Array[Dictionary] = [{"own": true, "id": id, "gait": 0, "pos": pos, "yaw": yaw, "on_floor": true,
			"seq": 0, "vel": Vector3.ZERO, "scale": 1.0, "restores": 0}]
	return SnapshotCodec.decode(SnapshotCodec.encode(tick, own))


func _forward() -> InputFrame:
	var f := InputFrame.new()
	f.move = Vector2(0.0, -1.0)
	return f


func _predictor() -> OwnerPredictor:
	var p := OwnerPredictor.new(_knobs, _body, _visual, _counting_step, null)
	p.own_id = OWN_ID
	return p


# --- OwnerPredictor ---

func test_spectating_predictor_holds_the_watched_position_and_steps_nothing() -> void:
	var p := _predictor()
	var at := Vector3(4.0, 2.0, -3.0) # in the air: a replayed step would let it fall
	p.apply_snapshot(_snap(10, WATCHED, at))
	for i in TICKS:
		p.predict(_forward())
	assert_bool(p.spectating()).is_true()
	assert_int(_steps).is_equal(0)
	assert_int(p.unacked_count()).is_equal(0)
	assert_vector(_body.global_position).is_equal(at)
	assert_int(p.local_tick()).is_equal(TICKS) # the tick estimate keeps running for the HUD clock


func test_spectating_snapshot_drops_unacked_frames_and_does_not_replay() -> void:
	var p := _predictor()
	p.apply_snapshot(_snap(10, OWN_ID, Vector3.ZERO))
	for i in 5:
		p.predict(_forward())
	assert_int(p.unacked_count()).is_equal(5)
	_steps = 0
	var at := Vector3(10.0, 3.0, 0.0)
	p.apply_snapshot(_snap(11, WATCHED, at))
	assert_int(_steps).is_equal(0)
	assert_int(p.unacked_count()).is_equal(0)
	assert_vector(_body.global_position).is_equal(at)


func test_own_entry_keeps_predicting() -> void:
	var p := _predictor()
	p.apply_snapshot(_snap(10, OWN_ID, Vector3.ZERO))
	for i in 3:
		p.predict(_forward())
	assert_bool(p.spectating()).is_false()
	assert_int(_steps).is_equal(3)
	assert_int(p.unacked_count()).is_equal(3)


func test_unknown_own_id_is_not_spectating() -> void:
	var p := OwnerPredictor.new(_knobs, _body, _visual, _counting_step, null)
	p.apply_snapshot(_snap(10, WATCHED, Vector3.ZERO))
	assert_bool(p.spectating()).is_false()


# --- SpectatorCamera ---

func _head() -> Node3D:
	var head := Node3D.new()
	head.position.y = EYE_M
	_visual.add_child(head)
	return head


func test_camera_sits_on_the_interpolated_watched_body_at_eye_height() -> void:
	var cam := SpectatorCamera.new(OWN_ID)
	var head := _head()
	cam.on_own(_snap(1, WATCHED, Vector3(0.0, 0.0, 0.0), 0.0).bodies[0], 0.0)
	cam.on_own(_snap(2, WATCHED, Vector3(2.0, 0.0, 4.0), 1.0).bodies[0], 100.0)
	assert_bool(cam.place(head, EYE_M, 50.0, 100.0)).is_true()
	assert_vector(head.global_position).is_equal_approx(Vector3(1.0, EYE_M, 2.0), Vector3.ONE * 0.001)
	assert_float(head.global_rotation.y).is_equal_approx(0.5, 0.001)
	assert_int(cam.watched()).is_equal(WATCHED)


func test_switching_the_watched_survivor_does_not_sweep_across_the_map() -> void:
	var cam := SpectatorCamera.new(OWN_ID)
	var head := _head()
	cam.on_own(_snap(1, WATCHED, Vector3.ZERO).bodies[0], 0.0)
	cam.on_own(_snap(2, OTHER, Vector3(40.0, 0.0, 0.0)).bodies[0], 100.0)
	assert_bool(cam.place(head, EYE_M, 50.0, 100.0)).is_true()
	assert_vector(head.global_position).is_equal_approx(Vector3(40.0, EYE_M, 0.0), Vector3.ONE * 0.001)


func test_own_entry_leaves_the_camera_on_the_own_body() -> void:
	var cam := SpectatorCamera.new(OWN_ID)
	var head := _head()
	_body.global_position = Vector3(3.0, 0.0, 0.0)
	cam.on_own(_snap(1, OWN_ID, Vector3(20.0, 0.0, 0.0)).bodies[0], 0.0)
	assert_bool(cam.place(head, EYE_M, 50.0, 100.0)).is_false()
	assert_int(cam.watched()).is_equal(-1)
	assert_vector(head.global_position).is_equal_approx(Vector3(3.0, EYE_M, 0.0), Vector3.ONE * 0.001)
