class_name OwnerPredictor extends RefCounted
## Owning client: predicts its own body with the shared movement step and reconciles against the
## server snapshots (ADR-0002 rules 6-7). Call predict() once per physics tick and advance_visual()
## every frame; snapshots arrive on SceneMultiplayer.peer_packet from the server (peer 1).
## Per snapshot: restore the server position and velocity at the acknowledged seq, apply_floor_snap()
## when the snapshot says on-floor, replay the unacknowledged frames, then compare with where the
## body was before: within correction_deadzone_m nothing is shown, under correction_smooth_max_m the
## error is hidden by an offset on `visual` (physics interpolation OFF) that decays over
## correction_smooth_s, otherwise (or when the server flags a snap) the body snaps and
## reset_physics_interpolation() is called. A snapshot not newer than the last applied one is ignored.
## Usage:
##   var p := OwnerPredictor.new(knobs, body, visual, TestMoveStep.apply, smp)
##   p.predict(frame)   # each physics tick: steps the body and sends the last 3 unacked frames

## Memory bound on unacknowledged frames (2 s at 60 Hz); the oldest is dropped beyond it.
const MAX_UNACKED := 120
const SERVER_PEER := 1

## Snapshots applied (stale and undecodable ones are not counted).
var states_received: int = 0
## Corrections beyond the deadzone, smooth and snap alike.
var corrections: int = 0
## Corrections that took the snap path (>= correction_smooth_max_m, or the server snap flag).
var snaps: int = 0
var stale_ignored: int = 0
var bad_snapshots: int = 0
## Magnitude in metres of every correction beyond the deadzone / of every snap.
var correction_magnitudes: Array[float] = []
var snap_magnitudes: Array[float] = []
## The modifiers used for prediction; refreshed from each own snapshot entry.
var modifiers := MovementModifiers.new()
var estimator: TickEstimator

var _body: CharacterBody3D
var _visual: Node3D
var _step: Callable
var _smp: SceneMultiplayer
var _deadzone: float
var _smooth_max: float
var _smooth_s: float
var _unacked: Array[InputFrame] = []
var _next_seq: int = 1
var _local_tick: int = 0
var _last_tick: int = -1
var _offset: Vector3 = Vector3.ZERO
var _decay_speed: float = 0.0


## `visual` is the non-interpolated child that shows the smoothing offset. `smp` may be null (no
## network: tests feed receive() directly).
func _init(knobs: Knobs, body: CharacterBody3D, visual: Node3D, step: Callable, smp: SceneMultiplayer) -> void:
	_body = body
	_visual = visual
	_step = step
	_smp = smp
	_deadzone = knobs.net.correction_deadzone_m
	_smooth_max = knobs.net.correction_smooth_max_m
	_smooth_s = knobs.net.correction_smooth_s
	estimator = TickEstimator.new(knobs.net.tick_estimate_rise_alpha, knobs.net.tick_estimate_fall_alpha)
	visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if smp != null:
		smp.peer_packet.connect(_on_packet)


## Stops listening. Safe to call twice.
func close() -> void:
	if _smp != null and _smp.peer_packet.is_connected(_on_packet):
		_smp.peer_packet.disconnect(_on_packet)


## One physics tick: stamps `frame.seq`, runs the shared step on the body and sends the last 3
## unacknowledged frames (unreliable, input channel).
func predict(frame: InputFrame) -> void:
	frame.seq = _next_seq
	_next_seq += 1
	_local_tick += 1
	_step.call(_body, frame, modifiers)
	_unacked.append(frame)
	if _unacked.size() > MAX_UNACKED:
		_unacked.pop_front()
	if _smp != null:
		var last: Array[InputFrame] = []
		for f in _unacked.slice(-InputQueue.MAX_FRAMES_PER_PACKET):
			last.append(f)
		_smp.send_bytes(var_to_bytes(InputFrame.build_packet(last)), SERVER_PEER,
			MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, NetChannels.INPUT)


## Decays the smoothing offset; call every rendered frame.
func advance_visual(delta: float) -> void:
	_offset = _offset.move_toward(Vector3.ZERO, _decay_speed * delta)
	_visual.position = _offset


## Current smoothing offset on the visual child.
func visual_offset() -> Vector3:
	return _offset


## Frames not yet acknowledged by a snapshot.
func unacked_count() -> int:
	return _unacked.size()


## Local physics ticks predicted so far.
func local_tick() -> int:
	return _local_tick


## Decodes and applies one snapshot datagram. A bad one is counted and dropped.
func receive(bytes: PackedByteArray) -> void:
	var snap := SnapshotCodec.decode(bytes)
	if snap.is_empty():
		bad_snapshots += 1
		return
	apply_snapshot(snap)


## Reconciles against a decoded snapshot (see class doc). Ignored when not newer than the last one
## or when it has no own entry.
func apply_snapshot(snap: Dictionary) -> void:
	if snap.tick <= _last_tick:
		stale_ignored += 1
		return
	var own: Dictionary = {}
	for b: Dictionary in snap.bodies:
		if b.get("own", false):
			own = b
	if own.is_empty():
		return
	_last_tick = snap.tick
	states_received += 1
	estimator.observe(snap.tick, float(_local_tick))
	var predicted := _body.global_position
	while not _unacked.is_empty() and _unacked[0].seq <= own.seq:
		_unacked.pop_front()
	modifiers.set_from_scale(own.scale)
	_restore_contacts(own.pos)
	_body.global_position = own.pos
	_body.velocity = own.vel
	if own.on_floor:
		_body.apply_floor_snap() ## before the first replayed step (ADR-0002 rule 6.1)
	for f in _unacked:
		_step.call(_body, f, modifiers)
	var error := (_body.global_position - predicted).length()
	if own.snap or error >= _smooth_max:
		_offset = Vector3.ZERO
		_visual.position = Vector3.ZERO
		_body.reset_physics_interpolation()
		snaps += 1
		snap_magnitudes.append(error)
		corrections += 1
		correction_magnitudes.append(error)
	elif error > _deadzone:
		corrections += 1
		correction_magnitudes.append(error)
		_offset += predicted - _body.global_position
		_decay_speed = _offset.length() / _smooth_s
		_visual.position = _offset


## Recomputes the body's contact flags (on floor, on wall) at `pos` from geometry. CharacterBody3D has
## no floor-state setter, and setting the position keeps the flags of the predicted head; a replay
## that starts airborne would then skip gravity on its first step. A zero-velocity move_and_slide
## with no floor snap recomputes them in place (it can only depenetrate by the safe margin; the
## caller sets the position again). apply_floor_snap() afterwards is a no-op when this found a floor.
func _restore_contacts(pos: Vector3) -> void:
	var snap_length := _body.floor_snap_length
	_body.global_position = pos
	_body.velocity = Vector3.ZERO
	_body.floor_snap_length = 0.0
	_body.move_and_slide()
	_body.floor_snap_length = snap_length


func _on_packet(peer_id: int, bytes: PackedByteArray) -> void:
	if peer_id == SERVER_PEER:
		receive(bytes)
