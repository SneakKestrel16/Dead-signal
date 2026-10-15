# Story controller-interaction/013: flinch view offset (ADR-0015 §1-4, first-person-controller.md rule 7).
extends GdUnitTestSuite

const PID := 0
const EPS := 0.0001
## More records than ViewOffset keeps per player.
const HISTORY_PLUS := ViewOffset.HISTORY + 1

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


## One server tick. The frame is stamped with `rec` (its record id and view epoch), or, when null, like
## a client that has seen every record the server sent.
func _send(yaw: float, pitch: float, rec: FlinchRecord = null) -> void:
	_seq += 1
	var f := InputFrame.new()
	f.seq = _seq
	f.yaw = yaw
	f.pitch = pitch
	if rec == null and not _sent.is_empty():
		rec = _sent.back()
	if rec != null:
		f.record_id = rec.record_id
		f.view_epoch = rec.view_epoch
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
		var old: FlinchRecord = _sent.back()
		match reset:
			"round_end": _bus.emit(EvRoundEnded.new())
			"downed":
				var d := EvSurvivorDowned.new()
				d.survivor = PID
				_bus.emit(d)
			"hidden": _offset.rebaseline(PID)
			"toggle_off": _offset.set_flinch_enabled(PID, false)
		_send(0.3, 0.0, old)
		assert_vector(_offset.offset_of(PID)).override_failure_message(reset).is_equal(Vector2.ZERO)
		assert_vector(_view.server_dir(PID)).override_failure_message(reset).is_equal_approx(before, Vector3.ONE * EPS)
		var rb: FlinchRecord = _sent.back()
		assert_bool(rb.rebaseline).override_failure_message(reset).is_true()
		assert_int(rb.view_epoch).override_failure_message(reset).is_not_equal(old.view_epoch)
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
	_send(0.5, 0.2, FlinchRecord.new()) ## a fresh client: record 0, epoch 0, nothing folded
	assert_vector(_view.server_dir(PID)).is_equal_approx(ViewState.direction(0.5, 0.2), Vector3.ONE * EPS)


## A reconnect after a re-baseline moved the epoch on: the fresh client still stamps epoch 0 and record 0,
## and the server takes them as current, so the two agree on the first tick. The server tells the owner
## so with a record of its own (epoch 0, record 0) carrying the held offset, never a silent zero.
func test_reconnect_after_an_epoch_change_agrees_on_first_tick() -> void:
	_send(0.0, 0.0)
	_flinch(Vector2(0.1, 0.0))
	for i in _ramp_ticks() + 2:
		_send(0.0, 0.0)
	_offset.rebaseline(PID) ## epoch 1
	_send(0.1, 0.0)
	for k in HISTORY_PLUS: ## enough replacing flinches that record 0 leaves the server's history
		_flinch(Vector2(0.02 * (k + 1), 0.02))
		for i in _ramp_ticks() + 2:
			_send(0.1, 0.0)
	var held := _offset.offset_of(PID)
	var c := EvPlayerConnectionChanged.new()
	c.player = PID
	c.status = EvPlayerConnectionChanged.RECONNECTED
	_bus.emit(c)
	_send(0.5, 0.2, FlinchRecord.new()) ## the fresh client's first frame
	assert_vector(_view.server_dir(PID)).is_equal_approx(ViewState.direction(0.5, 0.2), Vector3.ONE * EPS)
	var r: FlinchRecord = _sent.back()
	assert_bool(r.rebaseline).is_true()
	assert_int(r.view_epoch).is_equal(0)
	assert_int(r.record_id).is_equal(0)
	assert_vector(r.fold).is_equal_approx(held, Vector2.ONE * EPS)


## The toggle is a session setting: a reconnect keeps it off.
func test_reconnect_keeps_the_toggle() -> void:
	_offset.set_flinch_enabled(PID, false)
	var c := EvPlayerConnectionChanged.new()
	c.player = PID
	c.status = EvPlayerConnectionChanged.RECONNECTED
	_bus.emit(c)
	_send(0.0, 0.0)
	_flinch(Vector2(0.1, 0.0))
	for i in _ramp_ticks() + 2:
		_send(0.0, 0.0)
	assert_vector(_offset.offset_of(PID)).is_equal(Vector2.ZERO)


## A reset mid-ramp: frames the owner sampled before it learned of the re-baseline still carry the old
## epoch. Each keeps its own ramp value up to the reset tick and the held offset after it, so the server
## view never snaps to zero and never ramps on past the reset. After the fold it is the same direction.
func test_old_epoch_frames_get_the_held_offset_during_a_rebaseline() -> void:
	_send(0.2, 0.0)
	_flinch(Vector2(_max_angle(), 0.0))
	_send(0.2, 0.0)
	var flinch: FlinchRecord = _sent.back()
	for i in _ramp_ticks() / 3:
		_send(0.2, 0.0)
	_offset.rebaseline(PID)
	_send(0.2, 0.0, flinch) ## the bus delivers the re-baseline in this tick
	var rb: FlinchRecord = _sent.back()
	var held := rb.fold
	assert_float(held.x).is_greater(0.0)
	assert_float(held.x).is_less(_max_angle())
	var want := ViewState.direction(0.2 + held.x, held.y)
	assert_vector(_view.server_dir(PID)).is_equal_approx(want, Vector3.ONE * EPS)
	for i in _ramp_ticks(): ## one round trip and more on the old epoch: the held offset, no ramp
		_send(0.2, 0.0, flinch)
		assert_vector(_view.server_dir(PID)).override_failure_message("old-epoch tick %d" % i).is_equal_approx(want, Vector3.ONE * EPS)
	_send(0.2 + held.x, held.y, rb) ## folded: new epoch, zero record
	assert_vector(_view.server_dir(PID)).is_equal_approx(want, Vector3.ONE * EPS)
	assert_vector(_offset.offset_of(PID)).is_equal(Vector2.ZERO)


## A frame sampled before the reset tick, arriving after it, is evaluated at its own tick, not the held one.
func test_old_epoch_frame_before_the_reset_keeps_its_own_tick() -> void:
	_send(0.0, 0.0)
	_flinch(Vector2(_max_angle(), 0.0))
	_send(0.0, 0.0)
	var flinch: FlinchRecord = _sent.back()
	for i in _ramp_ticks() / 2:
		_send(0.0, 0.0)
	var sampled := _runner.current_tick() - 2
	_offset.rebaseline(PID)
	_send(0.0, 0.0, flinch)
	var f := InputFrame.new()
	f.record_id = flinch.record_id
	f.view_epoch = flinch.view_epoch
	f.offset_tick = sampled
	assert_vector(_offset.offset_for(PID, f)).is_equal_approx(FlinchRecord.offset_at(flinch, float(sampled)), Vector2.ONE * EPS)
	assert_float(_offset.offset_for(PID, f).x).is_less(_sent.back().fold.x)


## Two resets before the owner folds the first, with a flinch ramping in the middle epoch: each epoch
## keeps its own base, and a frame in any of the three gives the direction the owner saw.
func test_second_reset_during_a_handshake() -> void:
	_send(0.2, 0.0)
	_flinch(Vector2(0.1, 0.0))
	_send(0.2, 0.0)
	var flinch: FlinchRecord = _sent.back()
	for i in _ramp_ticks() + 2:
		_send(0.2, 0.0)
	var want := _view.server_dir(PID)
	_offset.rebaseline(PID)
	_flinch(Vector2(0.05, 0.0))
	_send(0.2, 0.0, flinch)
	var rb1: FlinchRecord = _sent[_sent.size() - 2]
	var flinch2: FlinchRecord = _sent.back()
	assert_bool(rb1.rebaseline).is_true()
	for i in 3:
		_send(0.2, 0.0, flinch)
	_offset.rebaseline(PID)
	_send(0.2, 0.0, flinch) ## still the oldest epoch
	assert_vector(_view.server_dir(PID)).is_equal_approx(want, Vector3.ONE * EPS)
	var rb2: FlinchRecord = _sent.back()
	assert_int(rb2.view_epoch).is_not_equal(rb1.view_epoch)
	assert_float(rb2.fold.x).is_greater(0.0)
	var want2 := ViewState.direction(0.2 + rb1.fold.x + rb2.fold.x, 0.0)
	_send(0.2 + rb1.fold.x, 0.0, flinch2) ## folded the first, rendering the second flinch: held at the reset
	assert_vector(_view.server_dir(PID)).is_equal_approx(want2, Vector3.ONE * EPS)
	_send(0.2 + rb1.fold.x + rb2.fold.x, 0.0, rb2) ## folded both
	assert_vector(_view.server_dir(PID)).is_equal_approx(want2, Vector3.ONE * EPS)


## A forged or long-gone epoch is read as the current one; it never reaches another epoch's base.
func test_unknown_epoch_reads_as_current() -> void:
	_send(0.0, 0.0)
	_flinch(Vector2(0.1, 0.0))
	for i in _ramp_ticks() + 2:
		_send(0.0, 0.0)
	var f := InputFrame.new()
	f.view_epoch = 200
	f.record_id = 99
	f.offset_tick = _runner.current_tick()
	assert_vector(_offset.offset_for(PID, f)).is_equal(_offset.offset_of(PID))


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
	f.view_epoch = 3
	var q := InputQueue.new(_knobs, true)
	q.push(InputFrame.build_packet([f]))
	var got := q.next(1)
	assert_int(got.record_id).is_equal(7)
	assert_int(got.offset_tick).is_equal(1234)
	assert_int(got.view_epoch).is_equal(3)


# --- Owner client: fold and stamping (LocalInput, ADR-0015 §2-3) ---

## Records in flight to the client: [deliver_at_tick, payload].
var _inbox: Array = []


func _queue_for_client(e: ServerEvent, delay: int) -> void:
	var v := e as EvViewOffsetChanged
	_inbox.append([_runner.current_tick() + delay, v.project(v.player, null, -1)])


## One tick of an owner client whose ViewOffsetChanged arrives `delay` ticks late and whose tick estimate
## is exact: deliver what is due, sample (stamped by LocalInput), let the server consume it, then return
## the server view direction minus the client's rendered one at that tick, in radians.
func _client_tick(li: LocalInput) -> float:
	var due := _runner.current_tick() + 1
	while not _inbox.is_empty() and _inbox[0][0] <= due:
		li.on_view_offset(due, _inbox.pop_front()[1])
	var f := li.sample(due)
	_seq += 1
	f.seq = _seq
	_sm.push_local(PID, f)
	_runner.step()
	return _view.server_dir(PID).angle_to(ViewState.direction(li.view_yaw(float(due)), li.view_pitch(float(due))))


func _owner(delay: int) -> LocalInput:
	_inbox.clear()
	_bus.subscribe(&"ViewOffsetChanged", _queue_for_client.bind(delay))
	var li: LocalInput = auto_free(LocalInput.new())
	li.yaw = 0.4
	li.pitch = 0.1
	return li


## ADR-0015 Validation: a flinch, a replacing flinch while the first ramps, and then a reset keep the
## server and owner view direction equal on every tick, with records 3 ticks late. The reset comes after
## the ramp: a record arriving mid-ramp is the small pop the ADR accepts.
func test_owner_and_server_agree_every_tick_through_flinch_replace_and_reset() -> void:
	var li := _owner(3)
	_client_tick(li)
	_flinch(Vector2(_max_angle() * 0.8, 0.0))
	var worst := 0.0
	for i in _ramp_ticks() / 2:
		worst = maxf(worst, _client_tick(li))
		li.look(Vector2(3, -1)) ## the player keeps moving the mouse
	_flinch(Vector2(-_max_angle() * 0.5, _max_angle() * 0.3))
	for i in _ramp_ticks() + 6:
		worst = maxf(worst, _client_tick(li))
	_offset.rebaseline(PID)
	for i in 10:
		worst = maxf(worst, _client_tick(li))
		li.look(Vector2(-2, 1))
	assert_float(worst).is_less(EPS)
	assert_int(li.view_epoch()).is_equal(_sent.back().view_epoch)
	assert_vector(li.view_offset(float(_runner.current_tick()))).is_equal(Vector2.ZERO)


## The fold keeps the rendered view where it was: yaw and pitch take the held offset, the offset goes to
## zero, and pitch is clamped on the sum, as the server clamps it.
func test_fold_moves_the_offset_into_yaw_and_pitch_without_a_snap() -> void:
	var li: LocalInput = auto_free(LocalInput.new())
	li.yaw = PI - 0.05
	li.pitch = ViewState.PITCH_LIMIT - 0.02
	var flinch := FlinchRecord.new()
	flinch.record_id = 1
	flinch.target = Vector2(0.1, 0.1)
	li.on_view_offset(0, flinch.to_dict())
	var before := ViewState.direction(li.view_yaw(50.0), li.view_pitch(50.0))
	var rb := FlinchRecord.new()
	rb.record_id = 2
	rb.view_epoch = 1
	rb.rebaseline = true
	rb.fold = flinch.target
	rb.start_tick = 50
	li.on_view_offset(50, rb.to_dict())
	assert_vector(ViewState.direction(li.view_yaw(50.0), li.view_pitch(50.0))).is_equal_approx(before, Vector3.ONE * EPS)
	assert_float(li.yaw).is_between(-PI, PI)
	assert_float(li.pitch).is_equal_approx(ViewState.PITCH_LIMIT, EPS)
	var f := li.sample(51)
	assert_int(f.record_id).is_equal(2)
	assert_int(f.view_epoch).is_equal(1)
	assert_int(f.offset_tick).is_equal(51)


## A fresh client (record 0) takes the server's reconnect record without folding: its yaw is its own and
## the server reads its frames with no offset. A malformed payload changes nothing.
func test_fresh_client_does_not_fold_the_reconnect_record_and_ignores_bad_payloads() -> void:
	var li: LocalInput = auto_free(LocalInput.new())
	li.yaw = 0.3
	var r := FlinchRecord.new()
	r.rebaseline = true
	r.fold = Vector2(0.1, 0.0)
	li.on_view_offset(5, r.to_dict())
	assert_float(li.yaw).is_equal(0.3)
	var bad := r.to_dict()
	bad.record_id = 9
	bad.fold = "x"
	li.on_view_offset(6, bad)
	li.on_view_offset(6, {})
	assert_float(li.yaw).is_equal(0.3)
	assert_int(li.sample().record_id).is_equal(0)


## Reconnect: a fresh owner and the server agree on the first tick and after.
func test_fresh_owner_after_reconnect_agrees_from_the_first_tick() -> void:
	_send(0.0, 0.0)
	_flinch(Vector2(0.1, 0.0))
	for i in _ramp_ticks() + 2:
		_send(0.0, 0.0)
	_offset.rebaseline(PID)
	_send(0.1, 0.0)
	var c := EvPlayerConnectionChanged.new()
	c.player = PID
	c.status = EvPlayerConnectionChanged.RECONNECTED
	_bus.emit(c)
	var li := _owner(3)
	var worst := 0.0
	for i in 8:
		worst = maxf(worst, _client_tick(li))
	assert_float(worst).is_less(EPS)


## Spectators (ADR-0015 §2): ServerMovement projects a spectator's event batch as the watched survivor,
## so the survivor's projection is what the spectator gets. A spectator that switches onto a survivor
## mid-hold gets the current record again through resend(); the owner, which already has it, keeps its
## view (same record id: no second fold, even for a re-baseline).
func test_resend_reaches_a_new_spectator_and_leaves_the_owner_unchanged() -> void:
	var li := _owner(0)
	_client_tick(li)
	_flinch(Vector2(0.1, 0.0))
	for i in _ramp_ticks() + 2:
		_client_tick(li)
	_offset.rebaseline(PID)
	_client_tick(li)
	var t := float(_runner.current_tick())
	var before := Vector2(li.view_yaw(t), li.view_pitch(t))
	var count := _sent.size()
	_offset.resend(PID)
	var worst := _client_tick(li)
	assert_int(_sent.size()).is_equal(count + 1)
	assert_bool(_sent.back().rebaseline).is_true()
	assert_float(worst).is_less(EPS)
	t = float(_runner.current_tick())
	assert_vector(Vector2(li.view_yaw(t), li.view_pitch(t))).is_equal_approx(before, Vector2.ONE * EPS)
	var e := EvViewOffsetChanged.new()
	e.player = PID
	e.record = _sent.back()
	var batch := EventBatch.decode(EventBatch.build(1, PID, [e] as Array[ServerEvent], [], Vector3.ZERO, null, -1))
	assert_array(batch.entries).is_equal([[&"ViewOffsetChanged", _sent.back().to_dict()]])
	var spectator := FlinchRecord.from_dict(batch.entries[0][1])
	assert_vector(FlinchRecord.offset_at(spectator, t)).is_equal(_offset.offset_of(PID))
