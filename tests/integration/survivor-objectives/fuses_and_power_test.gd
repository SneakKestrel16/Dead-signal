# Story survivor-objectives/003: fuses, fuse boxes and power restored (survivor-objectives.md rules
# 15, 17; ADR-0008). Real HoldService + SurvivorObjectives on the real map's first two drive, fuse and
# fuse box markers; frames, centres, sight and life state are fed by the test.
extends GdUnitTestSuite

const A := 1
const B := 2
const FUSES := SurvivorObjectives.ACTIVE_DRIVES ## net id of fuse 0: drives register first
const BOXES := SurvivorObjectives.ACTIVE_DRIVES + SurvivorObjectives.ACTIVE_FUSES

var _knobs: Knobs
var _map: MapData
var _holds: HoldService
var _obj: SurvivorObjectives
var _bus: EventBus
var _events: Array[EvObjectiveProgressChanged] = []
var _feed: Dictionary = {}
var _centres: Dictionary = {}
var _downed: Dictionary = {}
var _tick := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_build(_knobs)


func _build(knobs: Knobs) -> void:
	_feed = {}
	_downed = {}
	_events = []
	_tick = 0
	_map = MapData.load_map()
	_centres = {A: _point(&"fuse", 0), B: _point(&"fuse", 0)}
	_holds = HoldService.new(knobs, func() -> Array: return _centres.keys(),
		func(actor: int) -> Array: return _feed.get(actor, []),
		func(actor: int) -> Vector3: return _centres[actor],
		func(_actor: int, _i: Interactable) -> bool: return true,
		func(actor: int) -> int: return _claimed(actor))
	_obj = SurvivorObjectives.new(_holds, _map, func(actor: int) -> bool: return not _downed.has(actor))
	_bus = EventBus.new(knobs.core.max_flush_rounds)
	_bus.subscribe(&"ObjectiveProgressChanged", _on_progress)
	_obj.placement = FirstMarkers.of(_map)
	_obj.setup(null, _bus, StateRegistry.new(), knobs)


func _on_progress(e: ServerEvent) -> void:
	_events.append(e as EvObjectiveProgressChanged)


func _point(type: StringName, n: int) -> Vector3:
	var seen := 0
	for m: MapMarker in _map.markers:
		if m.type == type:
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


func _hold(actor: int, net_id: int, ticks: int) -> void:
	for i in ticks:
		_step({actor: [_f(true, net_id)]})


func _release(actor: int) -> void:
	_step({actor: [_f(false, 0)]})


## `actor` walks to fuse `n` and picks it up with a full hold.
func _pick_up(actor: int, n: int) -> void:
	_centres[actor] = _point(&"fuse", n)
	_hold(actor, FUSES + n, _knobs.ticks(_knobs.objectives.pickup_s))
	_release(actor)


## `actor` walks to box `n` and installs with a full hold.
func _install(actor: int, n: int) -> void:
	_centres[actor] = _point(&"fuse_box", n)
	_hold(actor, BOXES + n, _install_ticks())
	_release(actor)


func _install_ticks() -> int:
	return _knobs.ticks(_knobs.objectives.fuse_install_s)


func _power_events() -> int:
	var n := 0
	for e in _events:
		if e.objective == SurvivorObjectives.TERMINAL_ID and e.state == SurvivorObjectives.TerminalState.POWERED:
			n += 1
	return n


# --- AC-1: pickup and carry limits -------------------------------------------------------------

func test_a_pickup_s_hold_gives_the_fuse_and_emits_discovered_progress() -> void:
	assert_float(_knobs.objectives.pickup_s).is_equal(1.0)
	_hold(A, FUSES, _knobs.ticks(_knobs.objectives.pickup_s))
	assert_int(_obj.fuse_state_of(0)).is_equal(SurvivorObjectives.FuseState.CARRIED)
	assert_int(_obj.fuse_carrier_of(0)).is_equal(A)
	assert_int(_events.size()).is_equal(1)
	assert_int(_events[0].objective).is_equal(SurvivorObjectives.FUSE_ID)
	assert_int(_events[0].state).is_equal(SurvivorObjectives.FuseState.CARRIED)
	assert_bool(_events[0].discovered).is_true()


func test_pickup_interrupted_one_tick_short_gives_nothing() -> void:
	_hold(A, FUSES, _knobs.ticks(_knobs.objectives.pickup_s) - 1)
	_release(A)
	assert_int(_obj.fuse_state_of(0)).is_equal(SurvivorObjectives.FuseState.UNFOUND)
	assert_int(_obj.fuse_carrier_of(0)).is_equal(-1)
	assert_array(_events).is_empty()


func test_a_fuse_carrier_is_refused_a_second_fuse_but_accepts_a_drive() -> void:
	_pick_up(A, 0)
	_centres[A] = _point(&"fuse", 1)
	_step({A: [_f(true, FUSES + 1)]})
	assert_dict(_holds.hold_of(A)).is_empty()
	_release(A)
	assert_int(_obj.fuse_state_of(1)).is_equal(SurvivorObjectives.FuseState.UNFOUND)
	_centres[A] = _point(&"drive", 0)
	_hold(A, 0, _knobs.ticks(_knobs.objectives.drive_extract_s))
	assert_int(_obj.carrier_of(0)).is_equal(A)
	assert_int(_obj.fuse_carrier_of(0)).is_equal(A)


func test_a_drive_carrier_can_pick_up_a_fuse() -> void:
	_centres[A] = _point(&"drive", 0)
	_hold(A, 0, _knobs.ticks(_knobs.objectives.drive_extract_s))
	_release(A)
	_pick_up(A, 0)
	assert_int(_obj.carrier_of(0)).is_equal(A)
	assert_int(_obj.fuse_carrier_of(0)).is_equal(A)


func test_a_carried_fuse_cannot_be_picked_up_by_another() -> void:
	_pick_up(A, 0)
	_step({B: [_f(true, FUSES)]})
	assert_dict(_holds.hold_of(B)).is_empty()


func test_a_downed_survivor_cannot_pick_up() -> void:
	_downed[A] = true
	_step({A: [_f(true, FUSES)]})
	assert_dict(_holds.hold_of(A)).is_empty()


# --- AC-2: install and refusal -----------------------------------------------------------------

func test_an_8_s_hold_at_an_empty_box_installs() -> void:
	assert_float(_knobs.objectives.fuse_install_s).is_equal(8.0)
	_pick_up(A, 0)
	_centres[A] = _point(&"fuse_box", 0)
	_hold(A, BOXES, _install_ticks() - 1)
	assert_int(_obj.box_fuse_of(0)).is_equal(-1)
	_hold(A, BOXES, 1)
	assert_int(_obj.fuse_state_of(0)).is_equal(SurvivorObjectives.FuseState.INSTALLED)
	assert_int(_obj.fuse_carrier_of(0)).is_equal(-1)
	assert_int(_obj.box_fuse_of(0)).is_equal(0)
	var fuse_e := _events[-2]
	var box_e := _events[-1]
	assert_int(fuse_e.objective).is_equal(SurvivorObjectives.FUSE_ID)
	assert_int(fuse_e.state).is_equal(SurvivorObjectives.FuseState.INSTALLED)
	assert_int(box_e.objective).is_equal(SurvivorObjectives.FUSE_BOX_ID)
	assert_bool(fuse_e.discovered and box_e.discovered).is_true()
	assert_int(_power_events()).is_equal(0)


func test_a_full_box_refuses_and_the_fuse_stays_carried() -> void:
	_pick_up(A, 0)
	_install(A, 0)
	_pick_up(B, 1)
	var before := _events.size()
	_centres[B] = _point(&"fuse_box", 0)
	_hold(B, BOXES, _install_ticks())
	assert_dict(_holds.hold_of(B)).is_empty()
	assert_int(_obj.fuse_state_of(1)).is_equal(SurvivorObjectives.FuseState.CARRIED)
	assert_int(_obj.fuse_carrier_of(1)).is_equal(B)
	assert_int(_obj.box_fuse_of(0)).is_equal(0)
	assert_int(_events.size()).is_equal(before)


func test_install_without_a_fuse_is_refused() -> void:
	_centres[A] = _point(&"fuse_box", 0)
	_step({A: [_f(true, BOXES)]})
	assert_dict(_holds.hold_of(A)).is_empty()


func test_two_survivors_starting_on_one_box_the_same_tick_one_is_locked_out() -> void:
	_pick_up(A, 0)
	_pick_up(B, 1)
	_centres[A] = _point(&"fuse_box", 0)
	_centres[B] = _centres[A]
	_step({A: [_f(true, BOXES)], B: [_f(true, BOXES)]})
	var holders := int(not _holds.hold_of(A).is_empty()) + int(not _holds.hold_of(B).is_empty())
	assert_int(holders).is_equal(1)
	var winner := A if not _holds.hold_of(A).is_empty() else B
	var loser := B if winner == A else A
	_hold(winner, BOXES, _install_ticks() - 1)
	assert_dict(_holds.hold_of(loser)).is_empty() ## still holding the button: no rising edge, no start
	assert_int(_obj.box_fuse_of(0)).is_equal(0 if winner == A else 1)
	assert_int(_obj.fuse_state_of(1 if winner == A else 0)).is_equal(SurvivorObjectives.FuseState.CARRIED)


# --- AC-3: power restored ----------------------------------------------------------------------

func test_the_second_install_restores_power_once_and_fuses_stay() -> void:
	_pick_up(A, 0)
	_install(A, 0)
	_pick_up(A, 1)
	_install(A, 1)
	assert_int(_power_events()).is_equal(1)
	var last := _events[-1]
	assert_int(last.objective).is_equal(SurvivorObjectives.TERMINAL_ID)
	assert_bool(last.discovered).is_true()
	assert_bool(_obj.power_restored()).is_true()
	_hold(B, BOXES, _install_ticks()) ## nothing can take an installed fuse out or re-trigger power
	assert_int(_obj.fuse_state_of(0)).is_equal(SurvivorObjectives.FuseState.INSTALLED)
	assert_int(_obj.fuse_state_of(1)).is_equal(SurvivorObjectives.FuseState.INSTALLED)
	assert_int(_power_events()).is_equal(1)


func test_both_installs_completing_the_same_tick_restore_power_once() -> void:
	_pick_up(A, 0)
	_pick_up(B, 1)
	_centres[A] = _point(&"fuse_box", 0)
	_centres[B] = _point(&"fuse_box", 1)
	for i in _install_ticks() - 1:
		_step({A: [_f(true, BOXES)], B: [_f(true, BOXES + 1)]})
	assert_int(_power_events()).is_equal(0)
	_step({A: [_f(true, BOXES)], B: [_f(true, BOXES + 1)]})
	assert_int(_obj.box_fuse_of(0)).is_equal(0)
	assert_int(_obj.box_fuse_of(1)).is_equal(1)
	assert_int(_power_events()).is_equal(1)


func test_one_installed_fuse_is_not_power() -> void:
	_pick_up(A, 0)
	_install(A, 0)
	assert_bool(_obj.power_restored()).is_false()
	assert_int(_power_events()).is_equal(0)


# --- AC-4: values from the knobs ---------------------------------------------------------------

func test_pickup_and_install_times_come_from_the_knobs() -> void:
	var k := Knobs.load_all()
	k.objectives.pickup_s = 0.5
	k.objectives.fuse_install_s = 5.0
	assert_array(k.errors()).is_empty()
	_knobs = k
	_build(k)
	_hold(A, FUSES, k.ticks(0.5))
	assert_int(_obj.fuse_carrier_of(0)).is_equal(A)
	_release(A)
	_centres[A] = _point(&"fuse_box", 0)
	_hold(A, BOXES, k.ticks(5.0))
	assert_int(_obj.box_fuse_of(0)).is_equal(0)


# --- Structure ---------------------------------------------------------------------------------

func test_the_module_is_freed_with_the_round_no_reference_cycle() -> void:
	var probe: WeakRef = weakref(_obj)
	_obj = null
	assert_object(probe.get_ref()).is_null()

