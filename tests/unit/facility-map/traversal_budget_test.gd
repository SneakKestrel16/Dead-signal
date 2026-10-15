# Story facility-map/006: traversal budget walk-through (research-facility.md Dimensions and Traversal,
# Acceptance Criteria 7; TR-facility-002; ADR-0007 §3). A scripted walker - a real PlayerBody moved by the
# real MovementStep under Jolt, one step per physics tick at sim_tick_hz - follows the route waypoints
# below through the authored greybox scene at walk speed and is timed in ticks.
extends GdUnitTestSuite

const SCENE := "res://assets/levels/research_facility.tscn"
## The doc's Targets bound: any room to any other room in 20 s or less at walk speed.
const BUDGET_S := 20.0
## A waypoint counts as reached within this horizontal distance (one tick at 4 m/s moves ~0.07 m).
const REACH_M := 0.25
## Hard stop for a walker that never arrives, well past the budget.
const MAX_S := 30.0
const SETTLE_TICKS := 5
## Route waypoints (x, z) in metres: test data, not map data (story Implementation Notes). Each passes
## through door and archway centres square to the wall, read off data/maps/research_facility.tres.
## A1 to the C4 exit via H-S and C3 (doc ~66 m, ~17 s). Starts on S1, the spawn farthest from the
## archway; ends against the closed exit leaf at C4-Outside (60, 20) (exit E stays closed until activation).
const ROUTE_A1_C4_EXIT: Array[Vector2] = [
	Vector2(2.0, 31.0), ## S1
	Vector2(8.5, 38.95), Vector2(11.5, 38.95), ## A1-H-S archway, clear z 38-39.9
	Vector2(50.5, 37.5), Vector2(50.5, 34.5), ## C3-H-S door (50.5, 36)
	Vector2(55.5, 29.5), Vector2(55.5, 26.5), ## C3-C4 door (55.5, 28)
	Vector2(59.3, 20.0), ## at the exit leaf
]
## A6 to C3 via H-N, C5 and C2 (doc ~72 m, ~18 s: the longest room-to-room route). Starts at A6's centre,
## ends 2 m inside C3.
const ROUTE_A6_C3: Array[Vector2] = [
	Vector2(5.0, 9.0), ## A6 centre
	Vector2(5.5, 5.5), Vector2(5.5, 2.0), ## A6-H-N door (5.5, 4)
	Vector2(44.5, 2.0), Vector2(44.5, 15.5), ## H-N-C5 (44.5, 4) and C5-C2 (44.5, 14) doors
	Vector2(45.5, 26.5), Vector2(45.5, 30.0), ## C2-C3 door (45.5, 28)
]

var _knobs: Knobs
var _saved_hz: int
var _level: Node3D


func before_test() -> void:
	_knobs = Knobs.load_all()
	_saved_hz = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = _knobs.net.sim_tick_hz
	_level = auto_free(load(SCENE).instantiate())
	add_child(_level)


func after_test() -> void:
	Engine.physics_ticks_per_second = _saved_hz


## Walks `route` and returns {ticks, reached, stalls}: the ticks from the first step to the last waypoint,
## whether it got there, and the ticks (with speeds) where the walker moved under half the walk speed
## while input was held, outside the accel_time_s ramp after the start and after each turn.
func _walk(route: Array[Vector2]) -> Dictionary:
	var body := PlayerBody.new()
	body.setup(_knobs, PhysicsLayers.MOVE_SERVER)
	_level.add_child(body)
	body.global_position = Vector3(route[0].x, 0.0, route[0].y)
	for i in SETTLE_TICKS:
		await get_tree().physics_frame
	var hz := Engine.physics_ticks_per_second
	var walk := _knobs.controller.walk_speed
	var grace := ceili(_knobs.controller.accel_time_s * hz) + 1
	var state := MovementStep.MoveState.new()
	var frame := InputFrame.new()
	frame.move = Vector2(0, 1)
	var next := 1
	var since_turn := 0
	var ticks := 0
	var stalls := PackedStringArray()
	while next < route.size() and ticks < MAX_S * hz:
		var at := Vector2(body.global_position.x, body.global_position.z)
		var d := route[next] - at
		frame.yaw = atan2(-d.x, -d.y) ## forward at yaw 0 is -Z (MovementStep)
		await get_tree().physics_frame
		MovementStep.step(body, frame, state, _knobs)
		ticks += 1
		since_turn += 1
		var now := Vector2(body.global_position.x, body.global_position.z)
		var speed := now.distance_to(at) * hz
		if since_turn > grace and speed < walk / 2.0:
			stalls.append("tick %d at (%.2f, %.2f): %.2f m/s" % [ticks, now.x, now.y, speed])
		if now.distance_to(route[next]) < REACH_M:
			next += 1
			since_turn = 0
	body.free()
	return {"ticks": ticks, "reached": next == route.size(), "stalls": stalls,
		"seconds": float(ticks) / hz}


func _assert_route(route: Array[Vector2], route_name: String) -> void:
	var r := await _walk(route)
	prints(route_name, "%.2f s" % r.seconds)
	assert_bool(r.reached).override_failure_message("%s: never reached the end (%.1f s)" % [route_name, r.seconds]).is_true()
	assert_float(r.seconds).override_failure_message("%s: %.2f s > %.0f s" % [route_name, r.seconds, BUDGET_S]).is_less_equal(BUDGET_S)
	assert_array(r.stalls).override_failure_message("%s stalled %d ticks, first: %s" % [route_name, r.stalls.size(), ", ".join(r.stalls.slice(0, 3))]).is_empty()


# --- AC1 + AC2 ----------------------------------------------------------------

func test_a1_to_the_c4_exit_takes_at_most_20_s_without_stalling() -> void:
	await _assert_route(ROUTE_A1_C4_EXIT, "A1->C4 exit")


func test_a6_to_c3_takes_at_most_20_s_without_stalling() -> void:
	await _assert_route(ROUTE_A6_C3, "A6->C3")
