# Story controller-interaction/011: server authority, input timeout and round-end freeze
# (first-person-controller.md Edge Cases and AC "Authority", "RoundEnded"; ADR-0002 §4-6, ADR-0008 §3).
# A real RoundServer runs ServerMovement (real PlayerBody, real MovementStep) and ControllerAuthority
# (HoldService) in the HOLDS slot; input arrives as packets pushed into each player's InputQueue, the
# same path SceneMultiplayer.peer_packet feeds. RoundLifecycle's freeze hook is stood in by a module in
# the MATCH_FLOW_RESOLVE slot, the slot RoundLifecycle calls it from.
extends GdUnitTestSuite

const A := 1
const B := 2
const HOLD_S := 5.0 ## longer than every run here: a hold never completes on its own
const RANGE_M := 100.0 ## movement never breaks range here
const EPS := 1e-3

var _knobs: Knobs
var _world: Node3D
var _server: RoundServer
var _net: NetAuthority
var _sm: ServerMovement
var _holds: HoldService
var _ctl: ControllerAuthority
var _at: At
var _bodies: Dictionary[int, PlayerBody] = {}
var _stubs: Dictionary[int, Stub] = {}
var _seq: Dictionary[int, int] = {}
var _saved_hz := 0


## Logs "start:<actor>", "complete:<actor>", "cancel:<actor>:<reason>".
class Stub extends Interactable:
	var log: Array[String] = []

	func eligible(_actor: int) -> bool:
		return true

	func start_progress_s() -> float:
		return 0.0

	func on_start(actor: int) -> void:
		log.append("start:%d" % actor)

	func on_complete(actor: int) -> void:
		log.append("complete:%d" % actor)

	func on_cancel(actor: int, _progress_s: float, reason: StringName) -> void:
		log.append("cancel:%d:%s" % [actor, reason])


## Calls the Callable scheduled for a tick (stands in for RoundLifecycle and the connection emitter).
class At extends RefCounted:
	var _due: Dictionary[int, Callable] = {}

	func setup(_runner: TickRunner, _bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
		pass

	func at(tick: int, c: Callable) -> void:
		_due[tick] = c

	func server_tick(tick: int) -> void:
		if _due.has(tick):
			_due[tick].call()


func before_test() -> void:
	_saved_hz = Engine.physics_ticks_per_second
	_knobs = Knobs.load_all()
	_world = Node3D.new()
	add_child(_world)
	TestMoveStep.add_box(_world, Vector3(0, -0.5, 0), Vector3(60, 1, 60))
	_net = NetAuthority.new()
	_net.setup(_knobs, "test", null)
	_server = RoundServer.new()
	_sm = ServerMovement.new(_knobs, _net, SceneMultiplayer.new(), _move, PhysicsLayers.WORLD)
	_holds = HoldService.new(_knobs, _players, _sm.frames_of, _centre, _sight, _aim)
	_ctl = ControllerAuthority.new(_sm, _holds)
	_at = At.new()
	var errs := _server.start_round({TickOrder.HOLDS: _ctl, TickOrder.MATCH_FLOW_RESOLVE: _at}, _knobs)
	assert_array(errs).is_empty()
	_sm.attach(_server.tick_runner)
	_bodies = {}
	_stubs = {}
	_seq = {}
	for pid in [A, B]:
		var body := PlayerBody.new()
		body.setup(_knobs, PhysicsLayers.MOVE_SERVER)
		_world.add_child(body)
		body.global_position = Vector3(pid * 3.0, 0.0, 0.0)
		_bodies[pid] = body
		_sm.add_player(pid, body, true)
		var s := Stub.new()
		s.point = body.global_position
		s.range_m = RANGE_M
		s.duration_s = HOLD_S
		_holds.register(s)
		_stubs[pid] = s
		_seq[pid] = 0
	await get_tree().physics_frame
	await get_tree().physics_frame ## bodies and boxes are in the broadphase


func after_test() -> void:
	_sm.detach()
	_server.end_round()
	_server.free()
	_net.free()
	_world.free()
	Engine.physics_ticks_per_second = _saved_hz


func _players() -> Array:
	return [A, B]


func _centre(actor: int) -> Vector3:
	return _bodies[actor].global_position + Vector3(0.0, 0.9, 0.0)


func _sight(_actor: int, _i: Interactable) -> bool:
	return true


func _aim(actor: int) -> int:
	return _stubs[actor].net_id


## ServerMovement's step Callable: the controller's real MovementStep with the player's modifiers.
func _move(body: CharacterBody3D, frame: InputFrame, modifiers: MovementModifiers) -> void:
	var state := MovementStep.MoveState.new()
	state.modifiers = modifiers
	MovementStep.step(body, frame, state, _knobs)


## Pushes one input packet for `actor` (a client's whole message), with `extra` keys merged in.
func _send(actor: int, move: Vector2, interact: bool, sprint := false, extra := {}) -> void:
	var f := InputFrame.new()
	_seq[actor] += 1
	f.seq = _seq[actor]
	f.move = move
	f.sprint = sprint
	f.interact = interact
	f.interact_target = _stubs[actor].net_id
	var frames: Array[InputFrame] = [f]
	var packet := InputFrame.build_packet(frames)
	packet.merge(extra, true)
	_sm.queue_of(actor).push(packet)


func _tick() -> void:
	await get_tree().physics_frame
	_server.tick_runner.step()


func _now() -> int:
	return _server.tick_runner.current_tick()


func _speed(actor: int) -> float:
	var v := _bodies[actor].velocity
	return Vector2(v.x, v.z).length()


func _elapsed(actor: int) -> int:
	return _holds.hold_of(actor).get("elapsed_ticks", -1)


## Both players walk forward holding interact for `n` ticks.
func _walk_and_hold(n: int) -> void:
	for t in n:
		_send(A, Vector2(0, 1), true)
		_send(B, Vector2(0, 1), true)
		await _tick()


func _freeze_all() -> void:
	for pid in [A, B]:
		_ctl.freeze(pid)


func _drop_a() -> void:
	var e := EvPlayerConnectionChanged.new()
	e.player = A
	e.status = EvPlayerConnectionChanged.DISCONNECTED
	_server.bus.emit(e)


# --- AC1: clients send intent only ------------------------------------------------------------------

func test_client_position_speed_progress_and_done_keys_change_nothing() -> void:
	var start := _bodies[A].global_position
	var forged := {"position": Vector3(40, 0, 40), "pos": Vector3(40, 0, 40), "velocity": Vector3(0, 0, -50),
		"speed": 50.0, "progress": 99.0, "hold_progress": PackedFloat32Array([99.0]), "done": true,
		"complete": true}
	var n := 60
	for t in n:
		# move far beyond unit length, sprinting: the server caps it at the knob-driven sprint speed
		_send(A, Vector2(0, 40), true, true, forged)
		await _tick()
	var sprint := _knobs.controller.walk_speed * _knobs.controller.sprint_mult
	assert_float(_speed(A)).is_less_equal(sprint + EPS)
	assert_float(_speed(A)).is_less_equal(5.75) ## the AC's ceiling (true-form sprint)
	var travelled := _bodies[A].global_position - start
	assert_float(Vector2(travelled.x, travelled.z).length()).is_less_equal(sprint * n / 60.0 + EPS)
	assert_float(_bodies[A].global_position.distance_to(Vector3(40, 0, 40))).is_greater(30.0)
	assert_int(_elapsed(A)).is_equal(n) ## one tick of progress per tick held, whatever the client said
	assert_array(_stubs[A].log).is_equal(["start:1"]) ## no completion
	assert_int(_sm.queue_of(A).dropped_packets).is_equal(0) ## extra keys are ignored, not fatal


# --- AC2: intent timeout ----------------------------------------------------------------------------

func test_no_intent_for_450_ms_keeps_moving_and_holding() -> void:
	await _walk_and_hold(20)
	var held := _elapsed(A)
	var almost := _knobs.ticks(_knobs.controller.intent_timeout_ms * 0.9 / 1000.0) ## 450 ms
	for t in almost:
		_send(B, Vector2(0, 1), true)
		await _tick()
	assert_bool(_sm.queue_of(A).is_released()).is_false()
	assert_int(_elapsed(A)).is_equal(held + almost)
	assert_float(_speed(A)).is_greater(_knobs.controller.walk_speed - EPS)
	assert_array(_stubs[A].log).is_equal(["start:1"])


func test_no_intent_for_500_ms_stops_movement_and_cancels_the_hold_as_released() -> void:
	await _walk_and_hold(20)
	var timeout := _knobs.ticks(_knobs.controller.intent_timeout_ms / 1000.0)
	var silent := 0
	while _stubs[A].log.size() == 1 and silent < timeout + 5:
		_send(B, Vector2(0, 1), true)
		await _tick()
		silent += 1
	assert_int(silent).is_between(timeout - 1, timeout + 1)
	assert_array(_stubs[A].log).is_equal(["start:1", "cancel:1:released"])
	assert_bool(_sm.queue_of(A).is_released()).is_true()
	assert_float(_speed(A)).is_less(_knobs.controller.walk_speed) ## stopping from that tick
	for t in _knobs.ticks(_knobs.controller.accel_time_s):
		_send(B, Vector2(0, 1), true)
		await _tick()
	assert_float(_speed(A)).is_equal_approx(0.0, EPS)
	var at := _bodies[A].global_position
	_send(B, Vector2(0, 1), true)
	await _tick()
	assert_vector(_bodies[A].global_position).is_equal_approx(at, Vector3.ONE * EPS)
	assert_array(_stubs[B].log).is_equal(["start:2"]) ## B kept its intent and its hold


# --- AC3: inside geometry ---------------------------------------------------------------------------

func test_a_player_inside_geometry_is_at_the_last_valid_position_on_the_next_tick() -> void:
	TestMoveStep.add_box(_world, Vector3(20, 1, 0), Vector3(2, 2, 2))
	await _walk_and_hold(10)
	var valid := _sm.last_valid_position_of(A)
	assert_vector(valid).is_equal_approx(_bodies[A].global_position, Vector3.ONE * EPS)
	_bodies[A].global_position = Vector3(20, 0, 0) ## inside the box
	_send(A, Vector2.ZERO, true)
	_send(B, Vector2.ZERO, true)
	await _tick()
	assert_vector(_bodies[A].global_position).is_equal_approx(valid, Vector3.ONE * EPS)


# --- AC4: RoundEnded and disconnect -----------------------------------------------------------------

func test_round_ended_stops_movement_cancels_every_hold_and_ignores_further_intent() -> void:
	await _walk_and_hold(10)
	_at.at(_now() + 1, _freeze_all)
	await _walk_and_hold(1)
	assert_array(_stubs[A].log).is_equal(["start:1", "cancel:1:round_ended"])
	assert_array(_stubs[B].log).is_equal(["start:2", "cancel:2:round_ended"])
	for pid in [A, B]:
		assert_float(_speed(pid)).is_equal(0.0)
		assert_dict(_holds.hold_of(pid)).is_empty()
	var at := {A: _bodies[A].global_position, B: _bodies[B].global_position}
	for t in 10: ## release, then press again: a fresh Start and movement, both ignored
		_send(A, Vector2(1, 1), t > 0, true)
		_send(B, Vector2(-1, 1), t > 0)
		await _tick()
	for pid in [A, B]:
		assert_vector(_bodies[pid].global_position).is_equal_approx(at[pid], Vector3.ONE * EPS)
		assert_dict(_holds.hold_of(pid)).is_empty()
	assert_int(_stubs[A].log.size()).is_equal(2)
	assert_int(_stubs[B].log.size()).is_equal(2)


func test_disconnect_cancels_that_players_hold_only() -> void:
	await _walk_and_hold(10)
	_at.at(_now() + 1, _drop_a)
	await _walk_and_hold(1)
	assert_array(_stubs[A].log).is_equal(["start:1", "cancel:1:disconnected"])
	assert_array(_stubs[B].log).is_equal(["start:2"])
	assert_int(_elapsed(B)).is_equal(11)
