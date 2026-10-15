# Story network-authority/005: InputFrame and the server InputQueue.
extends GdUnitTestSuite

const HZ := 60
const WINDOW_TICKS := 120 ## starvation_window_s 2.0 at 60 Hz
const TIMEOUT_TICKS := 30 ## intent_timeout_ms 500 at 60 Hz
const CAP := 8
const MAX_AHEAD := 16


func _knobs() -> Knobs:
	var k := Knobs.new()
	k.net = NetKnobs.new()
	k.controller = ControllerKnobs.new()
	k.net.sim_tick_hz = HZ
	k.net.starvation_window_s = 2.0
	k.net.input_queue_cap = CAP
	k.net.max_seq_ahead = MAX_AHEAD
	k.net.starvation_high = 0.10
	k.net.starvation_low = 0.02
	k.controller.intent_timeout_ms = 500
	return k


func _frame(seq: int, move := Vector2.ZERO, yaw := 0.0, pitch := 0.0) -> InputFrame:
	var f := InputFrame.new()
	f.seq = seq
	f.move = move
	f.yaw = yaw
	f.pitch = pitch
	return f


## Packet of default frames with the given seq values.
func _packet(seqs: Array) -> Dictionary:
	var frames: Array[InputFrame] = []
	for s in seqs:
		frames.append(_frame(s))
	return InputFrame.build_packet(frames)


## Pushes one frame with `seq`; returns the count enqueued.
func _push1(q: InputQueue, seq: int) -> int:
	return q.push(_packet([seq]))


func _assert_dropped(q: InputQueue, packet: Dictionary) -> void:
	var size_before := q.size()
	var drops_before := q.dropped_packets
	assert_int(q.push(packet)).is_equal(0)
	assert_int(q.size()).is_equal(size_before)
	assert_int(q.dropped_packets).is_equal(drops_before + 1)
	assert_int(q.violations.size()).is_equal(drops_before + 1)


## Runs one window: every tick pushes a frame except the first `starved` ticks. Returns the next seq.
func _run_window(q: InputQueue, starved: int, seq: int, tick0: int) -> int:
	for t in WINDOW_TICKS:
		if t >= starved:
			_push1(q, seq)
			seq += 1
		q.next(tick0 + t)
	return seq


func test_valid_three_frame_packet_enqueues_only_new_seqs() -> void:
	var q := InputQueue.new(_knobs())
	assert_int(q.push(_packet([1, 2, 3]))).is_equal(3)
	assert_int(q.push(_packet([2, 3, 4]))).is_equal(1)
	assert_int(q.size()).is_equal(4)
	assert_int(q.dropped_packets).is_equal(0)


func test_mismatched_lengths_drop_whole_packet() -> void:
	var q := InputQueue.new(_knobs())
	_push1(q, 1)
	var p := _packet([2, 3])
	p["yaw"] = PackedFloat32Array([0.0])
	_assert_dropped(q, p)
	p = _packet([2, 3])
	p["flags"] = PackedByteArray([0, 0, 0])
	_assert_dropped(q, p)
	p = _packet([2, 3])
	p["view_tick"] = PackedFloat32Array([1.0])
	_assert_dropped(q, p)


func test_four_frames_drop_whole_packet() -> void:
	var q := InputQueue.new(_knobs())
	_assert_dropped(q, _packet([1, 2, 3, 4]))


func test_empty_packet_dropped_and_recorded() -> void:
	var q := InputQueue.new(_knobs())
	_assert_dropped(q, _packet([]))


func test_missing_key_or_wrong_type_dropped() -> void:
	var q := InputQueue.new(_knobs())
	var p := _packet([1])
	p.erase("pitch")
	_assert_dropped(q, p)
	p = _packet([1])
	p["seq"] = [1]
	_assert_dropped(q, p)


func test_nan_and_inf_anywhere_drop_whole_packet() -> void:
	var q := InputQueue.new(_knobs())
	var p := _packet([1, 2])
	p["move"] = PackedVector2Array([Vector2.ZERO, Vector2(NAN, 0.0)])
	_assert_dropped(q, p)
	p = _packet([1, 2])
	p["move"] = PackedVector2Array([Vector2(0.0, INF), Vector2.ZERO])
	_assert_dropped(q, p)
	p = _packet([1, 2])
	p["yaw"] = PackedFloat32Array([0.0, INF])
	_assert_dropped(q, p)
	p = _packet([1, 2])
	p["pitch"] = PackedFloat32Array([-INF, 0.0])
	_assert_dropped(q, p)
	p = _packet([1, 2])
	p["pitch"] = PackedFloat32Array([0.0, NAN])
	_assert_dropped(q, p)
	assert_int(q.size()).is_equal(0)


func test_seq_beyond_max_seq_ahead_drops_whole_packet() -> void:
	var q := InputQueue.new(_knobs())
	_push1(q, 0)
	q.next(1) # last consumed seq = 0, so 16 is the last accepted
	assert_int(q.push(_packet([15, 16, 17]))).is_equal(0)
	assert_int(q.dropped_packets).is_equal(1)
	assert_int(q.size()).is_equal(0)


func test_seq_exactly_at_max_seq_ahead_accepted() -> void:
	var q := InputQueue.new(_knobs())
	_push1(q, 0)
	q.next(1)
	assert_int(_push1(q, MAX_AHEAD)).is_equal(1)
	assert_int(q.dropped_packets).is_equal(0)


func test_seq_window_grows_with_silent_ticks_so_a_stall_recovers() -> void:
	var q := InputQueue.new(_knobs())
	_push1(q, 0)
	q.next(1)
	for t in 20: # 20 empty ticks: the client kept counting seq meanwhile
		q.next(2 + t)
	assert_int(_push1(q, 20 + MAX_AHEAD)).is_equal(1)
	assert_int(_push1(q, 20 + MAX_AHEAD + 2)).is_equal(0)


func test_duplicate_seq_dropped() -> void:
	var q := InputQueue.new(_knobs())
	_push1(q, 5)
	assert_int(_push1(q, 5)).is_equal(0)
	assert_int(q.size()).is_equal(1)


func test_out_of_order_seq_dropped() -> void:
	var q := InputQueue.new(_knobs())
	q.push(_packet([5, 6, 7]))
	assert_int(q.push(_packet([3, 4, 5]))).is_equal(0)
	assert_int(q.push(_packet([9, 8, 10]))).is_equal(2) # 8 is older than 9: skipped
	assert_int(q.size()).is_equal(5)


func test_move_clamped_to_length_one() -> void:
	var q := InputQueue.new(_knobs())
	q.push(InputFrame.build_packet([_frame(1, Vector2(1.0, 1.0)), _frame(2, Vector2(0.3, -0.4))]))
	assert_float(q.next(1).move.length()).is_equal_approx(1.0, 0.0001)
	assert_vector(q.next(2).move).is_equal_approx(Vector2(0.3, -0.4), Vector2(0.0001, 0.0001))


func test_pitch_clamped_to_85_degrees() -> void:
	var q := InputQueue.new(_knobs())
	q.push(InputFrame.build_packet([_frame(1, Vector2.ZERO, 0.0, 3.0), _frame(2, Vector2.ZERO, 0.0, -3.0)]))
	var limit := deg_to_rad(85.0)
	assert_float(q.next(1).pitch).is_equal_approx(limit, 0.0001)
	assert_float(q.next(2).pitch).is_equal_approx(-limit, 0.0001)


func test_yaw_passes_through_unchanged() -> void:
	var q := InputQueue.new(_knobs())
	q.push(InputFrame.build_packet([_frame(1, Vector2.ZERO, 2.5)]))
	assert_float(q.next(1).yaw).is_equal_approx(2.5, 0.0001)


func test_starvation_repeats_last_frame() -> void:
	var q := InputQueue.new(_knobs())
	q.push(InputFrame.build_packet([_frame(7, Vector2(0.0, 1.0), 1.0)]))
	var first := q.next(1)
	var again := q.next(2)
	assert_int(again.seq).is_equal(7)
	assert_vector(again.move).is_equal(Vector2(0.0, 1.0))
	assert_float(again.yaw).is_equal_approx(1.0, 0.0001)
	assert_bool(first == again).is_true()
	assert_bool(q.is_released()).is_false()


func test_input_released_after_timeout_ticks_not_before() -> void:
	var q := InputQueue.new(_knobs())
	var f := _frame(7, Vector2(0.0, 1.0), 1.0)
	f.sprint = true
	q.push(InputFrame.build_packet([f]))
	q.next(0)
	for t in TIMEOUT_TICKS - 1: # 29 empty ticks
		var held := q.next(1 + t)
		assert_vector(held.move).is_equal(Vector2(0.0, 1.0))
	assert_bool(q.is_released()).is_false()
	var released := q.next(100) # the 30th empty tick
	assert_bool(q.is_released()).is_true()
	assert_vector(released.move).is_equal(Vector2.ZERO)
	assert_bool(released.sprint).is_false()
	assert_bool(released.crouch).is_false()
	assert_bool(released.interact).is_false()
	assert_float(released.yaw).is_equal_approx(1.0, 0.0001) # view kept


## SR-1 review 2026-10-14: only 60 Hz was tested, so a hard-coded 30-tick timeout passed. 500 ms
## at 30 Hz is 15 ticks.
func test_timeout_follows_the_tick_rate() -> void:
	var k := _knobs()
	k.net.sim_tick_hz = 30
	var q := InputQueue.new(k)
	_push1(q, 1)
	q.next(0)
	for t in 14:
		q.next(1 + t)
	assert_bool(q.is_released()).is_false()
	q.next(15)
	assert_bool(q.is_released()).is_true()


func test_new_frame_clears_released() -> void:
	var q := InputQueue.new(_knobs())
	for t in TIMEOUT_TICKS:
		q.next(t)
	assert_bool(q.is_released()).is_true()
	_push1(q, 1)
	q.next(100)
	assert_bool(q.is_released()).is_false()


func test_backlog_above_target_plus_one_consumes_two_per_tick() -> void:
	var q := InputQueue.new(_knobs())
	q.next(0) # one starved tick earns the credit a catch-up spends
	q.push(_packet([1, 2, 3]))
	assert_int(q.target_depth()).is_equal(1)
	assert_int(q.next(1).seq).is_equal(2) # 3 > 1 + 1: two consumed, later returned
	assert_int(q.size()).is_equal(1)


## SR-1 review 2026-10-14: a client sending two frames per tick kept the backlog above target + 1,
## so the server consumed two per tick and the client moved at double speed. A catch-up now only
## repays ticks that starved, so over a run frames consumed never exceed ticks + one cap of credit.
func test_flooding_two_frames_per_tick_never_runs_faster_than_the_clock() -> void:
	var q := InputQueue.new(_knobs())
	var seq := 1
	var consumed := 0
	var ticks := 3 * WINDOW_TICKS
	for t in ticks:
		q.push(_packet([seq, seq + 1]))
		seq += 2
		q.next(t)
		consumed += q.taken().size()
	assert_int(consumed).is_less_equal(ticks + CAP)


func test_catch_up_credit_is_capped_so_a_long_stall_buys_no_sprint() -> void:
	var q := InputQueue.new(_knobs())
	for t in 10 * CAP:
		q.next(t) # long stall: credit stops at the cap
	var seq := 1
	var consumed := 0
	for t in 4 * CAP:
		q.push(_packet([seq, seq + 1]))
		seq += 2
		q.next(100 + t)
		consumed += q.taken().size()
	assert_int(consumed).is_equal(4 * CAP + CAP)


func test_backlog_exactly_target_plus_one_consumes_one() -> void:
	var q := InputQueue.new(_knobs())
	q.push(_packet([1, 2]))
	assert_int(q.next(1).seq).is_equal(1)
	assert_int(q.size()).is_equal(1)


func test_target_rises_above_starvation_high() -> void:
	var q := InputQueue.new(_knobs())
	_run_window(q, 13, 1, 0) # 13/120 = 0.108 > 0.10
	assert_int(q.target_depth()).is_equal(2)


func test_target_stays_at_exactly_starvation_high() -> void:
	var q := InputQueue.new(_knobs())
	_run_window(q, 12, 1, 0) # 12/120 = 0.10, not above
	assert_int(q.target_depth()).is_equal(1)


func test_target_not_adapted_before_a_full_window() -> void:
	var q := InputQueue.new(_knobs())
	for t in WINDOW_TICKS - 1:
		q.next(t) # all starved, window not yet full
	assert_int(q.target_depth()).is_equal(1)


func test_target_falls_below_starvation_low() -> void:
	var q := InputQueue.new(_knobs())
	var seq := _run_window(q, 13, 1, 0)
	assert_int(q.target_depth()).is_equal(2)
	seq = _run_window(q, 3, seq, WINDOW_TICKS) # 3/120 = 0.025 >= 0.02: holds
	assert_int(q.target_depth()).is_equal(2)
	_run_window(q, 2, seq, 2 * WINDOW_TICKS) # 2/120 = 0.0167 < 0.02
	assert_int(q.target_depth()).is_equal(1)


func test_cap_drops_oldest() -> void:
	var q := InputQueue.new(_knobs(), true) # host mode reads one frame in order
	q.push(_packet([0, 1, 2]))
	q.push(_packet([3, 4, 5]))
	q.push(_packet([6, 7, 8]))
	q.push(_packet([9, 10, 11]))
	assert_int(q.size()).is_equal(CAP)
	assert_int(q.cap_drops).is_equal(12 - CAP)
	assert_int(q.next(1).seq).is_equal(12 - CAP)


func test_host_mode_consumes_immediately_at_depth_zero() -> void:
	var q := InputQueue.new(_knobs(), true)
	assert_int(q.target_depth()).is_equal(0)
	_push1(q, 1)
	assert_int(q.next(1).seq).is_equal(1)
	q.push(_packet([2, 3, 4]))
	assert_int(q.next(2).seq).is_equal(2) # one per tick, no double consume
	assert_int(q.size()).is_equal(2)


func test_flags_packed_whole_each_frame() -> void:
	var a := _frame(1)
	a.sprint = true
	a.crouch = true
	var b := _frame(2)
	b.interact = true
	b.target_is_body = true
	b.interact_target = 42
	var packet := InputFrame.build_packet([a, b, _frame(3)])
	assert_array(Array(packet.flags)).is_equal([3, 12, 0])
	assert_int(InputFrame.pack_flags(true, false, true, false)).is_equal(5)
	var q := InputQueue.new(_knobs(), true)
	q.push(packet)
	var ra := q.next(1)
	assert_bool(ra.sprint and ra.crouch and not ra.interact and not ra.target_is_body).is_true()
	var rb := q.next(2)
	assert_bool(rb.interact and rb.target_is_body and not rb.sprint and not rb.crouch).is_true()
	assert_int(rb.interact_target).is_equal(42)


func test_extra_position_key_is_not_read() -> void:
	var q := InputQueue.new(_knobs(), true)
	var p := _packet([1])
	p["position"] = PackedVector3Array([Vector3(999, 999, 999)])
	p["speed"] = PackedFloat32Array([99.0])
	assert_int(q.push(p)).is_equal(1)
	var f := q.next(1)
	var names := []
	for prop in f.get_property_list():
		names.append(prop.name)
	for banned in ["position", "velocity", "speed", "progress"]:
		assert_bool(banned in names).is_false()
	assert_vector(f.move).is_equal(Vector2.ZERO)
	assert_int(q.dropped_packets).is_equal(0)


func test_violations_record_is_rate_limited_but_counter_keeps_counting() -> void:
	var q := InputQueue.new(_knobs())
	for i in InputQueue.MAX_RECORDED_VIOLATIONS + 5:
		q.push(_packet([]))
	assert_int(q.dropped_packets).is_equal(InputQueue.MAX_RECORDED_VIOLATIONS + 5)
	assert_int(q.violations.size()).is_equal(InputQueue.MAX_RECORDED_VIOLATIONS)
