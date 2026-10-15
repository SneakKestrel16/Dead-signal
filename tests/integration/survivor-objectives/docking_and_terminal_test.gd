# Story survivor-objectives/005: docking and the evacuation terminal (survivor-objectives.md rules 14,
# 18-20, Formulas "Effective activation time"; ADR-0005, ADR-0008). Real HoldService + SurvivorObjectives
# on the real map's first markers; frames, centres, sight, life and hidden state are fed by the test.
extends GdUnitTestSuite

const A := 1
const B := 2
const SHIFTER := 5 ## not in survivor_ids
const FUSES := SurvivorObjectives.ACTIVE_DRIVES
const BOXES := FUSES + SurvivorObjectives.ACTIVE_FUSES
const SLOTS := BOXES + SurvivorObjectives.ACTIVE_FUSE_BOXES
const PANEL := SLOTS + SurvivorObjectives.ACTIVE_DRIVES
const PICKUPS := PANEL + 1
const FAR := Vector3(-100.0, 0.0, -100.0)

var _knobs: Knobs
var _map: MapData
var _holds: HoldService
var _obj: SurvivorObjectives
var _bus: EventBus
var _events: Array[EvObjectiveProgressChanged] = []
var _feed: Dictionary = {}
var _centres: Dictionary = {}
var _downed: Dictionary = {}
var _hidden: Dictionary = {}
var _tick := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_build(_knobs)


func _build(knobs: Knobs) -> void:
	_feed = {}
	_downed = {}
	_hidden = {}
	_events = []
	_tick = 0
	_map = MapData.load_map()
	_centres = {A: FAR, B: FAR, SHIFTER: FAR}
	_holds = HoldService.new(knobs, func() -> Array: return _centres.keys(),
		func(actor: int) -> Array: return _feed.get(actor, []),
		func(actor: int) -> Vector3: return _centres[actor],
		func(_actor: int, _i: Interactable) -> bool: return true,
		func(actor: int) -> int: return _claimed(actor))
	_obj = SurvivorObjectives.new(_holds, _map, func(actor: int) -> bool: return not _downed.has(actor),
		func(actor: int) -> bool: return _hidden.has(actor),
		func(actor: int) -> Vector3: return _centres[actor])
	_obj.survivor_ids.assign([A, B])
	_bus = EventBus.new(knobs.core.max_flush_rounds)
	_bus.subscribe(&"ObjectiveProgressChanged", _on_progress)
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


func _steps(n: int) -> void:
	for i in n:
		_step()


func _hold(actor: int, net_id: int, ticks: int) -> void:
	for i in ticks:
		_step({actor: [_f(true, net_id)]})


func _release(actor: int) -> void:
	_step({actor: [_f(false, 0)]})


func _t(seconds: float) -> int:
	return _knobs.ticks(seconds)


func _extract(actor: int, n: int) -> void:
	_centres[actor] = _point(&"drive", n)
	_hold(actor, n, _t(_knobs.objectives.drive_extract_s))
	_release(actor)


func _dock(actor: int, slot: int) -> void:
	_centres[actor] = _point(&"terminal", 0)
	_hold(actor, SLOTS + slot, _t(_knobs.objectives.dock_s))
	_release(actor)


func _restore_power(actor: int) -> void:
	for n in 2:
		_centres[actor] = _point(&"fuse", n)
		_hold(actor, FUSES + n, _t(_knobs.objectives.pickup_s))
		_release(actor)
		_centres[actor] = _point(&"fuse_box", n)
		_hold(actor, BOXES + n, _t(_knobs.objectives.fuse_install_s))
		_release(actor)


func _arm() -> void:
	_extract(A, 0)
	_extract(A, 1)
	_dock(A, 0)
	_dock(A, 1)
	_restore_power(A)


## Arms, then `actor` starts activation standing at the terminal (in the zone). The completing tick is
## the first Activating tick and counts if the zone is held.
func _start_activation(actor: int) -> void:
	_arm()
	_centres[actor] = _point(&"terminal", 0)
	_hold(actor, PANEL, _t(_knobs.objectives.activation_start_s))
	_release(actor)


func _terminal_events(state: SurvivorObjectives.TerminalState) -> int:
	var n := 0
	for e in _events:
		if e.objective == SurvivorObjectives.TERMINAL_ID and e.state == state:
			n += 1
	return n


# --- AC-1: docking and arming ------------------------------------------------------------------

func test_a_dock_s_hold_docks_the_drive_with_no_carrier() -> void:
	assert_float(_knobs.objectives.dock_s).is_equal(2.0)
	_extract(A, 0)
	_centres[A] = _point(&"terminal", 0)
	_hold(A, SLOTS, _t(_knobs.objectives.dock_s) - 1)
	assert_int(_obj.state_of(0)).is_equal(SurvivorObjectives.DriveState.CARRIED)
	_hold(A, SLOTS, 1)
	assert_int(_obj.state_of(0)).is_equal(SurvivorObjectives.DriveState.DOCKED)
	assert_int(_obj.carrier_of(0)).is_equal(-1)
	assert_int(_obj.carried_by(A)).is_equal(0)
	assert_int(_events[-1].objective).is_equal(SurvivorObjectives.DRIVE_ID)
	assert_int(_events[-1].state).is_equal(SurvivorObjectives.DriveState.DOCKED)


func test_docking_without_a_drive_or_into_a_full_slot_is_refused() -> void:
	_centres[A] = _point(&"terminal", 0)
	_step({A: [_f(true, SLOTS)]})
	assert_dict(_holds.hold_of(A)).is_empty()
	_release(A)
	_extract(A, 0)
	_extract(A, 1)
	_dock(A, 0)
	_step({A: [_f(true, SLOTS)]})
	assert_dict(_holds.hold_of(A)).is_empty()
	assert_int(_obj.state_of(1)).is_equal(SurvivorObjectives.DriveState.CARRIED)


func test_docking_before_power_is_allowed_and_arms_only_on_the_second_fuse() -> void:
	_extract(A, 0)
	_extract(A, 1)
	_dock(A, 0)
	_dock(A, 1)
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.LOCKED)
	assert_int(_terminal_events(SurvivorObjectives.TerminalState.ARMED)).is_equal(0)
	_centres[B] = _point(&"terminal", 0)
	_step({B: [_f(true, PANEL)]}) ## activation refused before Armed
	assert_dict(_holds.hold_of(B)).is_empty()
	_restore_power(A)
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.ARMED)
	assert_int(_terminal_events(SurvivorObjectives.TerminalState.ARMED)).is_equal(1)
	assert_int(_events[-1].objective).is_equal(SurvivorObjectives.TERMINAL_ID)


func test_power_first_then_the_second_dock_arms_once() -> void:
	_restore_power(A)
	_extract(A, 0)
	_extract(A, 1)
	_dock(A, 0)
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.LOCKED)
	_dock(A, 1)
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.ARMED)
	assert_int(_terminal_events(SurvivorObjectives.TerminalState.ARMED)).is_equal(1)


func test_one_drive_docked_with_power_is_not_armed_and_refuses_activation() -> void:
	_restore_power(A)
	_extract(A, 0)
	_dock(A, 0)
	_centres[B] = _point(&"terminal", 0)
	_step({B: [_f(true, PANEL)]})
	assert_dict(_holds.hold_of(B)).is_empty()
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.LOCKED)


func test_a_docked_drive_cannot_be_removed() -> void:
	_extract(A, 0)
	_dock(A, 0)
	_centres[B] = _point(&"terminal", 0)
	_hold(B, PICKUPS, _t(_knobs.objectives.pickup_s))
	assert_int(_obj.state_of(0)).is_equal(SurvivorObjectives.DriveState.DOCKED)
	assert_int(_obj.carried_by(B)).is_equal(0)


func test_match_flow_enters_evacuation_when_the_terminal_arms() -> void:
	var mf := MatchFlow.new()
	mf.setup(null, _bus, StateRegistry.new(), _knobs)
	_arm()
	assert_int(mf.phase()).is_equal(MatchFlow.Phase.EVACUATION)


# --- AC-2: the countdown holds the zone --------------------------------------------------------

func test_a_start_hold_makes_the_terminal_activating() -> void:
	assert_float(_knobs.objectives.activation_start_s).is_equal(1.0)
	_start_activation(B)
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.ACTIVATING)
	assert_int(_terminal_events(SurvivorObjectives.TerminalState.ACTIVATING)).is_equal(1)


func test_15_s_in_the_zone_activates() -> void:
	assert_float(_knobs.objectives.evac_activation_s).is_equal(15.0)
	_start_activation(B) ## start tick + release tick: 2 held ticks
	_steps(_t(15.0) - 3)
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.ACTIVATING)
	_steps(1)
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.ACTIVATED)


func test_leaving_for_6_s_after_9_s_pauses_and_activates_at_21_s() -> void:
	_start_activation(B)
	_steps(_t(9.0) - 2)
	_centres[B] = FAR
	_steps(_t(6.0))
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.ACTIVATING)
	_centres[B] = _point(&"terminal", 0)
	_steps(_t(6.0) - 1)
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.ACTIVATING)
	_steps(1)
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.ACTIVATED)


func test_a_hidden_survivor_or_the_shapeshifter_alone_does_not_run_it() -> void:
	_start_activation(B) ## 2 ticks counted
	_hidden[B] = true
	_centres[SHIFTER] = _point(&"terminal", 0)
	_steps(_t(30.0))
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.ACTIVATING)
	_hidden.erase(B)
	_steps(_t(15.0) - 3)
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.ACTIVATING)
	_steps(1)
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.ACTIVATED)


func test_the_last_healthy_survivor_downed_mid_countdown_pauses_it_with_progress_kept() -> void:
	_start_activation(B)
	_steps(_t(5.0) - 2)
	_downed[B] = true
	_steps(_t(20.0))
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.ACTIVATING)
	_downed.erase(B)
	_steps(_t(10.0) - 1)
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.ACTIVATING)
	_steps(1)
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.ACTIVATED)


# --- AC-3: activation --------------------------------------------------------------------------

func test_at_0_the_exit_opens_and_both_drives_eject_as_dropped() -> void:
	_start_activation(B)
	assert_bool(_obj.exit_open()).is_false()
	_steps(_t(15.0) - 2)
	assert_bool(_obj.exit_open()).is_true()
	assert_int(_terminal_events(SurvivorObjectives.TerminalState.ACTIVATED)).is_equal(1)
	for n in 2:
		assert_int(_obj.state_of(n)).is_equal(SurvivorObjectives.DriveState.DROPPED)
		assert_int(_obj.carrier_of(n)).is_equal(-1)
	var dropped := 0
	for e in _events:
		if e.objective < SurvivorObjectives.FUSE_ID and e.state == SurvivorObjectives.DriveState.DROPPED:
			dropped += 1
	assert_int(dropped).is_equal(2)
	_steps(_t(5.0)) ## nothing more happens once Activated
	assert_int(_terminal_events(SurvivorObjectives.TerminalState.ACTIVATED)).is_equal(1)


func test_any_healthy_survivor_picks_up_an_ejected_drive_and_a_downed_one_cannot() -> void:
	_start_activation(B)
	_steps(_t(15.0) - 2)
	_downed[A] = true
	_centres[A] = _point(&"terminal", 0)
	_step({A: [_f(true, PICKUPS)]})
	assert_dict(_holds.hold_of(A)).is_empty()
	_hold(B, PICKUPS + 1, _t(_knobs.objectives.pickup_s))
	assert_int(_obj.state_of(1)).is_equal(SurvivorObjectives.DriveState.CARRIED)
	assert_int(_obj.carrier_of(1)).is_equal(B)


# --- AC-4: values from the knobs ---------------------------------------------------------------

func test_dock_start_countdown_and_zone_come_from_the_knobs() -> void:
	var k := Knobs.load_all()
	k.objectives.dock_s = 1.0
	k.objectives.activation_start_s = 0.5
	k.objectives.evac_activation_s = 10.0
	k.objectives.terminal_zone_radius_m = 10.0
	assert_array(k.errors()).is_empty()
	_knobs = k
	_build(k)
	_extract(A, 0)
	_centres[A] = _point(&"terminal", 0)
	_hold(A, SLOTS, k.ticks(1.0))
	assert_int(_obj.state_of(0)).is_equal(SurvivorObjectives.DriveState.DOCKED)
	_release(A)
	_extract(A, 1)
	_dock(A, 1)
	_restore_power(A)
	_centres[B] = _point(&"terminal", 0)
	_hold(B, PANEL, k.ticks(0.5))
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.ACTIVATING)
	_centres[B] = _point(&"terminal", 0) + Vector3(9.0, 0.0, 0.0) ## inside the wider zone
	_steps(k.ticks(10.0) - 2)
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.ACTIVATING)
	_steps(1)
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.ACTIVATED)


# --- Structure ---------------------------------------------------------------------------------

func test_the_module_is_freed_with_the_round_no_reference_cycle() -> void:
	_start_activation(B)
	var probe: WeakRef = weakref(_obj)
	_obj = null
	assert_object(probe.get_ref()).is_null()
