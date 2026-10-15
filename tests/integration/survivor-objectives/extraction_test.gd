# Story survivor-objectives/006: drive extraction at the exit (survivor-objectives.md rules 22, 23;
# ADR-0005). Real HoldService + SurvivorObjectives + MatchFlow on one bus and the real map; frames and
# centres are fed by the test. Match Flow story 003 decides the escape; here the test emits
# SurvivorEscaped on the bus directly.
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
var _mf: MatchFlow
var _bus: EventBus
var _events: Array[EvObjectiveProgressChanged] = []
var _ended: Array[EvRoundEnded] = []
var _feed: Dictionary = {}
var _centres: Dictionary = {}
var _tick := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_build(_knobs)


func _build(knobs: Knobs) -> void:
	_feed = {}
	_events = []
	_ended = []
	_tick = 0
	_map = MapData.load_map()
	_centres = {A: FAR, B: FAR, SHIFTER: FAR}
	_holds = HoldService.new(knobs, func() -> Array: return _centres.keys(),
		func(actor: int) -> Array: return _feed.get(actor, []),
		func(actor: int) -> Vector3: return _centres[actor],
		func(_actor: int, _i: Interactable) -> bool: return true,
		func(actor: int) -> int: return _claimed(actor))
	_obj = SurvivorObjectives.new(_holds, _map, Callable(),
		Callable(), func(actor: int) -> Vector3: return _centres[actor])
	_obj.survivor_ids.assign([A, B])
	_bus = EventBus.new(knobs.core.max_flush_rounds)
	_bus.subscribe(&"ObjectiveProgressChanged", _on_progress)
	_bus.subscribe(&"RoundEnded", _on_ended)
	_obj.setup(null, _bus, StateRegistry.new(), knobs)
	_mf = MatchFlow.new()
	_mf.survivor_ids.assign([A, B])
	_mf.setup(null, _bus, StateRegistry.new(), knobs)


func _on_progress(e: ServerEvent) -> void:
	_events.append(e as EvObjectiveProgressChanged)


func _on_ended(e: ServerEvent) -> void:
	_ended.append(e as EvRoundEnded)


func _point(type: StringName, n: int) -> Vector3:
	var seen := 0
	for m: MapMarker in _map.markers:
		if m.type == type:
			if seen == n:
				return m.position
			seen += 1
	return Vector3.ZERO


## Match Flow's escape (story 003), sent as it would be: on the bus, then the next tick runs.
func _escape(actor: int) -> void:
	var e := EvSurvivorEscaped.new()
	e.survivor = actor
	_bus.emit(e)
	_step()


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


## One tick in RoundServer slot order: Holds, Objectives, then Match Flow's resolve step.
func _step(frames: Dictionary = {}) -> void:
	for actor: int in frames:
		_feed[actor] = frames[actor]
	_holds.server_tick(_tick)
	_obj.server_tick(_tick)
	_bus.flush()
	_mf.resolve_step().server_tick(_tick)
	_bus.flush()
	_tick += 1


func _steps(n: int) -> void:
	for i in n:
		_step()


func _hold(actor: int, net_id: int, ticks: int) -> void:
	for i in ticks:
		_step({actor: [_f(true, net_id)]})
	_step({actor: [_f(false, 0)]})


func _t(seconds: float) -> int:
	return _knobs.ticks(seconds)


## Drives to the terminal, power, activation by B in the zone, countdown to 0: both drives Dropped.
func _activate() -> void:
	for n in 2: ## one at a time, so it also works with the cap at 1
		_centres[A] = _point(&"drive", n)
		_hold(A, n, _t(_knobs.objectives.drive_extract_s))
		_centres[A] = _point(&"terminal", 0)
		_hold(A, SLOTS + n, _t(_knobs.objectives.dock_s))
	for n in 2:
		_centres[A] = _point(&"fuse", n)
		_hold(A, FUSES + n, _t(_knobs.objectives.pickup_s))
		_centres[A] = _point(&"fuse_box", n)
		_hold(A, BOXES + n, _t(_knobs.objectives.fuse_install_s))
	_centres[A] = FAR
	_centres[B] = _point(&"terminal", 0)
	_hold(B, PANEL, _t(_knobs.objectives.activation_start_s))
	_steps(_t(_knobs.objectives.evac_activation_s))
	assert_bool(_obj.exit_open()).is_true()


func _pick_up(actor: int, drive: int) -> void:
	_centres[actor] = _point(&"terminal", 0)
	_hold(actor, PICKUPS + drive, _t(_knobs.objectives.pickup_s))


func _extracted_events() -> int:
	var n := 0
	for e in _events:
		if e.objective < SurvivorObjectives.FUSE_ID and e.state == SurvivorObjectives.DriveState.EXTRACTED:
			n += 1
	return n


# --- AC-1: one drive extracts; the win waits for the second ------------------------------------

func test_one_drive_then_the_second_ends_survivors_win_evidence_escaped() -> void:
	_activate()
	_pick_up(A, 0)
	_pick_up(B, 1)
	_escape(A)
	assert_int(_obj.state_of(0)).is_equal(SurvivorObjectives.DriveState.EXTRACTED)
	assert_int(_obj.carrier_of(0)).is_equal(-1)
	assert_int(_obj.state_of(1)).is_equal(SurvivorObjectives.DriveState.CARRIED)
	assert_int(_extracted_events()).is_equal(1)
	assert_int(_events[-1].objective).is_equal(SurvivorObjectives.DRIVE_ID)
	_steps(3)
	assert_array(_ended).is_empty()
	_escape(B)
	assert_int(_obj.state_of(1)).is_equal(SurvivorObjectives.DriveState.EXTRACTED)
	assert_int(_extracted_events()).is_equal(2)
	assert_int(_ended.size()).is_equal(1)
	assert_int(_ended[0].outcome).is_equal(MatchFlow.Outcome.SURVIVORS_WIN)
	assert_int(_ended[0].reason).is_equal(MatchFlow.Reason.EVIDENCE_ESCAPED)


# --- AC-2: one survivor carries both out -------------------------------------------------------

func test_one_survivor_picks_up_both_and_extracts_both_alone() -> void:
	_activate()
	_pick_up(B, 0)
	_pick_up(B, 1)
	assert_int(_obj.carried_by(B)).is_equal(2)
	_escape(B)
	for n in 2:
		assert_int(_obj.state_of(n)).is_equal(SurvivorObjectives.DriveState.EXTRACTED)
	assert_int(_extracted_events()).is_equal(2)
	# Both drives out locks a survivor win; others are still inside, so the round runs on (rule 15).
	assert_bool(_mf.is_locked()).is_true()
	assert_array(_ended).is_empty()


func test_with_the_cap_at_1_one_survivor_extracts_only_one() -> void:
	var k := Knobs.load_all()
	k.objectives.max_drives_carried = 1
	assert_array(k.errors()).is_empty()
	_knobs = k
	_build(k)
	_activate()
	_pick_up(B, 0)
	_pick_up(B, 1)
	assert_int(_obj.carried_by(B)).is_equal(1)
	_escape(B)
	assert_int(_obj.state_of(0)).is_equal(SurvivorObjectives.DriveState.EXTRACTED)
	assert_int(_obj.state_of(1)).is_equal(SurvivorObjectives.DriveState.DROPPED)
	assert_array(_ended).is_empty()


# --- AC-3: escapes without drives --------------------------------------------------------------

func test_an_empty_handed_escape_changes_no_objective_state() -> void:
	_activate()
	var before := _events.size()
	_escape(A)
	assert_int(_events.size()).is_equal(before)
	for n in 2:
		assert_int(_obj.state_of(n)).is_equal(SurvivorObjectives.DriveState.DROPPED)


func test_a_non_carriers_escape_leaves_the_carriers_drive_alone() -> void:
	_activate()
	_pick_up(B, 0)
	var before := _events.size()
	_escape(A)
	assert_int(_events.size()).is_equal(before)
	assert_int(_obj.state_of(0)).is_equal(SurvivorObjectives.DriveState.CARRIED)
	assert_int(_obj.carrier_of(0)).is_equal(B)


# --- Structure ---------------------------------------------------------------------------------

func test_the_module_is_freed_with_the_round_no_reference_cycle() -> void:
	_activate()
	var probe: WeakRef = weakref(_obj)
	_obj = null
	assert_object(probe.get_ref()).is_null()
