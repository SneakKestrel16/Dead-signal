# Story survivor-objectives/004: install noise and the monster alert (survivor-objectives.md rule 16,
# Formulas "Install alert placement"; ADR-0004 §5-6). Real HoldService + SurvivorObjectives on the real
# map's fuse and fuse box markers; frames, centres and sight are fed by the test.
extends GdUnitTestSuite

const A := 1
const MONSTER := 5
const SEED := 4004
const TRIALS := 50
const FUSES := SurvivorObjectives.ACTIVE_DRIVES ## net id of fuse 0: drives register first
const BOXES := SurvivorObjectives.ACTIVE_DRIVES + SurvivorObjectives.ACTIVE_FUSES

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
	_build()


func _build() -> void:
	_feed = {}
	_events = []
	_sounds = []
	_tick = 0
	_map = MapData.load_map()
	_centres = {A: _point(&"fuse", 0)}
	_holds = HoldService.new(_knobs, func() -> Array: return _centres.keys(),
		func(actor: int) -> Array: return _feed.get(actor, []),
		func(actor: int) -> Vector3: return _centres[actor],
		func(_actor: int, _i: Interactable) -> bool: return true,
		func(actor: int) -> int: return _claimed(actor))
	_obj = SurvivorObjectives.new(_holds, _map)
	_obj.rng.seed = SEED
	_obj.emit_sound = _on_sound
	_bus = EventBus.new(_knobs.core.max_flush_rounds)
	_bus.subscribe(&"ObjectiveProgressChanged", _on_progress)
	_obj.setup(null, _bus, StateRegistry.new(), _knobs)


func _on_progress(e: ServerEvent) -> void:
	_events.append(e as EvObjectiveProgressChanged)


func _on_sound(position: Vector3, sound_set: StringName, radius_m: float) -> void:
	_sounds.append([position, sound_set, radius_m])


func _alerts() -> Array[EvObjectiveProgressChanged]:
	var out: Array[EvObjectiveProgressChanged] = []
	for e in _events:
		if e.state == SurvivorObjectives.FuseState.INSTALLING:
			out.append(e)
	return out


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


func _pick_up_fuse() -> void:
	_hold(A, FUSES, _knobs.ticks(_knobs.objectives.pickup_s))
	_release(A)
	_centres[A] = _point(&"fuse_box", 0)


func _horizontal(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func test_alert_centre_contains_box_and_is_offset_in_most_trials() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var box := _point(&"fuse_box", 0)
	var r := _knobs.objectives.alert_area_radius_m
	var far := 0
	for i in TRIALS:
		var c := SurvivorObjectives.alert_centre(box, r, rng)
		assert_float(_horizontal(c, box)).is_less_equal(r)
		assert_float(c.y).is_equal(box.y)
		if _horizontal(c, box) > 1.0:
			far += 1
	assert_int(far).is_greater_equal(int(ceil(TRIALS * 0.9)))


func test_install_start_alerts_the_monster_alone() -> void:
	_pick_up_fuse()
	_events = []
	_step({A: [_f(true, BOXES)]})
	var alerts := _alerts()
	assert_int(alerts.size()).is_equal(1)
	var o := _knobs.objectives
	var m := alerts[0].project(MONSTER, null, MONSTER)
	assert_array(m.keys()).contains_exactly_in_any_order(["centre", "radius_m", "duration_s"])
	assert_float(m.radius_m).is_equal(o.alert_area_radius_m)
	assert_float(m.duration_s).is_equal(o.alert_duration_s)
	assert_float(_horizontal(m.centre, _point(&"fuse_box", 0))).is_less_equal(o.alert_area_radius_m)
	assert_dict(alerts[0].project(A, null, MONSTER)).is_empty()
	alerts[0].discovered = true ## the alert stays monster-only however the flag is set
	assert_dict(alerts[0].project(A, null, MONSTER)).is_empty()


func test_install_start_makes_the_install_noise() -> void:
	_pick_up_fuse()
	_sounds = []
	_step({A: [_f(true, BOXES)]})
	assert_int(_sounds.size()).is_equal(1)
	assert_vector(_sounds[0][0]).is_equal(_point(&"fuse_box", 0))
	assert_float(_sounds[0][2]).is_equal(_knobs.objectives.install_noise_radius_m)


func test_cancel_and_restart_raises_a_new_alert_and_completion_none() -> void:
	_pick_up_fuse()
	_hold(A, BOXES, 3)
	_release(A)
	_hold(A, BOXES, _knobs.ticks(_knobs.objectives.fuse_install_s))
	assert_int(_alerts().size()).is_equal(2)
	assert_int(_sounds.size()).is_equal(2)
	assert_int(_obj.box_fuse_of(0)).is_equal(0) ## installed; completing raised no third alert


func test_refused_install_raises_no_alert() -> void:
	_centres[A] = _point(&"fuse_box", 0) ## no fuse carried
	_hold(A, BOXES, 3)
	assert_array(_alerts()).is_empty()
	assert_array(_sounds).is_empty()


func test_alert_values_follow_the_knobs() -> void:
	_knobs.objectives.alert_area_radius_m = 6.0
	_knobs.objectives.alert_duration_s = 4.0
	_build()
	_pick_up_fuse()
	_step({A: [_f(true, BOXES)]})
	var m := _alerts()[0].project(MONSTER, null, MONSTER)
	assert_float(m.radius_m).is_equal(6.0)
	assert_float(m.duration_s).is_equal(4.0)
	assert_float(_horizontal(m.centre, _point(&"fuse_box", 0))).is_less_equal(6.0)
