# Story network-authority/006: snapshots, owner prediction and reconciliation.
# Integration: the server and every client are separate SceneMultiplayer subtrees in this one process
# over real ENet sockets on 127.0.0.1, each client behind a UdpLink (delay, jitter, loss).
# The test drives ticks by hand (TickRunner.step), one per physics frame: ENet measures round trips and
# throttles on the wall clock, so ticks are paced to real time and the link delays count in tick time.
extends GdUnitTestSuite

const SERVER_VERSION := "test-1.0+aaaa1111"
const WAIT_S := 5.0
const HOST_ID := 100 ## the host's own player; NetAuthority hands out 0, 1, 2 ... to remote players
const WORLD_SIZE := 400.0
const LINK_DELAY_S := 0.075 ## 75 ms each way = 150 ms RTT (ADR-0002 Validation Criteria)
const LINK_JITTER_S := 0.030
const LINK_LOSS := 0.02
const HORIZONTAL_TOLERANCE_M := 0.001 ## a fifth of the correction deadzone: invisible to any client
const RESTORE_DROPPED_DATAGRAMS := 3
const PROCESS_FRAME_PREDICTED := 30
const PROCESS_FRAME_ACKED := 20
const LIP_REPLAY_TOLERANCE_M := 0.01 ## see the clean-link test; the ADR spike measured 1.6 mm on a 40° lip
const AC1_TICKS := 1600 ## about 27 s; at most one snapshot applies per tick, so ~5300 states
const AC1_CLIENTS := 5
const AC1_MAX_CORRECTIONS := 53 ## the spike's 53 corrections ...
const AC1_STATES := 5022 ## ... per 5022 states
const AC1_SNAP_P95_M := 0.35
const AC1_MIN_STATES := 5022 ## at least the spike's sample, and no empty ratio on a dead link
const SETTLE_TICKS := 120
const LONG_RUNNING_MS := 60000

static var _next_port := 25100

class FakeLobby extends RefCounted:
	func state() -> StringName:
		return &"waiting"

	func player_count() -> int:
		return 0

var _knobs: Knobs
var _saved_hz: int
var _dt: float
var _now: float = 0.0
var _uid := 0
var _world: Node3D
var _server_root: Node
var _server_net: NetAuthority
var _server_api: SceneMultiplayer
var _runner: TickRunner
var _sm: ServerMovement
var _server_bodies: Dictionary = {}
var _joined: Array[int] = []
var _clients: Array[Dictionary] = []
var _roots: Array[Node] = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_saved_hz = Engine.physics_ticks_per_second
	_dt = 1.0 / float(_knobs.net.sim_tick_hz)
	_now = 0.0
	_joined.clear()
	_clients.clear()
	_server_bodies.clear()


func after_test() -> void:
	for c in _clients:
		c.predictor.close()
		c.link.stop()
	if _sm != null:
		_sm.detach()
	for r in _roots:
		for n in r.get_children():
			if n is NetAuthority:
				n.close()
		var api := r.multiplayer as SceneMultiplayer
		if api.multiplayer_peer != null:
			api.multiplayer_peer.close()
		api.multiplayer_peer = null
		api.auth_callback = Callable()
		get_tree().set_multiplayer(null, r.get_path())
		r.free()
	_roots.clear()
	_clients.clear()
	_sm = null
	if _runner != null:
		_runner.free()
		_runner = null
	if _world != null:
		_world.free()
		_world = null
	Engine.physics_ticks_per_second = _saved_hz


# --- rig ---------------------------------------------------------------------

func _port() -> int:
	_next_port += 1
	return _next_port


func _root() -> Node:
	_uid += 1
	var n := Node.new()
	n.name = "Pr%d" % _uid
	get_tree().root.add_child(n)
	get_tree().set_multiplayer(SceneMultiplayer.new(), n.get_path())
	_roots.append(n)
	return n


func _spawn(player_id: int) -> Vector3:
	return Vector3(float(player_id) * 2.0, 0.0, -1.0)


## Floor, a 40 degree ramp, a plateau after it (a drop beyond), and a 0.35 m step further on.
func _build_world() -> void:
	_world = Node3D.new()
	get_tree().root.add_child(_world)
	TestMoveStep.add_box(_world, Vector3(0, -0.5, 0), Vector3(WORLD_SIZE, 1.0, WORLD_SIZE))
	TestMoveStep.add_wedge(_world, 2.0, 40.0, 0.8)
	var ramp_end := 2.0 + 0.8 / tan(deg_to_rad(40.0))
	TestMoveStep.add_box(_world, Vector3(0, 0.3, (ramp_end + 6.0) / 2.0), Vector3(4, 1.0, 6.0 - ramp_end))
	TestMoveStep.add_box(_world, Vector3(0, 0.175, 9.5), Vector3(4, 0.35, 1.0))
	await get_tree().physics_frame
	await get_tree().physics_frame


func _start_server() -> void:
	_server_root = _root()
	_server_net = NetAuthority.new()
	_server_net.setup(_knobs, SERVER_VERSION, FakeLobby.new())
	_server_root.add_child(_server_net)
	var port := _port()
	assert_int(_server_net.host(port)).is_equal(OK)
	_server_net.player_joined.connect(_on_joined)
	_server_api = _server_root.multiplayer as SceneMultiplayer
	_runner = TickRunner.new() ## not in the tree: the test calls step()
	_runner.fail_hard = false
	_runner.boot(_knobs)
	_sm = ServerMovement.new(_knobs, _server_net, _server_api, TestMoveStep.apply, TestMoveStep.WORLD)
	_sm.attach(_runner)
	_server_net.set_meta("port", port)


func _on_joined(player_id: int) -> void:
	_joined.append(player_id)
	_server_bodies[player_id] = TestMoveStep.make_body(_server_root, _spawn(player_id))
	_sm.add_player(player_id, _server_bodies[player_id])


## Adds `count` clients behind clean links and waits until each is joined; then builds predictors.
func _add_clients(count: int, seed_base: int = 1000) -> void:
	var start := _clients.size()
	for i in count:
		var root := _root()
		var net := NetAuthority.new()
		net.setup(_knobs, SERVER_VERSION, FakeLobby.new())
		root.add_child(net)
		var link := UdpLink.new(seed_base + start + i)
		var listen := _port()
		assert_int(link.start(listen, _server_net.get_meta("port"))).is_equal(OK)
		assert_int(net.join("127.0.0.1", listen, "P%d" % (start + i))).is_equal(OK)
		_clients.append({"net": net, "root": root, "link": link})
	await _until(func() -> bool:
		if _joined.size() < start + count:
			return false
		for i in range(start, start + count):
			if _clients[i].net.local_token == "":
				return false
		return true, "all clients joined")
	for i in range(start, start + count):
		var c: Dictionary = _clients[i]
		var pid: int = c.net.local_player_id
		var body := TestMoveStep.make_body(c.root, _spawn(pid))
		var visual := Node3D.new()
		body.add_child(visual)
		c["pid"] = pid
		c["body"] = body
		c["visual"] = visual
		c["predictor"] = OwnerPredictor.new(_knobs, body, visual, TestMoveStep.apply, c.root.multiplayer as SceneMultiplayer)


func _condition_links(delay_s: float, jitter_s: float, loss: float) -> void:
	for c in _clients:
		c.link.delay_s = delay_s
		c.link.jitter_s = jitter_s
		c.link.loss = loss


func _until(cond: Callable, what: String) -> void:
	var end := Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while Time.get_ticks_msec() < end:
		_pump()
		if cond.call():
			return
		await get_tree().process_frame
	assert_bool(cond.call()).override_failure_message("timeout waiting for " + what).is_true()


func _pump() -> void:
	for c in _clients:
		c.link.pump(_now)


func _poll_clients() -> void:
	for c in _clients:
		(c.root.multiplayer as SceneMultiplayer).poll()


## One server tick of virtual time. frames[i] is client i's input this tick (a shorter array leaves
## the rest idle). The order is: clients predict and send, links carry, server polls and steps,
## links carry, clients poll (receive snapshots and reconcile).
func _tick(frames: Array[InputFrame] = []) -> void:
	await get_tree().physics_frame ## real-time pace: ENet measures round trips and bandwidth on the wall clock
	_now += _dt
	for i in frames.size():
		_clients[i].predictor.predict(frames[i])
	_poll_clients()
	_pump()
	_server_api.poll()
	_runner.step()
	_server_api.poll()
	_pump()
	_poll_clients()
	for c in _clients:
		c.predictor.apply_pending() ## still inside the physics frame awaited above
		c.predictor.advance_visual(_dt)


func _ticks(n: int) -> void:
	for i in n:
		await _tick()


# --- scripted input ----------------------------------------------------------

func _frame(move: Vector2, yaw: float) -> InputFrame:
	var f := InputFrame.new()
	f.move = move
	f.yaw = yaw
	return f


## Segments [ticks, move, yaw] expanded to one [move, yaw] per tick.
func _expand(segments: Array) -> Array:
	var out: Array = []
	for s in segments:
		for i in s[0]:
			out.append([s[1], s[2]])
	return out


## Up the ramp, along the plateau, off its edge, into the step, along it, back across the floor.
func _ramp_route() -> Array:
	return _expand([
		[300, Vector2(0, 1), PI],
		[60, Vector2(1, 0), PI],
		[60, Vector2(0.7, 0.7), PI / 2.0],
		[120, Vector2(0, -1), PI],
		[90, Vector2.ZERO, PI],
	])


## Seeded random walk: new heading and speed every 20 to 60 ticks, sometimes standing still.
func _random_route(seed_value: int, n: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array = []
	var move := Vector2.ZERO
	var yaw := 0.0
	var left := 0
	for i in n:
		if left == 0:
			left = rng.randi_range(20, 60)
			yaw += rng.randf_range(-1.0, 1.0)
			move = Vector2.ZERO if rng.randf() < 0.15 else Vector2.from_angle(rng.randf() * TAU)
		left -= 1
		out.append([move, yaw])
	return out


func _p95(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var s := values.duplicate()
	s.sort()
	return s[maxi(0, ceili(0.95 * s.size()) - 1)]


func _totals(key: String) -> int:
	var t := 0
	for c in _clients:
		t += c.predictor.get(key)
	return t


# --- tests -------------------------------------------------------------------

func test_five_clients_at_150ms_rtt_30ms_jitter_2pct_loss_stay_within_correction_budget(timeout: int = LONG_RUNNING_MS) -> void:
	# Long-running: 5 real ENet clients x AC1_TICKS ticks.
	await _build_world()
	_start_server()
	await _add_clients(AC1_CLIENTS)
	_condition_links(LINK_DELAY_S, LINK_JITTER_S, LINK_LOSS)
	var routes: Array = []
	for i in AC1_CLIENTS:
		routes.append(_random_route(77 + i, AC1_TICKS))
	var t0 := Time.get_ticks_msec()
	for t in AC1_TICKS:
		var frames: Array[InputFrame] = []
		for i in AC1_CLIENTS:
			frames.append(_frame(routes[i][t][0], routes[i][t][1]))
		await _tick(frames)
	var wall_ms := Time.get_ticks_msec() - t0
	var states := _totals("states_received")
	var corrections := _totals("corrections")
	var mags: Array[float] = []
	for c in _clients:
		mags.append_array(c.predictor.correction_magnitudes)
	var p95 := _p95(mags)
	var offset: float = _clients[0].predictor.estimator.offset_ticks()
	print("AC1: states=%d corrections=%d snaps=%d p95=%.4f m max=%.4f m wall=%d ms offset=%.2f ticks dropped=%d bad=%d oversize=%d" % [
		states, corrections, _totals("snaps"), p95, mags.max() if not mags.is_empty() else 0.0, wall_ms, offset,
		_clients[0].link.dropped, _totals("bad_snapshots"), _sm.oversize_drops])
	assert_int(states).is_greater(AC1_MIN_STATES)
	assert_bool(corrections * AC1_STATES <= AC1_MAX_CORRECTIONS * states) \
		.override_failure_message("%d corrections in %d states exceeds %d per %d" % [corrections, states, AC1_MAX_CORRECTIONS, AC1_STATES]).is_true()
	assert_float(p95).is_less(AC1_SNAP_P95_M)
	assert_int(_sm.oversize_drops + _sm.malformed_drops + _sm.unknown_peer_drops).is_equal(0)
	assert_int(_totals("bad_snapshots")).is_equal(0)
	# One way is 4.5 ticks; the lowest-delay path sits a little under that.
	assert_float(offset).is_between(2.0, 6.0)


func test_clean_link_replay_over_step_and_ramp_geometry_shows_no_snap() -> void:
	await _build_world()
	_start_server()
	await _add_clients(1)
	_condition_links(LINK_DELAY_S, 0.0, 0.0)
	var route := _ramp_route()
	var peak_y := 0.0
	for r in route:
		await _tick([_frame(r[0], r[1])] as Array[InputFrame])
		peak_y = maxf(peak_y, _clients[0].body.global_position.y)
	await _ticks(SETTLE_TICKS)
	var p: OwnerPredictor = _clients[0].predictor
	assert_float(peak_y).is_greater(0.5) ## it really climbed the ramp
	assert_int(p.states_received).is_greater(route.size())
	assert_int(p.snaps).is_equal(0) ## the AC: no snap on a clean link
	# Replay at the ramp-to-plateau lip differs from the predicted path by up to about 6 mm (5.8 mm
	# measured 2026-10-13, over the 5 mm deadzone): at most a sub-centimetre smooth correction there.
	for m in p.correction_magnitudes:
		assert_float(m).is_less(LIP_REPLAY_TOLERANCE_M)
	assert_vector(_clients[0].body.global_position).is_equal_approx(_server_bodies[_clients[0].pid].global_position, Vector3.ONE * _knobs.net.correction_deadzone_m)


func test_host_and_remote_client_end_with_identical_server_positions() -> void:
	await _build_world()
	_start_server()
	await _add_clients(1)
	_condition_links(LINK_DELAY_S, 0.0, 0.0)
	_server_bodies[HOST_ID] = TestMoveStep.make_body(_server_root, _spawn(_clients[0].pid))
	_sm.add_player(HOST_ID, _server_bodies[HOST_ID], true)
	var route := _ramp_route()
	for i in route.size():
		var hf := _frame(route[i][0], route[i][1])
		hf.seq = i + 1
		_sm.push_local(HOST_ID, hf)
		await _tick([_frame(route[i][0], route[i][1])] as Array[InputFrame])
	await _ticks(SETTLE_TICKS)
	var host_pos: Vector3 = _server_bodies[HOST_ID].global_position
	var remote_pos: Vector3 = _server_bodies[_clients[0].pid].global_position
	assert_float(host_pos.distance_to(_spawn(_clients[0].pid))).is_greater(1.0) ## both really moved
	assert_int(_sm.ack_seq_of(HOST_ID)).is_equal(route.size())
	assert_int(_sm.ack_seq_of(_clients[0].pid)).is_equal(route.size())
	# Not bit-identical: a resting CharacterBody3D sits anywhere within its safe margin of the contact
	# (-0.19 mm to +0.84 mm measured), and that changes the slope contact, so after this route x and z
	# differ by about 0.19 mm (measured 2026-10-13/14 over 12 runs). Before TestMoveStep skipped the
	# resting step, the remote's extra idle steps while its first frames were in flight made the step
	# corner diverge by metres in about 1 run in 6; the real controller step should keep that property.
	assert_float(Vector2(host_pos.x, host_pos.z).distance_to(Vector2(remote_pos.x, remote_pos.z))).is_less(HORIZONTAL_TOLERANCE_M)
	assert_float(absf(host_pos.y - remote_pos.y)).is_less_equal(2.0 * _server_bodies[HOST_ID].safe_margin)


func test_player_pushed_inside_geometry_is_restored_and_owner_takes_the_snap_path() -> void:
	await _build_world()
	_start_server()
	await _add_clients(1)
	_condition_links(LINK_DELAY_S, 0.0, 0.0)
	await _ticks(60)
	var pid: int = _clients[0].pid
	var body: CharacterBody3D = _server_bodies[pid]
	var valid := _sm.last_valid_position_of(pid)
	var p: OwnerPredictor = _clients[0].predictor
	assert_int(p.snaps).is_equal(0)
	body.global_position = Vector3(0, 0.4, 4.4) ## inside the plateau box
	# Lose the snapshots right after the restore: the counter in every later one still carries it.
	_clients[0].link.drop_next_down = RESTORE_DROPPED_DATAGRAMS
	await _ticks(1)
	assert_vector(body.global_position).is_equal_approx(valid, Vector3.ONE * 0.01)
	assert_vector(_sm.last_valid_position_of(pid)).is_equal(valid)
	await _ticks(SETTLE_TICKS)
	# The client never moved, so the error is under the deadzone: only the restore counter can snap.
	assert_int(p.snaps).is_equal(1)
	assert_float(p.snap_magnitudes[0]).is_less(_knobs.net.correction_deadzone_m)
	assert_vector(p.visual_offset()).is_equal(Vector3.ZERO)
	await _ticks(SETTLE_TICKS)
	assert_int(p.snaps).is_equal(1) ## the unchanged counter in later snapshots does not snap again


func test_loss_burst_of_five_packets_recovers_without_a_permanent_offset() -> void:
	await _build_world()
	_start_server()
	await _add_clients(1)
	_condition_links(LINK_DELAY_S, 0.0, 0.0)
	var link: UdpLink = _clients[0].link
	var route := _random_route(5, 300)
	var p: OwnerPredictor = _clients[0].predictor
	for t in route.size():
		if t == 100:
			link.drop_next_up = 5
			link.drop_next_down = 5
		await _tick([_frame(route[t][0], route[t][1])] as Array[InputFrame])
	await _ticks(SETTLE_TICKS)
	assert_int(link.dropped).is_greater_equal(10)
	assert_int(p.corrections).is_greater(0) ## the burst did cost frames
	assert_vector(_clients[0].body.global_position).is_equal_approx(_server_bodies[_clients[0].pid].global_position, Vector3.ONE * _knobs.net.correction_deadzone_m)
	assert_int(p.unacked_count()).is_less(3)


func test_reconcile_with_an_empty_input_buffer_applies_the_server_state() -> void:
	await _build_world()
	var body := TestMoveStep.make_body(_world, _spawn(0))
	var visual := Node3D.new()
	body.add_child(visual)
	var p := OwnerPredictor.new(_knobs, body, visual, TestMoveStep.apply, null)
	for i in 3:
		p.predict(_frame(Vector2(0, 1), 0.0))
	assert_int(p.unacked_count()).is_equal(3)
	var here := body.global_position
	_deliver(p, SnapshotCodec.encode(5, [_own_entry(here, 3)] as Array[Dictionary]))
	assert_int(p.unacked_count()).is_equal(0) ## nothing left to replay
	assert_int(p.corrections).is_equal(0)
	# Server says the body is 0.5 m away: smooth path, exactly one correction, the offset hides it.
	_deliver(p, SnapshotCodec.encode(6, [_own_entry(here + Vector3(0.5, 0, 0), 3)] as Array[Dictionary]))
	assert_int(p.corrections).is_equal(1)
	assert_int(p.snaps).is_equal(0)
	assert_float(body.global_position.x).is_equal_approx(here.x + 0.5, 0.01)
	assert_float(p.visual_offset().x).is_equal_approx(-0.5, 0.01)
	p.advance_visual(_knobs.net.correction_smooth_s)
	assert_vector(p.visual_offset()).is_equal_approx(Vector3.ZERO, Vector3.ONE * 0.001)
	# Beyond correction_smooth_max_m it snaps.
	_deliver(p, SnapshotCodec.encode(7, [_own_entry(here + Vector3(5, 0, 0), 3)] as Array[Dictionary]))
	assert_int(p.snaps).is_equal(1)
	assert_float(p.snap_magnitudes[0]).is_greater(_knobs.net.correction_smooth_max_m)
	assert_vector(p.visual_offset()).is_equal(Vector3.ZERO)
	body.free()


func test_snapshot_with_an_older_or_equal_tick_is_ignored() -> void:
	await _build_world()
	var body := TestMoveStep.make_body(_world, _spawn(0))
	var visual := Node3D.new()
	body.add_child(visual)
	var p := OwnerPredictor.new(_knobs, body, visual, TestMoveStep.apply, null)
	var here := body.global_position
	_deliver(p, SnapshotCodec.encode(10, [_own_entry(here + Vector3(0.2, 0, 0), 0)] as Array[Dictionary]))
	var after_first := body.global_position
	_deliver(p, SnapshotCodec.encode(9, [_own_entry(here + Vector3(0.6, 0, 0), 0)] as Array[Dictionary]))
	_deliver(p, SnapshotCodec.encode(10, [_own_entry(here + Vector3(0.6, 0, 0), 0)] as Array[Dictionary]))
	_deliver(p, PackedByteArray([1, 2, 3]))
	assert_int(p.states_received).is_equal(1)
	assert_int(p.stale_ignored).is_equal(2)
	assert_int(p.bad_snapshots).is_equal(1)
	assert_vector(body.global_position).is_equal(after_first)
	# Two arrive before the physics frame: the newer one is kept, the older counted stale.
	p.receive(SnapshotCodec.encode(12, [_own_entry(here + Vector3(0.3, 0, 0), 0)] as Array[Dictionary]))
	p.receive(SnapshotCodec.encode(11, [_own_entry(here + Vector3(0.6, 0, 0), 0)] as Array[Dictionary]))
	p.apply_pending()
	assert_int(p.states_received).is_equal(2)
	assert_int(p.stale_ignored).is_equal(3)
	assert_float(body.global_position.x).is_equal_approx(here.x + 0.3, 0.01)
	body.free()


func _own_entry(pos: Vector3, seq: int) -> Dictionary:
	return {"id": 0, "pos": pos, "yaw": 0.0, "gait": 0, "own": true, "seq": seq, "vel": Vector3.ZERO,
		"on_floor": true, "scale": 1.0, "restores": 0}


## Buffers `bytes` and applies it at once (these tests drive the predictor without a network).
func _deliver(p: OwnerPredictor, bytes: PackedByteArray) -> void:
	p.receive(bytes)
	p.apply_pending()


func test_snapshot_received_outside_the_physics_frame_replays_with_the_physics_delta() -> void:
	# The tree polls the multiplayer API in the idle frame; move_and_slide() there would use the frame
	# delta and replay the wrong distance. The predictor buffers and replays in the physics frame.
	await _build_world()
	var body := TestMoveStep.make_body(_world, _spawn(0))
	var visual := Node3D.new()
	body.add_child(visual)
	var server := TestMoveStep.make_body(_world, _spawn(0) + Vector3(0, 0, -20))
	var p := OwnerPredictor.new(_knobs, body, visual, TestMoveStep.apply, null)
	var mods := MovementModifiers.new()
	for i in PROCESS_FRAME_PREDICTED:
		await get_tree().physics_frame
		var f := _frame(Vector2(0, 1), 0.0)
		p.predict(f)
		if i < PROCESS_FRAME_ACKED:
			TestMoveStep.apply(server, f, mods)
	var entry := _own_entry(server.global_position + Vector3(0, 0, 20), PROCESS_FRAME_ACKED)
	entry["vel"] = server.velocity
	await get_tree().process_frame
	assert_bool(Engine.is_in_physics_frame()).is_false()
	p.receive(SnapshotCodec.encode(1, [entry] as Array[Dictionary]))
	await get_tree().physics_frame
	p.apply_pending()
	assert_int(p.states_received).is_equal(1)
	assert_int(p.corrections).is_equal(0)
	server.free()
	body.free()


func test_position_history_returns_null_for_unrecorded_and_negative_ticks() -> void:
	await _build_world()
	_start_server()
	await _add_clients(1)
	await _ticks(5)
	var pid: int = _clients[0].pid
	var now := _runner.current_tick()
	assert_vector(_sm.position_at(pid, now)).is_equal(_server_bodies[pid].global_position)
	assert_that(_sm.position_at(pid, -1)).is_null() ## unrecorded slots hold tick -1
	assert_that(_sm.position_at(pid, now + 1)).is_null()
