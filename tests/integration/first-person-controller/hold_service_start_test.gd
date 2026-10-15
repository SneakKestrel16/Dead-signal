# Story controller-interaction/008: HoldService Start, contested locks and completion (ADR-0008 §1-4,
# first-person-controller.md rules 11-16). Stub Interactables log their callbacks; actors are plain
# player IDs whose frames, centres and sight the test feeds. The line-of-sight ray itself
# (MapQueries.clear_line) runs against real static bodies at the end.
extends GdUnitTestSuite

const A := 1
const B := 2
const HOLD_S := 0.5 ## 30 ticks at the shipped 60 Hz

var _knobs: Knobs
var _holds: HoldService
## actor -> Array[InputFrame] fed to the next server_tick
var _feed: Dictionary = {}
var _centres: Dictionary = {}
var _blind: Dictionary = {} ## actor -> true: sight fails
var _bodies: Dictionary = {} ## handle -> net id, for body targets
var _aimed: Dictionary = {} ## actor -> net id the server's ray picks; absent = the latest claimed target
var _tick := 0


## Logs every callback as "start:<actor>", "complete:<actor>", "cancel:<actor>:<progress>:<reason>".
## on_start keeps the parent's void and needs no return (ADR-0008 Verification 1: this file compiles).
class Stub extends Interactable:
	var log: Array[String] = []
	var allowed := true
	var stored_s := 0.0

	func eligible(_actor: int) -> bool:
		return allowed

	func start_progress_s() -> float:
		return stored_s

	func on_start(actor: int) -> void:
		log.append("start:%d" % actor)

	func on_complete(actor: int) -> void:
		log.append("complete:%d" % actor)

	func on_cancel(actor: int, progress_s: float, reason: StringName) -> void:
		log.append("cancel:%d:%.2f:%s" % [actor, progress_s, reason])


func before_test() -> void:
	_knobs = Knobs.load_all()
	_feed = {}
	_centres = {A: Vector3.ZERO, B: Vector3.ZERO}
	_blind = {}
	_bodies = {}
	_aimed = {}
	_tick = 0
	_holds = HoldService.new(_knobs, func() -> Array: return _centres.keys(),
		func(actor: int) -> Array: return _feed.get(actor, []),
		func(actor: int) -> Vector3: return _centres[actor],
		func(actor: int, _i: Interactable) -> bool: return not _blind.has(actor),
		func(actor: int) -> int: return _aimed[actor] if _aimed.has(actor) else _claimed(actor),
		func(_actor: int, handle: int) -> int: return _bodies.get(handle, -1))


## The last pressed net-id target in the actor's frames: by default the server's ray agrees.
func _claimed(actor: int) -> int:
	var id := -1
	for f: InputFrame in _feed.get(actor, []):
		if f.interact:
			id = f.interact_target
	return id


func _stub(duration_s := HOLD_S, lock := &"", range_m := 1.5) -> Stub:
	var s := Stub.new()
	s.point = Vector3(0.0, 0.0, -1.0)
	s.range_m = range_m
	s.duration_s = duration_s
	s.lock_key = lock
	_holds.register(s)
	return s


func _f(interact: bool, target := 0, is_body := false) -> InputFrame:
	var f := InputFrame.new()
	f.interact = interact
	f.interact_target = target
	f.target_is_body = is_body
	return f


## One server tick; `frames` maps actor -> Array of its frames this tick (an actor absent keeps
## its last frame, as the queue's starvation repeat does).
func _step(frames: Dictionary = {}) -> void:
	for actor: int in frames:
		_feed[actor] = frames[actor]
	_holds.server_tick(_tick)
	_tick += 1


func _press(actor: int, target := 0) -> void:
	_step({actor: [_f(true, target)]})


# --- AC1: rejected Starts --------------------------------------------------------

func test_ineligible_actor_is_rejected_and_has_no_hold() -> void:
	var s := _stub()
	s.allowed = false ## shocked, hidden, Downed or wrong role: the owner's eligible() says no
	_press(A)
	assert_array(s.log).is_empty()
	assert_dict(_holds.hold_of(A)).is_empty() ## the snapshot shows no hold: the client bar cancels


func test_blocked_line_of_sight_is_rejected() -> void:
	var s := _stub()
	_blind[A] = true
	_press(A)
	assert_array(s.log).is_empty()
	assert_dict(_holds.hold_of(A)).is_empty()


func test_start_range_is_strict_range_m() -> void:
	var s := _stub(HOLD_S, &"", 1.0) # point 1.0 m away: exactly at range
	_press(A)
	assert_array(s.log).is_equal(["start:%d" % A])
	var far := _stub(HOLD_S, &"", 0.99)
	_press(B, far.net_id)
	assert_array(far.log).is_empty()


func test_exclusive_lock_held_by_another_actor_rejects() -> void:
	var s := _stub(HOLD_S, &"door_3")
	var other := _stub(HOLD_S, &"door_3") # barricade and break share the door's key
	_press(A, s.net_id)
	_press(B, other.net_id)
	assert_array(other.log).is_empty()
	assert_dict(_holds.hold_of(B)).is_empty()
	assert_int(_holds.hold_of(A).net_id).is_equal(s.net_id)


func test_target_minus_one_or_out_of_range_is_rejected() -> void:
	var s := _stub()
	_press(A, -1)
	_step({A: [_f(false)]})
	_press(A, 99)
	assert_array(s.log).is_empty()


func test_body_target_resolves_through_the_handle_table() -> void:
	var s := _stub()
	_bodies[7001] = s.net_id
	_step({A: [_f(true, 7001, true)]})
	assert_array(s.log).is_equal(["start:%d" % A])
	_step({B: [_f(true, 7002, true)]}) # a handle naming no body
	assert_dict(_holds.hold_of(B)).is_empty()


# --- AC2: contested lock in rotated order (ADR-0008 Verification 3) --------------

func test_two_starts_on_one_lock_in_one_tick_go_to_the_first_in_rotated_order() -> void:
	for case: Array in [[0, A], [1, B]]: # tick 0 orders [1, 2]; tick 1 rotates to [2, 1]
		before_test()
		var s := _stub(HOLD_S, &"drive_slot")
		var start_tick: int = case[0]
		var first: int = case[1]
		_tick = start_tick
		_step({A: [_f(true, s.net_id)], B: [_f(true, s.net_id)]})
		assert_array(s.log).override_failure_message("tick %d" % start_tick).is_equal(["start:%d" % first])
		assert_dict(_holds.hold_of(A if first == B else B)).is_empty()


func test_rotation_moves_one_place_per_tick() -> void:
	assert_array(HoldService.rotated([3, 1, 2], 0)).is_equal([1, 2, 3])
	assert_array(HoldService.rotated([3, 1, 2], 1)).is_equal([2, 3, 1])
	assert_array(HoldService.rotated([3, 1, 2], 5)).is_equal([3, 1, 2])


# --- AC3: Stop before acceptance -------------------------------------------------

func test_press_and_release_in_one_tick_is_accepted_then_cancelled_at_zero() -> void:
	var s := _stub()
	_step({A: [_f(true), _f(false)]}) # a catch-up tick consumed both frames
	assert_array(s.log).is_equal(["start:%d" % A, "cancel:%d:0.00:released" % A])
	assert_dict(_holds.hold_of(A)).is_empty()


# --- AC4: timing -----------------------------------------------------------------

func test_hold_completes_once_on_the_tick_elapsed_reaches_duration() -> void:
	var s := _stub()
	var d := _knobs.ticks(HOLD_S)
	_press(A)
	var done_at := -1
	var start_tick := _tick - 1
	for i in d + 10: # keep holding: the repeat frame stays pressed
		if s.log.has("complete:%d" % A) and done_at == -1:
			done_at = _tick - 1 # the tick that just ran
		_step()
	assert_int(s.log.count("complete:%d" % A)).is_equal(1)
	# The Start tick counts as the first elapsed tick, so tick start + d - 1 has elapsed d.
	assert_int(done_at - start_tick).is_equal(d - 1)
	assert_dict(_holds.hold_of(A)).is_empty()


func test_instant_completes_on_the_start_tick_and_takes_no_lock() -> void:
	var door := _stub(0.0, &"door_1")
	var barricade := _stub(HOLD_S, &"door_1")
	_step({A: [_f(true, door.net_id)], B: [_f(true, barricade.net_id)]})
	assert_array(door.log).is_equal(["start:%d" % A, "complete:%d" % A])
	assert_dict(_holds.hold_of(A)).is_empty()
	assert_array(barricade.log).is_equal(["start:%d" % B]) # the instant took no lock


## Code review 2026-10-14: an instant on a key another actor holds ran anyway (AC1: a held lock rejects).
func test_instant_is_rejected_while_another_actor_holds_its_lock() -> void:
	var barricade := _stub(HOLD_S, &"door_1")
	var door := _stub(0.0, &"door_1")
	_press(A, barricade.net_id)
	_press(B, door.net_id)
	assert_array(door.log).is_empty()


## Code review 2026-10-14 (GDD rule 10, AC "server's ray"): a claimed target the server's own view
## ray does not pick is rejected, so a client cannot start a hold on something behind it.
func test_start_on_a_target_the_server_ray_does_not_pick_is_rejected() -> void:
	var s := _stub()
	_aimed[A] = -1
	_press(A, s.net_id)
	assert_array(s.log).is_empty()


func test_stored_progress_at_duration_completes_on_the_start_tick() -> void:
	var s := _stub(HOLD_S, &"k")
	s.stored_s = HOLD_S
	_press(A, s.net_id)
	assert_array(s.log).is_equal(["start:%d" % A, "complete:%d" % A])
	_press(B, s.net_id) # the lock was released, so B is accepted (and completes too)
	assert_array(s.log.slice(2)).is_equal(["start:%d" % B, "complete:%d" % B])


func test_stored_progress_seeds_elapsed() -> void:
	var s := _stub()
	s.stored_s = 0.25
	_press(A)
	assert_int(_holds.hold_of(A).elapsed_ticks).is_equal(_knobs.ticks(0.25) + 1)


func test_target_is_read_on_the_rising_edge_only() -> void:
	var s := _stub()
	var other := _stub()
	_press(A, s.net_id)
	_step({A: [_f(true, other.net_id)]}) # still held, new target ignored
	assert_int(_holds.hold_of(A).net_id).is_equal(s.net_id)
	assert_array(other.log).is_empty()


func test_release_cancels_and_frees_the_lock() -> void:
	var s := _stub(HOLD_S, &"k")
	_press(A, s.net_id)
	_step({A: [_f(false)]})
	assert_str(s.log[-1]).starts_with("cancel:%d:" % A).ends_with(":released")
	_press(B, s.net_id)
	assert_int(_holds.hold_of(B).net_id).is_equal(s.net_id)


# --- line of sight on real geometry (MapQueries.clear_line) ----------------------

func test_clear_line_is_blocked_by_a_wall_but_not_by_the_actors_own_body() -> void:
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	var q := MapQueries.new(MapData.new())
	var rules := MapQueries.InteractRules.from_knobs(_knobs)
	var space := root.get_world_3d().direct_space_state
	var eye := Vector3(0.0, 1.6, 0.0)
	var point := Vector3(0.0, 0.9, -1.5)
	assert_bool(q.clear_line(eye, point, 0, rules, space)).is_true()
	var own := _box(root, Vector3(0.0, 1.6, -0.2))
	assert_bool(q.clear_line(eye, point, 0, rules, space)).is_false()
	assert_bool(q.clear_line(eye, point, 0, rules, space, [own.get_rid()])).is_true()


func _box(root: Node3D, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.PROJECTILE
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 2.0, 0.1)
	shape.shape = box
	body.add_child(shape)
	body.position = at
	root.add_child(body)
	return body


# --- code review 2026-10-14 --------------------------------------------------------

## A holder who left the round (disconnect, elimination) kept the hold and its lock forever.
func test_a_holder_who_leaves_the_round_is_cancelled_and_frees_the_lock() -> void:
	var s := _stub(HOLD_S, &"k")
	_press(A, s.net_id)
	_centres.erase(A)
	_step()
	assert_str(s.log[-1]).ends_with(":left")
	assert_dict(_holds.hold_of(A)).is_empty()
	_press(B, s.net_id) # A is still gone: only B presses
	assert_int(_holds.hold_of(B).net_id).is_equal(s.net_id)


## An owner's on_cancel that cancels another actor (ADR-0008 §5) during unregister errored on the
## already-erased hold.
class Interrupter extends Stub:
	var holds: HoldService
	func on_cancel(actor: int, progress_s: float, reason: StringName) -> void:
		super(actor, progress_s, reason)
		holds.cancel(B, &"interrupt")


func test_unregister_survives_an_owner_cancelling_another_hold() -> void:
	var s := Interrupter.new()
	s.holds = _holds
	s.point = Vector3(0.0, 0.0, -1.0)
	s.range_m = 1.5
	s.duration_s = HOLD_S
	_holds.register(s)
	_step({A: [_f(true, s.net_id)], B: [_f(true, s.net_id)]})
	_holds.unregister(s.net_id)
	assert_dict(_holds.hold_of(A)).is_empty()
	assert_dict(_holds.hold_of(B)).is_empty()
	assert_int(s.log.filter(func(l: String) -> bool: return l.begins_with("cancel:")).size()).is_equal(2)


## Frames [press X, release, press Y] in one catch-up tick: the latest press is what the player holds.
func test_the_last_press_in_a_tick_picks_the_target() -> void:
	var x := _stub()
	var y := _stub()
	_step({A: [_f(true, x.net_id), _f(false), _f(true, y.net_id)]})
	assert_int(_holds.hold_of(A).net_id).is_equal(y.net_id)
	assert_array(x.log).is_empty()


## Code review 2026-10-14: the analytic door test in clear_line had no case (the map had no doors).
## A closed door across the line blocks; the same door as the target does not block itself.
func test_clear_line_closed_door_blocks_except_as_its_own_target() -> void:
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	var door := MapPassage.new()
	door.id = &"d"
	door.kind = MapPassage.DOOR
	door.position = Vector3(0.0, 0.0, -1.0)
	door.width_m = 1.0
	door.swing_box = AABB(Vector3(-0.5, 0.0, -2.0), Vector3(1.0, 2.0, 2.0))
	var map := MapData.new()
	map.passages.assign([door])
	var q := MapQueries.new(map)
	var space := root.get_world_3d().direct_space_state
	var eye := Vector3(0.0, 1.6, 0.0)
	var point := Vector3(0.0, 0.9, -1.8)
	var closed := MapQueries.InteractRules.from_knobs(_knobs, func(id: int) -> bool: return id == 0)
	var open := MapQueries.InteractRules.from_knobs(_knobs)
	assert_bool(q.clear_line(eye, point, 1, open, space)).is_true()
	assert_bool(q.clear_line(eye, point, 1, closed, space)).is_false()
	assert_bool(q.clear_line(eye, point, 0, closed, space)).is_true()


## Code review 2026-10-14: AC3 relies on ServerMovement.frames_of handing over both frames of a
## catch-up tick, oldest first, and the repeat frame when starved.
func test_frames_of_returns_a_catch_up_ticks_frames_oldest_first_and_the_repeat_when_starved() -> void:
	var net := NetAuthority.new()
	net.setup(_knobs, "test", null)
	var runner := TickRunner.new()
	runner.fail_hard = false
	runner.boot(_knobs)
	var sm := ServerMovement.new(_knobs, net, SceneMultiplayer.new(),
		func(_b: Node, _f: InputFrame, _m: MovementModifiers) -> void: pass, PhysicsLayers.WORLD)
	sm.attach(runner)
	sm.add_player(A, auto_free(CharacterBody3D.new()))
	runner.step() # starved: earns the catch-up credit
	var frames: Array[InputFrame] = []
	for s in [1, 2, 3]:
		var f := _f(s == 1, 0)
		f.seq = s
		frames.append(f)
	sm.queue_of(A).push(InputFrame.build_packet(frames))
	runner.step()
	var got := sm.frames_of(A)
	assert_array(got.map(func(f: InputFrame) -> int: return f.seq)).is_equal([1, 2])
	runner.step() # frame 3
	runner.step() # starved: the repeat of frame 3
	assert_array(sm.frames_of(A).map(func(f: InputFrame) -> int: return f.seq)).is_equal([3])
	sm.detach()
	runner.free()
	net.free()
