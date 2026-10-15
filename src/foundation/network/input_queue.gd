class_name InputQueue extends RefCounted
## Server-side input queue for ONE player (ADR-0002 §3-4); the server keeps one per player ID.
## The host's own player uses the same class with host_mode = true (depth 0, no adaptation).
## Packet (Dictionary of packed arrays, one entry per frame, at most 3): required `seq` PackedInt32Array,
## `move` PackedVector2Array, `flags` PackedByteArray (bits: InputFrame.FLAG_*), `yaw` and `pitch`
## PackedFloat32Array in RADIANS; optional `interact_target` and `view_tick` PackedInt32Array.
## Any other key (e.g. a position) is never read. Invalid packets are dropped whole and recorded.
## No fail_hard: a remote peer must not be able to trip an assert, so violations only count and record.
## Tuning comes from Knobs (net.input_queue_cap, max_seq_ahead, starvation_*; controller.intent_timeout_ms).
## Usage:
##   var q := InputQueue.new(knobs); q.push(packet); var f := q.next(tick); if q.is_released(): ...

const MAX_FRAMES_PER_PACKET := 3
const PITCH_LIMIT_DEG := 85.0 ## ADR-0002 §3
const MAX_RECORDED_VIOLATIONS := 32 ## rate limit: the counter keeps counting, the text stops growing

## Human-readable record of dropped packets (first MAX_RECORDED_VIOLATIONS only).
var violations: PackedStringArray = []
## Total packets dropped as invalid.
var dropped_packets: int = 0
## Frames discarded because the cap was hit (oldest first).
var cap_drops: int = 0

var _host_mode: bool
var _cap: int
var _max_ahead: int
var _high: float
var _low: float
var _timeout_ticks: int
var _window_ticks: int
var _frames: Array[InputFrame] = []
var _taken: Array[InputFrame] = []
var _newest_seq: int = -1
var _last_consumed_seq: int = -1
var _last: InputFrame = null
var _empty_ticks: int = 0
var _released: bool = false
var _target: int = 1
## Catch-up credit: one per starved tick, capped at _cap; each two-frame tick spends one, so a client
## can never be consumed faster than the clock over a run (SR-1 review: flooding gave double speed).
var _credit: int = 0
## Ring of the last _window_ticks ticks: 1 = the queue was empty on that tick.
var _ring: PackedByteArray = []
var _ring_pos: int = 0
var _ring_filled: int = 0
var _starved_in_ring: int = 0


## `knobs` supplies every number. `host_mode` true = depth 0 (consume at once, no target logic).
func _init(knobs: Knobs, host_mode: bool = false) -> void:
	_host_mode = host_mode
	_cap = knobs.net.input_queue_cap
	_max_ahead = knobs.net.max_seq_ahead
	_high = knobs.net.starvation_high
	_low = knobs.net.starvation_low
	_timeout_ticks = knobs.ticks(knobs.controller.intent_timeout_ms / 1000.0)
	_window_ticks = maxi(1, knobs.ticks(knobs.net.starvation_window_s))
	_ring.resize(_window_ticks)


## Validates `packet` (see class doc) and enqueues its frames whose seq is newer than any accepted.
## Invalid packet: nothing changes, dropped_packets and violations record it. Returns frames enqueued.
func push(packet: Dictionary) -> int:
	var reason := _validate(packet)
	if reason != "":
		dropped_packets += 1
		if violations.size() < MAX_RECORDED_VIOLATIONS:
			violations.append(reason)
		return 0
	var seqs: PackedInt32Array = packet.seq
	var moves: PackedVector2Array = packet.move
	var flags: PackedByteArray = packet.flags
	var yaws: PackedFloat32Array = packet.yaw
	var pitches: PackedFloat32Array = packet.pitch
	var targets: PackedInt32Array = packet.get("interact_target", PackedInt32Array())
	var views: PackedInt32Array = packet.get("view_tick", PackedInt32Array())
	var pitch_limit := deg_to_rad(PITCH_LIMIT_DEG)
	var added := 0
	for i in seqs.size():
		if seqs[i] <= _newest_seq:
			continue ## duplicate or out of order
		var f := InputFrame.new()
		f.seq = seqs[i]
		f.move = moves[i].limit_length(1.0)
		f.sprint = flags[i] & InputFrame.FLAG_SPRINT != 0
		f.crouch = flags[i] & InputFrame.FLAG_CROUCH != 0
		f.interact = flags[i] & InputFrame.FLAG_INTERACT != 0
		f.target_is_body = flags[i] & InputFrame.FLAG_TARGET_IS_BODY != 0
		f.interact_target = targets[i] if not targets.is_empty() else 0
		f.view_tick = views[i] if not views.is_empty() else 0
		f.yaw = yaws[i]
		f.pitch = clampf(pitches[i], -pitch_limit, pitch_limit)
		_newest_seq = f.seq
		_frames.append(f)
		added += 1
	while _frames.size() > _cap:
		_frames.pop_front()
		cap_drops += 1
	return added


## The frame to simulate this tick. Normally consumes one queued frame, two when the backlog exceeds
## target depth + 1 and a starved tick left credit (the later one is returned). Empty queue: repeats the last frame; after
## intent_timeout_ms (in ticks) with none, returns a released frame and is_released() is true.
## `_tick` is accepted for the phase-1 hook signature; consumption is per call, not per clock.
func next(_tick: int) -> InputFrame:
	if _host_mode:
		return _take_or_starve(1)
	var starved := _frames.is_empty()
	_record_starvation(starved)
	if starved:
		_credit = mini(_credit + 1, _cap)
	# ponytail: a backlog grown by jitter without a starved tick keeps its extra latency until one
	# starves; spending credit on it instead would hand a flooding client free speed.
	if _frames.size() > _target + 1 and _credit > 0:
		_credit -= 1
		return _take_or_starve(2)
	return _take_or_starve(1)


## True once input has been treated as released (no frame for intent_timeout_ms); cleared by the next frame.
func is_released() -> bool:
	return _released


## Current target depth (1 or 2; 0 in host mode).
func target_depth() -> int:
	return 0 if _host_mode else _target


## The queued frames the last next() consumed, oldest first: two on a catch-up tick, none when it
## starved (next() then returned a repeated or released frame). Movement steps each one, so a
## catch-up never skips a frame the owner predicted (story 006).
func taken() -> Array[InputFrame]:
	return _taken


## Number of frames waiting.
func size() -> int:
	return _frames.size()


func _take_or_starve(count: int) -> InputFrame:
	if _frames.is_empty():
		_taken.clear()
		_empty_ticks += 1
		if _empty_ticks >= _timeout_ticks:
			_released = true
		if _released:
			return _released_frame()
		return _last if _last != null else InputFrame.new()
	var f: InputFrame = null
	_taken.clear()
	for i in mini(count, _frames.size()):
		f = _frames.pop_front()
		_taken.append(f)
	_last = f
	_last_consumed_seq = f.seq
	_empty_ticks = 0
	_released = false
	return f


func _released_frame() -> InputFrame:
	var r := InputFrame.new()
	if _last != null:
		r.seq = _last.seq
		r.yaw = _last.yaw
		r.pitch = _last.pitch
		r.view_tick = _last.view_tick
	return r


## Slides the starvation window and moves the target depth when a full window crosses a threshold.
func _record_starvation(starved: bool) -> void:
	_starved_in_ring -= _ring[_ring_pos]
	_ring[_ring_pos] = 1 if starved else 0
	_starved_in_ring += _ring[_ring_pos]
	_ring_pos = (_ring_pos + 1) % _window_ticks
	_ring_filled = mini(_ring_filled + 1, _window_ticks)
	if _ring_filled < _window_ticks:
		return
	var fraction := float(_starved_in_ring) / float(_window_ticks)
	if fraction > _high:
		_target = 2
	elif fraction < _low:
		_target = 1


## "" when valid, else why not. Checks shape, length, count and finiteness before any value is read.
func _validate(packet: Dictionary) -> String:
	var types := {"seq": TYPE_PACKED_INT32_ARRAY, "move": TYPE_PACKED_VECTOR2_ARRAY,
		"flags": TYPE_PACKED_BYTE_ARRAY, "yaw": TYPE_PACKED_FLOAT32_ARRAY, "pitch": TYPE_PACKED_FLOAT32_ARRAY}
	var optional := {"interact_target": TYPE_PACKED_INT32_ARRAY, "view_tick": TYPE_PACKED_INT32_ARRAY}
	for key in types:
		if typeof(packet.get(key)) != types[key]:
			return "missing or wrong type: " + key
	for key in optional:
		if packet.has(key) and typeof(packet[key]) != optional[key]:
			return "wrong type: " + key
	var n: int = packet.seq.size()
	if n == 0:
		return "empty packet"
	if n > MAX_FRAMES_PER_PACKET:
		return "too many frames: %d" % n
	if packet.move.size() != n or packet.flags.size() != n or packet.yaw.size() != n or packet.pitch.size() != n:
		return "mismatched array lengths"
	for key in optional:
		if packet.has(key) and packet[key].size() != n:
			return "mismatched array lengths: " + key
	for i in n:
		if not (is_finite(packet.move[i].x) and is_finite(packet.move[i].y)
				and is_finite(packet.yaw[i]) and is_finite(packet.pitch[i])):
			return "non-finite value in frame %d" % i
	# A silent client cannot advance _last_consumed_seq, yet its seq keeps counting one per tick,
	# so the window grows by the empty ticks (else a stall longer than max_seq_ahead never recovers).
	var limit := _last_consumed_seq + _empty_ticks + _max_ahead
	for s in packet.seq:
		if s < 0 or s > limit:
			return "seq %d outside accepted range (limit %d)" % [s, limit]
	return ""
