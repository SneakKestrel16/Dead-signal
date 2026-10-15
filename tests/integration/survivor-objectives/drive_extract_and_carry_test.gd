# Story survivor-objectives/001: drive extract and carry (survivor-objectives.md rules 1-3, 8-9;
# ADR-0008). Real HoldService + SurvivorObjectives on the real map's first two drive markers; frames,
# centres, sight and life state are fed by the test.
extends GdUnitTestSuite

const A := 1
const B := 2

var _knobs: Knobs
var _holds: HoldService
var _obj: SurvivorObjectives
var _bus: EventBus
var _events: Array[EvObjectiveProgressChanged] = []
var _feed: Dictionary = {}
var _centres: Dictionary = {}
var _downed: Dictionary = {}
var _aimed: Dictionary = {} ## actor -> net id the server's ray picks; absent = the claimed target
var _tick := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_build(_knobs)


func _build(knobs: Knobs) -> void:
	_feed = {}
	_downed = {}
	_aimed = {}
	_events = []
	_tick = 0
	var map := MapData.load_map()
	_centres = {A: _drive_point(map, 0), B: _drive_point(map, 0)}
	_holds = HoldService.new(knobs, func() -> Array: return _centres.keys(),
		func(actor: int) -> Array: return _feed.get(actor, []),
		func(actor: int) -> Vector3: return _centres[actor],
		func(_actor: int, _i: Interactable) -> bool: return true,
		func(actor: int) -> int: return _aimed[actor] if _aimed.has(actor) else _claimed(actor))
	_obj = SurvivorObjectives.new(_holds, map, func(actor: int) -> bool: return not _downed.has(actor))
	_bus = EventBus.new(knobs.core.max_flush_rounds)
	_bus.subscribe(&"ObjectiveProgressChanged", _on_progress)
	_obj.placement = FirstMarkers.of(map)
	_obj.setup(null, _bus, StateRegistry.new(), knobs)


func _on_progress(e: ServerEvent) -> void:
	_events.append(e as EvObjectiveProgressChanged)


func _drive_point(map: MapData, n: int) -> Vector3:
	var seen := 0
	for m: MapMarker in map.markers:
		if m.type == &"drive":
			if seen == n:
				return m.position
			seen += 1
	return Vector3.ZERO


func _claimed(actor: int) -> int:
	var id := -1
	for f: InputFrame in _feed.get(actor, []):
		if f.interact:
			id = f.interact_target
	return id


func _f(interact: bool, target := 0) -> InputFrame:
	var f := InputFrame.new()
	f.interact = interact
	f.interact_target = target
	return f


func _step(frames: Dictionary = {}) -> void:
	for actor: int in frames:
		_feed[actor] = frames[actor]
	_holds.server_tick(_tick)
	_obj.server_tick(_tick)
	_bus.flush()
	_tick += 1


## `actor` presses on console `n` and keeps holding for `ticks` ticks in total.
func _hold(actor: int, n: int, ticks: int) -> void:
	for i in ticks:
		_step({actor: [_f(true, n)]})


func _extract_ticks() -> int:
	return _knobs.ticks(_knobs.objectives.drive_extract_s)


# --- AC1 -------------------------------------------------------------------------------------

func test_a_full_hold_gives_the_drive_and_emits_progress() -> void:
	assert_float(_knobs.objectives.drive_extract_s).is_equal(5.0)
	_hold(A, 0, _extract_ticks())
	assert_int(_obj.state_of(0)).is_equal(SurvivorObjectives.DriveState.CARRIED)
	assert_int(_obj.carrier_of(0)).is_equal(A)
	assert_int(_events.size()).is_equal(1)
	assert_int(_events[0].objective).is_equal(0)
	assert_int(_events[0].state).is_equal(SurvivorObjectives.DriveState.CARRIED)
	assert_dict(_holds.hold_of(A)).is_empty()


func test_one_tick_before_completion_nothing_is_given() -> void:
	_hold(A, 0, _extract_ticks() - 1)
	assert_int(_obj.state_of(0)).is_equal(SurvivorObjectives.DriveState.SECURED)
	assert_array(_events).is_empty()
	assert_int(_holds.hold_of(A).elapsed_ticks).is_equal(_extract_ticks() - 1)


func test_releasing_at_4_s_gives_nothing_and_resets_the_bar() -> void:
	_hold(B, 0, _knobs.ticks(4.0))
	_step({B: [_f(false, 0)]})
	assert_dict(_holds.hold_of(B)).is_empty()
	assert_int(_obj.state_of(0)).is_equal(SurvivorObjectives.DriveState.SECURED)
	assert_array(_events).is_empty()
	_step({B: [_f(true, 0)]}) ## a new press starts from 0
	assert_int(_holds.hold_of(B).elapsed_ticks).is_equal(1)


func test_a_second_holder_is_locked_out_while_the_first_extracts() -> void:
	_hold(A, 0, 10)
	_step({B: [_f(true, 0)]})
	assert_dict(_holds.hold_of(B)).is_empty()
	assert_int(_holds.hold_of(A).net_id).is_equal(0)


# --- AC2 -------------------------------------------------------------------------------------

func test_a_downed_survivor_cannot_start_the_hold() -> void:
	_downed[A] = true
	_step({A: [_f(true, 0)]})
	assert_dict(_holds.hold_of(A)).is_empty()


func test_going_down_mid_hold_cancels_and_gives_nothing() -> void:
	_hold(A, 0, 100)
	_downed[A] = true
	_step({A: [_f(true, 0)]})
	assert_dict(_holds.hold_of(A)).is_empty()
	assert_int(_obj.state_of(0)).is_equal(SurvivorObjectives.DriveState.SECURED)


func test_start_at_2_1_m_is_refused_with_range_2() -> void:
	var map := MapData.load_map()
	assert_float(_knobs.objectives.interact_range_m).is_equal(2.0)
	_centres[A] = _drive_point(map, 0) + Vector3(2.1, 0.0, 0.0)
	_step({A: [_f(true, 0)]})
	assert_dict(_holds.hold_of(A)).is_empty()


func test_a_hold_keeps_to_2_25_m_exactly_and_breaks_beyond() -> void:
	var map := MapData.load_map()
	var p := _drive_point(map, 0)
	_hold(A, 0, 10)
	_centres[A] = p + Vector3(_knobs.objectives.interact_range_m + _knobs.controller.hold_range_tolerance_m, 0.0, 0.0)
	assert_float(_centres[A].distance_to(p)).is_equal_approx(2.25, 0.0001)
	_step({A: [_f(true, 0)]})
	assert_int(_holds.hold_of(A).net_id).is_equal(0)
	_centres[A] = p + Vector3(2.26, 0.0, 0.0)
	_step({A: [_f(true, 0)]})
	assert_dict(_holds.hold_of(A)).is_empty()


# --- AC3 -------------------------------------------------------------------------------------

func test_cap_2_lets_a_carrier_extract_a_second_drive() -> void:
	assert_int(_knobs.objectives.max_drives_carried).is_equal(2)
	_hold(A, 0, _extract_ticks())
	_step({A: [_f(false, 0)]})
	_centres[A] = _drive_point(MapData.load_map(), 1)
	_hold(A, 1, _extract_ticks())
	assert_int(_obj.carried_by(A)).is_equal(2)
	assert_int(_obj.state_of(1)).is_equal(SurvivorObjectives.DriveState.CARRIED)
	assert_int(_events.size()).is_equal(2)


func test_cap_1_refuses_a_second_drive() -> void:
	var k := Knobs.load_all()
	k.objectives.max_drives_carried = 1
	assert_array(k.errors()).is_empty()
	_knobs = k
	_build(k)
	_hold(A, 0, _extract_ticks())
	_step({A: [_f(false, 0)]})
	_centres[A] = _drive_point(MapData.load_map(), 1)
	_centres[B] = _centres[A]
	_step({A: [_f(true, 1)]})
	assert_dict(_holds.hold_of(A)).is_empty()
	assert_int(_obj.carried_by(A)).is_equal(1)
	assert_int(_obj.state_of(1)).is_equal(SurvivorObjectives.DriveState.SECURED)
	_step({B: [_f(true, 1)]}) ## another survivor can still extract it
	assert_int(_holds.hold_of(B).net_id).is_equal(1)


func test_a_cap_override_outside_1_to_2_fails_validation() -> void:
	for bad in [0, 3]:
		var k := Knobs.load_all()
		k.objectives.max_drives_carried = bad
		assert_array(k.errors()).is_not_empty()


# --- AC4 -------------------------------------------------------------------------------------

func test_a_forged_claim_of_completion_changes_nothing() -> void:
	## A client can only send input frames. One claiming the console while the server's ray sees
	## nothing there is not a Start.
	_aimed[A] = -1
	_step({A: [_f(true, 0)]})
	assert_dict(_holds.hold_of(A)).is_empty()
	assert_int(_obj.state_of(0)).is_equal(SurvivorObjectives.DriveState.SECURED)
	assert_array(_events).is_empty()


func test_a_forged_claim_during_a_hold_does_not_shorten_it() -> void:
	_hold(A, 0, 50)
	_step({A: [_f(true, 1)]}) ## pressing another target mid-hold: no rising edge, ignored
	_step({B: [_f(true, 0)]}) ## a rival claiming the same console is locked out
	assert_int(_obj.state_of(0)).is_equal(SurvivorObjectives.DriveState.SECURED)
	assert_int(_holds.hold_of(A).elapsed_ticks).is_equal(52)
	assert_array(_events).is_empty()


# --- AC5 -------------------------------------------------------------------------------------

func test_hold_time_and_range_come_from_the_knobs() -> void:
	var k := Knobs.load_all()
	k.objectives.drive_extract_s = 3.0
	k.objectives.interact_range_m = 1.5
	_knobs = k
	_build(k)
	var map := MapData.load_map()
	_centres[B] = _drive_point(map, 0) + Vector3(1.6, 0.0, 0.0) ## outside the overridden range
	_step({B: [_f(true, 0)]})
	assert_dict(_holds.hold_of(B)).is_empty()
	_hold(A, 0, k.ticks(3.0))
	assert_int(_obj.state_of(0)).is_equal(SurvivorObjectives.DriveState.CARRIED)


# --- Review fixes ------------------------------------------------------------------------------

func test_a_carried_drive_event_reaches_survivor_clients() -> void:
	_hold(A, 0, _extract_ticks())
	var survivor_peer := 7
	var monster_peer := 9
	var d := _events[0].project(survivor_peer, null, monster_peer)
	assert_dict(d).is_equal({"objective": SurvivorObjectives.DRIVE_ID, "state": SurvivorObjectives.DriveState.CARRIED,
		"carrier": A})


func test_a_carried_drive_cannot_be_extracted_again_and_the_other_can() -> void:
	_hold(A, 0, _extract_ticks())
	_step({A: [_f(false, 0)]})
	_step({B: [_f(true, 0)]})
	assert_dict(_holds.hold_of(B)).is_empty()
	_step({B: [_f(false, 0)]})
	_centres[B] = _drive_point(MapData.load_map(), 1)
	_hold(B, 1, _extract_ticks())
	assert_int(_obj.carrier_of(1)).is_equal(B)
	assert_int(_events[1].objective).is_equal(SurvivorObjectives.DRIVE_ID + 1)


func test_the_module_is_freed_with_the_round_no_reference_cycle() -> void:
	var probe: WeakRef = weakref(_obj)
	_obj = null
	assert_object(probe.get_ref()).is_null()


func test_setup_twice_does_not_duplicate_drives() -> void:
	_obj.setup(null, _bus, StateRegistry.new(), _knobs)
	assert_int(_obj.drive_count()).is_equal(SurvivorObjectives.ACTIVE_DRIVES)
