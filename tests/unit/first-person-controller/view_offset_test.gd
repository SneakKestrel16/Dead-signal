# Story controller-interaction/013: flinch view offset (ADR-0015 §1-4, first-person-controller.md rule 7).
extends GdUnitTestSuite

const PID := 0
const EPS := 0.0001

var _knobs: Knobs
var _net: NetAuthority
var _runner: TickRunner
var _bus: EventBus
var _sm: ServerMovement
var _offset: ViewOffset
var _view: ViewState
var _saved_hz: int
var _seq := 0
var _wind_up := false
## Every ViewOffsetChanged record the server sent, in order.
var _sent: Array[FlinchRecord] = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_saved_hz = Engine.physics_ticks_per_second
	_net = NetAuthority.new()
	_net.setup(_knobs, "test", null)
	_bus = EventBus.new(_knobs.core.max_flush_rounds)
	_runner = TickRunner.new()
	_runner.fail_hard = false
	_runner.boot(_knobs)
	_runner.bus = _bus
	_sm = ServerMovement.new(_knobs, _net, SceneMultiplayer.new(), func(_b: Node, _f: InputFrame, _m: MovementModifiers) -> void: pass, PhysicsLayers.WORLD)
	_sm.attach(_runner)
	_sm.add_player(PID, auto_free(CharacterBody3D.new()), true)
	_offset = ViewOffset.new(_in_wind_up)
	_offset.setup(_runner, _bus, null, _knobs)
	_bus.subscribe(&"ViewOffsetChanged", _on_changed)
	_view = ViewState.new(_sm, _offset)
	_seq = 0
	_wind_up = false
	_sent.clear()


func after_test() -> void:
	_sm.detach()
	_runner.free()
	_net.free()
	Engine.physics_ticks_per_second = _saved_hz


func _in_wind_up(_player: int) -> bool:
	return _wind_up


func _on_changed(e: ServerEvent) -> void:
	_sent.append((e as EvViewOffsetChanged).record)


## One server tick; the frame is stamped like a client that has seen every record the server sent.
func _send(yaw: float, pitch: float, record_id := -1) -> void:
	_seq += 1
	var f := InputFrame.new()
	f.seq = _seq
	f.yaw = yaw
	f.pitch = pitch
	f.record_id = record_id if record_id >= 0 else (_sent.back().record_id if not _sent.is_empty() else 0)
	f.offset_tick = _runner.current_tick() + 1
	_sm.push_local(PID, f)
	_runner.step()


func _flinch(target: Vector2) -> void:
	var e := EvFlinchRequested.new()
	e.player = PID
	e.target = target
	_bus.emit(e)


func _ramp_ticks() -> int:
	return roundi(_knobs.scare.scare_max_control_loss_s * _knobs.net.sim_tick_hz)


func _max_angle() -> float:
	return deg_to_rad(_knobs.scare.flinch_max_angle_deg)


func test_offset_at_ramps_with_float_ticks_and_guards_zero_ramp() -> void:
	var r := FlinchRecord.new()
	r.target = Vector2(0.1, -0.05)
	r.start_tick = 10
	r.ramp_ticks = 18
	assert_vector(FlinchRecord.offset_at(r, 10.0)).is_equal(Vector2.ZERO)
	assert_vector(FlinchRecord.offset_at(r, 19.0)).is_equal_approx(r.target * 0.5, Vector2.ONE * EPS)
	assert_float(FlinchRecord.offset_at(r, 11.0).x).is_greater(0.0)
	assert_float(FlinchRecord.offset_at(r, 11.0).x).is_less(FlinchRecord.offset_at(r, 11.5).x)
	assert_vector(FlinchRecord.offset_at(r, 28.0)).is_equal(r.target)
	assert_vector(FlinchRecord.offset_at(r, 99.0)).is_equal(r.target)
	r.ramp_ticks = 0
	assert_vector(FlinchRecord.offset_at(r, 10.0)).is_equal(r.from)


func test_flinch_reaches_target_within_ramp_and_holds() -> void:
	var target := Vector2(_max_angle() * 0.5, -_max_angle() * 0.3)
	_send(0.2, 0.1)
	_flinch(target)
	_send(0.2, 0.1)
	var start: int = _sent.back().start_tick
	while _runner.current_tick() < start + _ramp_ticks():
		_send(0.2, 0.1)
	assert_int(_runner.current_tick() - start).is_less_equal(roundi(0.3 * _knobs.net.sim_tick_hz))
	for i in 5:
		assert_vector(_view.server_dir(PID)).is_equal_approx(ViewState.direction(0.2 + target.x, 0.1 + target.y), Vector3.ONE * EPS)
		_send(0.2, 0.1)


func test_toggled_off_player_never_moves() -> void:
	_offset.set_flinch_enabled(PID, false)
	_send(0.2, 0.1)
	_flinch(Vector2(0.1, 0.1))
	for i in _ramp_ticks() + 3:
		_send(0.2, 0.1)
		assert_vector(_view.server_dir(PID)).is_equal_approx(ViewState.direction(0.2, 0.1), Vector3.ONE * EPS)


func test_no_flinch_starts_during_wind_up() -> void:
	_wind_up = true
	_send(0.0, 0.0)
	_flinch(Vector2(0.1, 0.1))
	for i in _ramp_ticks() + 3:
		_send(0.0, 0.0)
	assert_vector(_offset.offset_of(PID)).is_equal(Vector2.ZERO)
	assert_array(_sent).is_empty()


func test_second_flinch_replaces_and_caps_total_rotation() -> void:
	var cap := _max_angle()
	_send(0.0, 0.0)
	_flinch(Vector2(cap, 0.0))
	for i in _ramp_ticks() + 2:
		_send(0.0, 0.0)
	assert_vector(_offset.offset_of(PID)).is_equal_approx(Vector2(cap, 0.0), Vector2.ONE * EPS)
	_flinch(Vector2(-cap * 3.0, 0.0))
	for i in _ramp_ticks() + 2:
		_send(0.0, 0.0)
	var held := _offset.offset_of(PID)
	assert_float(held.length()).is_less_equal(cap + EPS)
	assert_float((held - Vector2(cap, 0.0)).length()).is_less_equal(cap + EPS)
	assert_float(held.x).is_less(cap) ## moved toward the new target: replaced, not summed
	assert_vector(_sent.back().from).is_equal_approx(Vector2(cap, 0.0), Vector2.ONE * EPS)


func test_same_flinch_twice_does_not_sum() -> void:
	var t := Vector2(_max_angle() * 0.6, 0.0)
	_send(0.0, 0.0)
	_flinch(t)
	for i in _ramp_ticks() + 2:
		_send(0.0, 0.0)
	_flinch(t)
	for i in _ramp_ticks() + 2:
		_send(0.0, 0.0)
	assert_vector(_offset.offset_of(PID)).is_equal_approx(t, Vector2.ONE * EPS)


func test_wind_up_freezes_a_running_flinch() -> void:
	_send(0.0, 0.0)
	_flinch(Vector2(_max_angle(), 0.0))
	for i in _ramp_ticks() / 2:
		_send(0.0, 0.0)
	_wind_up = true
	var e := EvAbilityUsed.new()
	_bus.emit(e)
	_send(0.0, 0.0)
	var frozen := _offset.offset_of(PID)
	assert_float(frozen.x).is_greater(0.0)
	assert_float(frozen.x).is_less(_max_angle())
	for i in _ramp_ticks():
		_send(0.0, 0.0)
	assert_vector(_offset.offset_of(PID)).is_equal(frozen)


## Each reset: offset 0, and the view direction on that tick (frame still on the old record) unchanged.
func test_resets_rebaseline_without_a_snap() -> void:
	for reset in ["round_end", "downed", "hidden", "toggle_off"]:
		after_test() ## a fresh fixture per reset kind; gdUnit's own after_test frees the last one
		before_test()
		_send(0.3, 0.0)
		_flinch(Vector2(0.1, 0.05))
		for i in _ramp_ticks() + 2:
			_send(0.3, 0.0)
		var before := _view.server_dir(PID)
		var old_id: int = _sent.back().record_id
		match reset:
			"round_end": _bus.emit(EvRoundEnded.new())
			"downed":
				var d := EvSurvivorDowned.new()
				d.survivor = PID
				_bus.emit(d)
			"hidden": _offset.rebaseline(PID)
			"toggle_off": _offset.set_flinch_enabled(PID, false)
		_send(0.3, 0.0, old_id)
		assert_vector(_offset.offset_of(PID)).override_failure_message(reset).is_equal(Vector2.ZERO)
		assert_vector(_view.server_dir(PID)).override_failure_message(reset).is_equal_approx(before, Vector3.ONE * EPS)
		var rb: FlinchRecord = _sent.back()
		assert_bool(rb.rebaseline).override_failure_message(reset).is_true()
		# The owner folds the held offset into yaw/pitch and stamps the new record: still no snap.
		_send(0.3 + rb.fold.x, rb.fold.y)
		assert_vector(_view.server_dir(PID)).override_failure_message(reset).is_equal_approx(before, Vector3.ONE * EPS)


func test_reconnect_starts_fresh_and_agrees_on_first_tick() -> void:
	_send(0.0, 0.0)
	_flinch(Vector2(0.1, 0.0))
	for i in _ramp_ticks() + 2:
		_send(0.0, 0.0)
	var c := EvPlayerConnectionChanged.new()
	c.player = PID
	c.status = EvPlayerConnectionChanged.RECONNECTED
	_bus.emit(c)
	_send(0.5, 0.2, 0) ## a fresh client: record 0, nothing folded
	assert_vector(_view.server_dir(PID)).is_equal_approx(ViewState.direction(0.5, 0.2), Vector3.ONE * EPS)


func test_pitch_clamp_applies_to_the_sum() -> void:
	_send(0.0, ViewState.PITCH_LIMIT)
	_flinch(Vector2(0.0, _max_angle()))
	for i in _ramp_ticks() + 2:
		_send(0.0, ViewState.PITCH_LIMIT)
	assert_float(_view.pitch_of(PID)).is_equal_approx(ViewState.PITCH_LIMIT, EPS)


func test_input_packet_carries_record_and_offset_tick() -> void:
	var f := InputFrame.new()
	f.seq = 1
	f.record_id = 7
	f.offset_tick = 1234
	var q := InputQueue.new(_knobs, true)
	q.push(InputFrame.build_packet([f]))
	var got := q.next(1)
	assert_int(got.record_id).is_equal(7)
	assert_int(got.offset_tick).is_equal(1234)
