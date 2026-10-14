class_name ServerMovement extends RefCounted
## Server-side movement, position history and snapshots for every player (ADR-0002 rules 2-5, 9).
## Plugs into TickRunner's phase hooks: 1 dequeue one frame per player, 2 movement (the shared step),
## 3 push positions into the history ring, 6 build and send per-peer snapshots. Server only.
## State is keyed by player ID; a peer ID is looked up through NetAuthority on each use, never stored.
## The caller creates each player's CharacterBody3D (in the tree, with a CapsuleShape3D CollisionShape3D
## child) and passes it to add_player(). Remote input arrives on SceneMultiplayer.peer_packet; the
## host's own player calls push_local() into the same InputQueue class (host_mode, depth 0).
## Rule 9: a body found inside static geometry is put back at its last valid position (the end of the
## latest tick with no overlap) and its restore counter rises; every own snapshot entry carries the
## counter, so the owner takes the snap path even when the snapshot right after the restore is lost.
## A body whose position or velocity is not finite is restored the same way (a NaN would make every
## snapshot to its owner fail decoding).
## The gait byte is a stand-in derived from the frame (0 idle, 1 walk, 2 sprint, 3 crouch); the
## controller epic owns the real gait.
## Usage:
##   var sm := ServerMovement.new(knobs, net, smp, TestMoveStep.apply, WORLD_LAYER_MASK)
##   sm.attach(runner); sm.add_player(pid, body)

const GAIT_IDLE := 0
const GAIT_WALK := 1
const GAIT_SPRINT := 2
const GAIT_CROUCH := 3
## The inside-geometry probe is the body's capsule shrunk by this on every side, so a capsule resting
## on the floor (touching, not penetrating) never counts as inside.
const PROBE_SHRINK_M := 0.02
const MAX_RECORDED_VIOLATIONS := 32

## Packets dropped: from an unbound peer, oversized, or not a Dictionary after decoding.
var unknown_peer_drops: int = 0
var oversize_drops: int = 0
var malformed_drops: int = 0
## Human-readable record of the above (first MAX_RECORDED_VIOLATIONS only).
var violations: PackedStringArray = []

var _knobs: Knobs
var _net: NetAuthority
var _smp: SceneMultiplayer
var _step: Callable
var _static_mask: int
var _players: Dictionary = {}
var _runner: TickRunner
## Which bodies each viewer's snapshot carries and under which handle (ADR-0004). The composition root
## sets its relevance.volume_at and visible_volumes from the Facility Map; until then only the near
## rule applies. Tests may replace it with one built on a seeded RNG.
var scope: ReplicationScope


class PlayerState extends RefCounted:
	var body: CharacterBody3D
	var queue: InputQueue
	var frame: InputFrame = InputFrame.new()
	var ack_seq: int = 0
	var modifiers := MovementModifiers.new()
	var last_valid: Vector3
	## Inside-geometry restores so far, mod 256 (SnapshotCodec `restores`).
	var restores: int = 0
	var probe: PhysicsShapeQueryParameters3D
	## The body's capsule node: the probe is resized from its live shape each tick (a crouch resizes it).
	var shape_node: CollisionShape3D
	## No movement and no inside-geometry restore (an Out player, set_frozen).
	var frozen := false
	var history_pos := PackedVector3Array()
	var history_tick := PackedInt32Array()


## `step` is the shared Callable(body, frame, modifiers) (ADR-0002 apply_move). `static_mask` is the
## physics layer mask of static geometry used by the inside-geometry check.
func _init(knobs: Knobs, net: NetAuthority, smp: SceneMultiplayer, step: Callable, static_mask: int) -> void:
	_knobs = knobs
	_net = net
	_smp = smp
	_step = step
	_static_mask = static_mask
	scope = ReplicationScope.new(knobs)


## Sets the runner's four hook Callables and starts listening for input packets.
func attach(runner: TickRunner) -> void:
	_runner = runner
	runner.input_stage = _input_phase
	runner.movement_stage = _movement_phase
	runner.history_stage = _history_phase
	runner.snapshot_stage = _snapshot_phase
	_smp.peer_packet.connect(_on_packet)
	_net.player_rejoined.connect(_on_rejoined)


## Removes the hooks and the packet listener. Safe to call twice.
func detach() -> void:
	if _runner != null:
		_runner.input_stage = Callable()
		_runner.movement_stage = Callable()
		_runner.history_stage = Callable()
		_runner.snapshot_stage = Callable()
		_runner = null
	if _smp.peer_packet.is_connected(_on_packet):
		_smp.peer_packet.disconnect(_on_packet)
	if _net.player_rejoined.is_connected(_on_rejoined):
		_net.player_rejoined.disconnect(_on_rejoined)


## Registers a player. `host_mode` true = the host's own player (InputQueue depth 0, no peer).
func add_player(player_id: int, body: CharacterBody3D, host_mode: bool = false) -> void:
	var p := PlayerState.new()
	p.body = body
	p.queue = InputQueue.new(_knobs, host_mode)
	p.last_valid = body.global_position
	var n := _knobs.net.history_ticks
	p.history_pos.resize(n)
	p.history_tick.resize(n)
	p.history_tick.fill(-1)
	for c in body.get_children():
		var cs := c as CollisionShape3D
		if cs != null and cs.shape is CapsuleShape3D:
			p.shape_node = cs
			p.probe = PhysicsShapeQueryParameters3D.new()
			p.probe.shape = CapsuleShape3D.new()
			p.probe.collision_mask = _static_mask
			p.probe.exclude = [body.get_rid()]
	if p.probe == null:
		_record("player %d has no capsule CollisionShape3D: inside-geometry restore is off" % player_id)
	_players[player_id] = p


## Forgets a player (the body is the caller's to free).
func remove_player(player_id: int) -> void:
	_players.erase(player_id)
	scope.remove_player(player_id)


## The host's own player submits one frame through the same queue as remote players.
func push_local(player_id: int, frame: InputFrame) -> void:
	var f: Array[InputFrame] = [frame]
	_players[player_id].queue.push(InputFrame.build_packet(f))


## Stops (true) or resumes the player's movement step. The owner of Eliminated and Escaped (Match Flow)
## calls it together with PlayerBody.set_out(), which removes the body's collision (ADR-0007).
func set_frozen(player_id: int, frozen: bool) -> void:
	_players[player_id].frozen = frozen
	if frozen:
		_players[player_id].body.velocity = Vector3.ZERO


## The player's modifiers; the controller arbitration (story 002) writes them.
func modifiers_of(player_id: int) -> MovementModifiers:
	return _players[player_id].modifiers


## The frame the player's movement used this tick (a repeat or released frame when starved; a released
## frame keeps the last yaw and pitch). The server's view direction is read from it (ViewState).
func frame_of(player_id: int) -> InputFrame:
	return _players[player_id].frame


## Last input seq consumed for the player (0 before any).
func ack_seq_of(player_id: int) -> int:
	return _players[player_id].ack_seq


## The player's last valid position (rule 9).
func last_valid_position_of(player_id: int) -> Vector3:
	return _players[player_id].last_valid


## The player's InputQueue (for tests and the telemetry that reads its counters).
func queue_of(player_id: int) -> InputQueue:
	return _players[player_id].queue


## The recorded position at `tick`, or null when it is older than history_ticks or never recorded.
## ADR-0003 reads this for lag compensation.
func position_at(player_id: int, tick: int) -> Variant:
	if tick < 0:
		return null ## unrecorded slots hold tick -1
	var p: PlayerState = _players[player_id]
	var i := tick % p.history_tick.size()
	return p.history_pos[i] if p.history_tick[i] == tick else null


func _input_phase(tick: int) -> void:
	for p: PlayerState in _players.values():
		p.frame = p.queue.next(tick)
		p.ack_seq = maxi(p.ack_seq, p.frame.seq)


func _movement_phase(_tick: int) -> void:
	for p: PlayerState in _players.values():
		if p.frozen:
			continue
		_restore_if_inside(p)
		# Movement steps exactly the frames the owner predicted, time-shifted: a catch-up tick steps
		# both, a starved tick steps none (the repeat still stands for intent, e.g. holds), so a late
		# frame is never preceded by a step the owner did not run. A released frame is stepped so a
		# silent player still stops and falls.
		var taken := p.queue.taken()
		if taken.is_empty() and p.queue.is_released():
			_step.call(p.body, p.frame, p.modifiers)
		for f in taken:
			_step.call(p.body, f, p.modifiers)
		if not _restore_if_inside(p):
			p.last_valid = p.body.global_position


func _history_phase(tick: int) -> void:
	for p: PlayerState in _players.values():
		var i := tick % p.history_tick.size()
		p.history_pos[i] = p.body.global_position
		p.history_tick[i] = tick


## Per viewer: its own entry, then every relevant body under the viewer's handle, in handle order
## (join order would let a client link a re-introduced body to its old place). Handle introduce and
## retire messages are sent first, reliable on the event channel (ADR-0004 §3); ENet does not order
## across channels, so a snapshot can still arrive first and its new entry is ignored until then.
func _snapshot_phase(tick: int) -> void:
	var positions := {}
	for pid: int in _players:
		positions[pid] = _players[pid].body.global_position
	for pid: int in _players:
		var peer := _net.peer_id_of(pid)
		if peer == -1:
			continue
		var seen := scope.bodies_for(tick, pid, positions)
		var msgs := scope.handles.take(pid)
		if not msgs.is_empty():
			_smp.send_bytes(HandleTable.encode(msgs), peer, MultiplayerPeer.TRANSFER_MODE_RELIABLE, NetChannels.EVENT)
		var bodies: Array[Dictionary] = [_entry(pid, pid, true)]
		for other: int in seen: ## handle order (ReplicationScope.bodies_for)
			bodies.append(_entry(other, seen[other], false))
		_smp.send_bytes(SnapshotCodec.encode(tick, bodies), peer,
			MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, NetChannels.STATE)


## `id` is the viewer's handle for the body; the own entry carries the viewer's own player ID.
func _entry(player_id: int, id: int, own: bool) -> Dictionary:
	var p: PlayerState = _players[player_id]
	var e := {"id": id, "pos": p.body.global_position, "yaw": p.frame.yaw, "gait": _gait(p.frame)}
	if own:
		e["own"] = true
		e["seq"] = p.ack_seq
		e["vel"] = p.body.velocity
		e["on_floor"] = p.body.is_on_floor()
		e["scale"] = p.modifiers.effective_scale()
		e["restores"] = p.restores
	return e


## The rebound client starts a new puppet map: re-issue every handle (ADR-0004 §9).
func _on_rejoined(player_id: int, _new_peer_id: int) -> void:
	scope.reset_viewer(player_id)


func _gait(f: InputFrame) -> int:
	if f.crouch:
		return GAIT_CROUCH
	if f.move.is_zero_approx():
		return GAIT_IDLE
	return GAIT_SPRINT if f.sprint else GAIT_WALK


## True (and the player restored, its restore counter raised) when the capsule overlaps static
## geometry or the body's position or velocity is not finite.
func _restore_if_inside(p: PlayerState) -> bool:
	if p.body.global_position.is_finite() and p.body.velocity.is_finite():
		if p.probe == null:
			return false
		var live := p.shape_node.shape as CapsuleShape3D
		var cap := p.probe.shape as CapsuleShape3D
		cap.radius = live.radius - PROBE_SHRINK_M
		cap.height = live.height - 2.0 * PROBE_SHRINK_M
		p.probe.transform = p.body.global_transform * p.shape_node.transform
		if p.body.get_world_3d().direct_space_state.intersect_shape(p.probe, 1).is_empty():
			return false
	p.body.global_position = p.last_valid
	p.body.velocity = Vector3.ZERO
	p.restores = (p.restores + 1) % 256
	return true


func _on_packet(peer_id: int, bytes: PackedByteArray) -> void:
	var pid := _net.player_id_of(peer_id)
	if pid == -1 or not _players.has(pid):
		unknown_peer_drops += 1
		return
	if bytes.size() > _knobs.net.input_packet_cap_bytes:
		oversize_drops += 1
		_record("oversize input packet: %d B" % bytes.size())
		return
	var packet: Variant = bytes_to_var(bytes)
	if not packet is Dictionary:
		malformed_drops += 1
		_record("input packet is not a Dictionary")
		return
	_players[pid].queue.push(packet)


func _record(msg: String) -> void:
	if violations.size() < MAX_RECORDED_VIOLATIONS:
		violations.append(msg)
