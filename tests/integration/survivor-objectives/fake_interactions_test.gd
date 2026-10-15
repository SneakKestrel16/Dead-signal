# Story survivor-objectives/007: shapeshifter fake interactions (survivor-objectives.md rules 25-26;
# ADR-0008 §6). Real HoldService (with the role Callable) + SurvivorObjectives on the real map's first
# markers; frames, centres and sight are fed by the test. Disguise is not an input: HoldService decides a
# fake from the role alone, so "disguised or not" is the same path.
extends GdUnitTestSuite

const A := 1
const SHIFTER := 5 ## not in survivor_ids
const DRIVES := 0
const FUSES := SurvivorObjectives.ACTIVE_DRIVES
const BOXES := FUSES + SurvivorObjectives.ACTIVE_FUSES
const SLOTS := BOXES + SurvivorObjectives.ACTIVE_FUSE_BOXES
const PANEL := SLOTS + SurvivorObjectives.ACTIVE_DRIVES
const DROPPED_DRIVES := PANEL + 1
const DROPPED_FUSES := DROPPED_DRIVES + SurvivorObjectives.ACTIVE_DRIVES
const FAR := Vector3(-100.0, 0.0, -100.0)

var _knobs: Knobs
var _map: MapData
var _holds: HoldService
var _obj: SurvivorObjectives
var _bus: EventBus
var _events: Array[EvObjectiveProgressChanged] = []
var _sounds: Array[Array] = []
var _feed: Dictionary = {}
var _centres: Dictionary = {}
var _tick := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	_feed = {}
	_events = []
	_sounds = []
	_tick = 0
	_map = MapData.load_map()
	_centres = {A: FAR, SHIFTER: FAR}
	_holds = HoldService.new(_knobs, func() -> Array: return _centres.keys(),
		func(actor: int) -> Array: return _feed.get(actor, []),
		func(actor: int) -> Vector3: return _centres[actor],
		func(_actor: int, _i: Interactable) -> bool: return true,
		func(actor: int) -> int: return _claimed(actor),
		Callable(),
		func(actor: int) -> bool: return actor == SHIFTER)
	_obj = SurvivorObjectives.new(_holds, _map, Callable(), Callable(),
		func(actor: int) -> Vector3: return _centres[actor])
	_obj.survivor_ids.assign([A])
	_obj.emit_sound = _on_sound
	_bus = EventBus.new(_knobs.core.max_flush_rounds)
	_bus.subscribe(&"ObjectiveProgressChanged", _on_progress)
	_obj.placement = FirstMarkers.of(_map)
	_obj.setup(null, _bus, StateRegistry.new(), _knobs)


func _on_progress(e: ServerEvent) -> void:
	_events.append(e as EvObjectiveProgressChanged)


func _on_sound(position: Vector3, sound_set: StringName, radius_m: float) -> void:
	_sounds.append([position, sound_set, radius_m])


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


func _t(seconds: float) -> int:
	return _knobs.ticks(seconds)


## Longer than any objective hold, so a real hold would have completed.
func _long() -> int:
	var o := _knobs.objectives
	return _t(maxf(maxf(o.drive_extract_s, o.fuse_install_s), maxf(o.dock_s, o.activation_start_s))) + 5


## The shapeshifter fakes `net_id` at `at` for _long() ticks; true if the hold stayed a fake throughout.
func _fake(net_id: int, at: Vector3) -> bool:
	_centres[SHIFTER] = at
	var faked := true
	for i in _long():
		_step({SHIFTER: [_f(true, net_id)]})
		var h := _holds.hold_of(SHIFTER)
		faked = faked and not h.is_empty() and h.fake and h.net_id == net_id
	_release(SHIFTER)
	return faked


func _real(actor: int, net_id: int, at: Vector3, seconds: float) -> void:
	_centres[actor] = at
	_hold(actor, net_id, _t(seconds))
	_release(actor)


func _arm() -> void:
	var o := _knobs.objectives
	for n in 2:
		_real(A, DRIVES + n, _point(&"drive", n), o.drive_extract_s)
		_real(A, SLOTS + n, _point(&"terminal", 0), o.dock_s)
	for n in 2:
		_real(A, FUSES + n, _point(&"fuse", n), o.pickup_s)
		_real(A, BOXES + n, _point(&"fuse_box", n), o.fuse_install_s)


func test_faking_consoles_fuses_and_boxes_changes_no_state() -> void:
	for n in 2:
		assert_bool(_fake(DRIVES + n, _point(&"drive", n))).is_true()
		assert_bool(_fake(FUSES + n, _point(&"fuse", n))).is_true()
		assert_bool(_fake(BOXES + n, _point(&"fuse_box", n))).is_true()
	assert_array(_events).is_empty()
	for n in 2:
		assert_int(_obj.state_of(n)).is_equal(SurvivorObjectives.DriveState.SECURED)
		assert_int(_obj.fuse_state_of(n)).is_equal(SurvivorObjectives.FuseState.UNFOUND)
		assert_int(_obj.box_fuse_of(n)).is_equal(-1)
	assert_int(_obj.carried_by(SHIFTER)).is_equal(0)


func test_faking_the_armed_terminal_starts_nothing() -> void:
	_arm()
	_events = []
	assert_bool(_fake(PANEL, _point(&"terminal", 0))).is_true()
	assert_bool(_fake(SLOTS, _point(&"terminal", 0))).is_true()
	assert_array(_events).is_empty()
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.ARMED)


func test_the_shapeshifter_in_the_zone_does_not_run_the_countdown() -> void:
	_arm()
	_real(A, PANEL, _point(&"terminal", 0), _knobs.objectives.activation_start_s)
	_centres[A] = FAR
	_centres[SHIFTER] = _point(&"terminal", 0)
	for i in _t(_knobs.objectives.evac_activation_s) + 5:
		_step()
	assert_int(_obj.terminal_state()).is_equal(SurvivorObjectives.TerminalState.ACTIVATING)


func test_a_survivor_start_cancels_the_fake_and_completes_normally() -> void:
	var at := _point(&"drive", 0)
	_centres[SHIFTER] = at
	_centres[A] = at
	_hold(SHIFTER, DRIVES, 3)
	assert_bool(_holds.hold_of(SHIFTER).fake).is_true()
	_step({SHIFTER: [_f(true, DRIVES)], A: [_f(true, DRIVES)]})
	assert_dict(_holds.hold_of(SHIFTER)).is_empty()
	assert_bool(_holds.hold_of(A).fake).is_false()
	for i in _t(_knobs.objectives.drive_extract_s):
		_step({SHIFTER: [_f(true, DRIVES)], A: [_f(true, DRIVES)]})
	assert_int(_obj.carrier_of(0)).is_equal(A)


func test_a_fake_install_makes_no_noise_and_no_alert() -> void:
	assert_bool(_fake(BOXES, _point(&"fuse_box", 0))).is_true()
	assert_array(_sounds).is_empty()
	assert_array(_events).is_empty()
	## the same box, a real install start: noise and alert both (the control)
	_real(A, FUSES, _point(&"fuse", 0), _knobs.objectives.pickup_s)
	_centres[A] = _point(&"fuse_box", 0)
	_step({A: [_f(true, BOXES)]})
	assert_int(_sounds.size()).is_equal(1)


func test_faking_a_dropped_fuse_or_drive_picks_up_nothing() -> void:
	_real(A, FUSES, _point(&"fuse", 0), _knobs.objectives.pickup_s)
	_real(A, DRIVES, _point(&"drive", 0), _knobs.objectives.drive_extract_s)
	_obj.drop(A, SurvivorObjectives.FUSE_ID)
	_obj.drop(A, SurvivorObjectives.DRIVE_ID)
	_step() ## flush the drop events
	_events = []
	assert_bool(_fake(DROPPED_FUSES, _obj.dropped_at(SurvivorObjectives.FUSE_ID))).is_true()
	assert_bool(_fake(DROPPED_DRIVES, _obj.dropped_at(SurvivorObjectives.DRIVE_ID))).is_true()
	assert_array(_events).is_empty()
	assert_int(_obj.fuse_state_of(0)).is_equal(SurvivorObjectives.FuseState.DROPPED)
	assert_int(_obj.state_of(0)).is_equal(SurvivorObjectives.DriveState.DROPPED)
