# Story network-authority/007: rewind history and lag compensation (ADR-0003 §3-6).
extends GdUnitTestSuite

const HZ := 60
const INTERP_MS := 50
const MAX_REWIND_MS := 180
const HISTORY := 16
const SLACK := 1
const H := 1.8
const R := 0.3
const ATTACKER := 1
const TARGET := 2
const NOW := 100
## Target moves on a circle (so interpolation between ticks matters) at this speed, m/s.
const SPEED := 4.0
const CIRCLE_M := 3.0
## The attacker's render clock sits this far past its newest snapshot (fractional view ticks).
const PHASE := 0.37

var _frame := InputFrame.new()
var _hidden_now: Dictionary[int, bool] = {}


func _knobs() -> Knobs:
	var k := Knobs.new()
	k.net = NetKnobs.new()
	k.ability = AbilityKnobs.new()
	k.net.sim_tick_hz = HZ
	k.net.interp_delay_ms = INTERP_MS
	k.net.history_ticks = HISTORY
	k.net.slack_ticks = SLACK
	k.ability.max_rewind_ms = MAX_REWIND_MS
	return k


## LagCompensation's frame source: the attacker's frame this tick.
func _frame_of(_player_id: int) -> InputFrame:
	return _frame


## Current-tick eligibility: true = skip (hidden now).
func _is_hidden_now(player_id: int) -> bool:
	return _hidden_now.get(player_id, false)


func _path(tick: float) -> Vector3:
	var a := SPEED / CIRCLE_M * tick / HZ
	return Vector3(cos(a), 0.0, sin(a)) * CIRCLE_M


## What a client rendering at fractional `tick` drew: the two bracketing snapshots, lerped.
func _seen(tick: float) -> Vector3:
	return _path(floorf(tick)).lerp(_path(ceilf(tick)), tick - floorf(tick))


func _history_with_path(from: int, to: int) -> RewindHistory:
	var h := RewindHistory.new(HISTORY)
	for t in range(from, to + 1):
		var p := _path(t)
		h.push(t, TARGET, p, H, R, p + Vector3(0.0, H - R, 0.0))
	return h


func test_full_rewind_error_is_zero_up_to_cap_and_capped_error_reported_at_150ms() -> void:
	var cap_ticks := MAX_REWIND_MS * HZ / 1000.0
	for rtt_ms: int in [50, 100, 150]:
		var rtt_ticks := rtt_ms * HZ / 1000.0
		var h := _history_with_path(0, NOW)
		var lc := LagCompensation.new(_knobs(), h, _frame_of)
		_frame.ack_snapshot_tick = NOW - int(rtt_ticks)
		_frame.view_tick = NOW - rtt_ticks - INTERP_MS * HZ / 1000.0 + PHASE
		var lag := NOW - _frame.view_tick
		var rewind := lc.rewind_ticks(ATTACKER, NOW)
		var s := h.sample(TARGET, NOW - rewind)
		assert_bool(s.ok).is_true()
		var err: float = s.pos.distance_to(_seen(_frame.view_tick))
		if lag <= cap_ticks:
			assert_float(rewind).is_equal_approx(lag, 0.0001)
			assert_float(err).override_failure_message("RTT %d ms: error %.4f m" % [rtt_ms, err]).is_less(0.005)
			assert_int(lc.record_count).is_equal(0)
		else:
			assert_float(rewind).is_equal_approx(cap_ticks, 0.0001)
			# Capped: the target is (lag - cap) ticks newer than seen, about SPEED * that, along the arc.
			var expected := SPEED * (lag - cap_ticks) / HZ
			print("ADR-0003 capped rewind error at %d ms RTT: %.3f m (lag %.2f ticks, cap %.2f)" % [rtt_ms, err, lag, cap_ticks])
			assert_float(err).is_equal_approx(expected, 0.002)
			assert_int(lc.record_count).is_equal(1)
			assert_str(lc.records[0].kind).is_equal("clamped")


func test_non_finite_or_future_view_tick_gives_zero_rewind_and_a_log_entry() -> void:
	for vt: float in [NAN, INF, -INF, NOW + 0.5]:
		var lc := LagCompensation.new(_knobs(), _history_with_path(0, NOW), _frame_of)
		_frame.view_tick = vt
		_frame.ack_snapshot_tick = NOW - 6
		assert_float(lc.rewind_ticks(ATTACKER, NOW)).is_equal(0.0)
		assert_int(lc.record_count).is_equal(1)
		assert_str(lc.records[0].kind).is_equal("bad_view_tick")
		assert_int(lc.records[0].attacker).is_equal(ATTACKER)


func test_view_tick_equal_to_now_is_zero_rewind_without_a_log_entry() -> void:
	var lc := LagCompensation.new(_knobs(), _history_with_path(0, NOW), _frame_of)
	_frame.view_tick = NOW
	_frame.ack_snapshot_tick = NOW - 6
	assert_float(lc.rewind_ticks(ATTACKER, NOW)).is_equal(0.0)
	assert_int(lc.record_count).is_equal(0)


func test_claimed_lag_above_server_measured_bound_is_clamped_and_logged() -> void:
	var lc := LagCompensation.new(_knobs(), _history_with_path(0, NOW), _frame_of)
	_frame.ack_snapshot_tick = NOW - 1 ## the client acked a fresh snapshot ...
	_frame.view_tick = NOW - 10.0 ## ... yet claims a 10-tick view lag
	var bound := 1.0 + INTERP_MS * HZ / 1000.0 + 2.0 + SLACK ## (T - ack) + interp + 2 + slack = 7
	assert_float(lc.rewind_ticks(ATTACKER, NOW)).is_equal_approx(bound, 0.0001)
	assert_int(lc.record_count).is_equal(1)
	assert_str(lc.records[0].kind).is_equal("clamped")
	assert_float(lc.records[0].requested).is_equal_approx(10.0, 0.0001)
	assert_float(lc.records[0].applied).is_equal_approx(bound, 0.0001)


func test_sample_outside_history_is_not_ok() -> void:
	var h := _history_with_path(0, 40) ## the 16-tick ring keeps 25..40
	assert_bool(h.sample(TARGET, 40.0).ok).is_true()
	assert_bool(h.sample(TARGET, 25.0).ok).is_true()
	assert_bool(h.sample(TARGET, 24.0).ok).is_false() ## overwritten
	assert_bool(h.sample(TARGET, 24.5).ok).is_false() ## one bracket overwritten
	assert_bool(h.sample(TARGET, 40.5).ok).is_false() ## future bracket
	assert_bool(h.sample(TARGET, NAN).ok).is_false()
	assert_bool(h.sample(TARGET + 1, 30.0).ok).is_false() ## never pushed


func test_sample_interpolates_between_bracketing_ticks() -> void:
	var h := RewindHistory.new(HISTORY)
	h.push(10, TARGET, Vector3(0, 0, 0), H, R, Vector3(0, 1.5, 0))
	h.push(11, TARGET, Vector3(2, 0, 0), 1.2, R, Vector3(2, 0.9, 0))
	var s := h.sample(TARGET, 10.25)
	assert_bool(s.ok).is_true()
	assert_vector(s.pos).is_equal_approx(Vector3(0.5, 0, 0), Vector3.ONE * 0.0001)
	assert_vector(s.chest).is_equal_approx(Vector3(0.5, 1.35, 0), Vector3.ONE * 0.0001)
	assert_float(s.height).is_equal_approx(1.65, 0.0001)
	assert_float(s.radius).is_equal_approx(R, 0.0001)


func test_out_of_history_target_uses_current_position_and_is_logged() -> void:
	var h := _history_with_path(NOW - 2, NOW) ## joined two ticks ago
	var lc := LagCompensation.new(_knobs(), h, _frame_of)
	var ids: Array[int] = [TARGET]
	var targets := lc.targets_at(NOW, 5.0, ids)
	assert_int(targets.size()).is_equal(1)
	assert_int(targets[0].id).is_equal(TARGET)
	assert_vector(targets[0].pos).is_equal_approx(_path(NOW), Vector3.ONE * 0.0001)
	assert_int(lc.record_count).is_equal(1)
	assert_str(lc.records[0].kind).is_equal("out_of_history")
	assert_int(lc.records[0].player).is_equal(TARGET)


func test_targets_at_rewinds_target_positions() -> void:
	var lc := LagCompensation.new(_knobs(), _history_with_path(0, NOW), _frame_of)
	var ids: Array[int] = [TARGET]
	var targets := lc.targets_at(NOW, 4.5, ids)
	assert_vector(targets[0].pos).is_equal_approx(_seen(NOW - 4.5), Vector3.ONE * 0.0001)
	assert_int(lc.record_count).is_equal(0)


## A target hidden after the rewound time is not hit: the skip reads current state, the history carries
## no eligibility. The visible target behind it is hit instead.
func test_eligibility_is_read_at_the_current_tick_not_the_rewound_tick() -> void:
	var h := RewindHistory.new(HISTORY)
	for t in range(NOW - 10, NOW + 1):
		var near := Vector3(0, 0, -3) if t <= NOW - 6 else Vector3(5, 0, -3) ## walked into a hide spot at T-5
		h.push(t, TARGET, near, H, R, near + Vector3(0, H - R, 0))
		h.push(t, TARGET + 1, Vector3(0, 0, -8), H, R, Vector3(0, H - R, -8))
	_hidden_now = {TARGET: true}
	var lc := LagCompensation.new(_knobs(), h, _frame_of)
	var ids: Array[int] = [TARGET, TARGET + 1]
	var targets := lc.targets_at(NOW, 6.0, ids)
	var origin := Vector3(0, 1.5, 0)
	var hit := LagCompensation.ray_first_hit(origin, Vector3.FORWARD, 20.0, targets, _is_hidden_now)
	assert_bool(hit.hit).is_true()
	assert_int(hit.id).is_equal(TARGET + 1)
	_hidden_now = {}
	hit = LagCompensation.ray_first_hit(origin, Vector3.FORWARD, 20.0, targets, _is_hidden_now)
	assert_int(hit.id).is_equal(TARGET) ## rewound position of the near target is on the ray
	assert_float(hit.distance).is_equal_approx(3.0 - R, 0.0001)


func test_ray_first_hit_respects_max_distance_and_direction() -> void:
	var targets: Array = [{"id": TARGET, "pos": Vector3(0, 0, -5), "height": H, "radius": R}]
	var origin := Vector3(0, 1.0, 0)
	assert_bool(LagCompensation.ray_first_hit(origin, Vector3.FORWARD, 4.0, targets, _is_hidden_now).hit).is_false()
	assert_bool(LagCompensation.ray_first_hit(origin, Vector3.BACK, 20.0, targets, _is_hidden_now).hit).is_false()
	var hit := LagCompensation.ray_first_hit(origin, Vector3.FORWARD * 3.0, 20.0, targets, _is_hidden_now)
	assert_float(hit.distance).is_equal_approx(5.0 - R, 0.0001) ## dir is normalised
	# Over the head: the top cap sphere centre is at H - R = 1.5; a ray 0.29 above it still hits it.
	var over := LagCompensation.ray_first_hit(Vector3(0, H - R + 0.29, 0), Vector3.FORWARD, 20.0, targets, _is_hidden_now)
	assert_bool(over.hit).is_true()
	over = LagCompensation.ray_first_hit(Vector3(0, H - R + 0.31, 0), Vector3.FORWARD, 20.0, targets, _is_hidden_now)
	assert_bool(over.hit).is_false()
	# Straight down onto the head (parallel to the axis): enters the top cap at y = H.
	var down := LagCompensation.ray_first_hit(Vector3(0, 5, -5), Vector3.DOWN, 20.0, targets, _is_hidden_now)
	assert_float(down.distance).is_equal_approx(5.0 - H, 0.0001)


## Segment half-length is height / 2 - radius: the axis runs from feet + r to feet + h - r.
func test_capsule_hits_segment_uses_half_length_height_half_minus_radius() -> void:
	var t := {"pos": Vector3.ZERO, "height": H, "radius": R}
	var top := H - R
	assert_bool(LagCompensation.capsule_hits_segment(Vector3(-1, top + 0.29, 0), Vector3(1, top + 0.29, 0), t)).is_true()
	assert_bool(LagCompensation.capsule_hits_segment(Vector3(-1, top + 0.31, 0), Vector3(1, top + 0.31, 0), t)).is_false()
	assert_bool(LagCompensation.capsule_hits_segment(Vector3(-1, R - 0.29, 0), Vector3(1, R - 0.29, 0), t)).is_true()
	assert_bool(LagCompensation.capsule_hits_segment(Vector3(-1, 0.9, 0.31), Vector3(1, 0.9, 0.31), t)).is_false()
	assert_bool(LagCompensation.capsule_hits_segment(Vector3(-1, 0.9, 0.31), Vector3(1, 0.9, 0.31), t, 0.02)).is_true()


func test_input_frame_carries_view_and_ack_ticks_through_the_queue() -> void:
	var k := Knobs.load_all()
	var frames: Array[InputFrame] = []
	for i in 3:
		var f := InputFrame.new()
		f.seq = i + 1
		f.view_tick = 123456.37 + i
		f.ack_snapshot_tick = 123459 + i
		frames.append(f)
	var packet := InputFrame.build_packet(frames)
	assert_int(var_to_bytes(packet).size()).is_less_equal(k.net.input_packet_cap_bytes)
	var q := InputQueue.new(k)
	assert_int(q.push(packet)).is_equal(3)
	var got := q.next(0)
	assert_float(got.view_tick).is_equal_approx(123456.37, 0.01)
	assert_int(got.ack_snapshot_tick).is_equal(123459)
