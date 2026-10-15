# Story survivor-objectives/002: item drops and pickups (survivor-objectives.md rules 11-13, 15, Edge
# Cases; ADR-0005, ADR-0008). Real HoldService + SurvivorObjectives on one bus and the real map; frames,
# centres and life state are fed by the test. Downing and Match Flow emit SurvivorDowned,
# SurvivorEliminated and PlayerConnectionChanged; here the test emits them on the bus directly.
extends GdUnitTestSuite

const A := 1
const B := 2
const FUSES := SurvivorObjectives.ACTIVE_DRIVES
const BOXES := FUSES + SurvivorObjectives.ACTIVE_FUSES
const SLOTS := BOXES + SurvivorObjectives.ACTIVE_FUSE_BOXES
const PANEL := SLOTS + SurvivorObjectives.ACTIVE_DRIVES
const PICKUPS := PANEL + 1
const FUSE_PICKUPS := PICKUPS + SurvivorObjectives.ACTIVE_DRIVES
const FAR := Vector3(-100.0, 0.0, -100.0)
const DRIVE := SurvivorObjectives.DriveState
const FUSE := SurvivorObjectives.FuseState

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
	_centres = {A: FAR, B: FAR}
	_holds = HoldService.new(knobs, func() -> Array: return _centres.keys(),
		func(actor: int) -> Array: return _feed.get(actor, []),
		func(actor: int) -> Vector3: return _centres[actor],
		func(_actor: int, _i: Interactable) -> bool: return true,
		func(actor: int) -> int: return _claimed(actor))
	_obj = SurvivorObjectives.new(_holds, _map, func(actor: int) -> bool: return not _downed.has(actor),
		Callable(), func(actor: int) -> Vector3: return _centres[actor])
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


## One tick in RoundServer slot order: Holds, Objectives, then the bus.
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
	_step({actor: [_f(false, 0)]})


func _t(seconds: float) -> int:
	return _knobs.ticks(seconds)


## A takes drive 0 and fuse 0, then stands at `at`.
func _load_a(at: Vector3) -> void:
	_centres[A] = _point(&"drive", 0)
	_hold(A, 0, _t(_knobs.objectives.drive_extract_s))
	_centres[A] = _point(&"fuse", 0)
	_hold(A, FUSES, _t(_knobs.objectives.pickup_s))
	assert_int(_obj.carrier_of(0)).is_equal(A)
	assert_int(_obj.fuse_carrier_of(0)).is_equal(A)
	_centres[A] = at
	_events = []


func _down(actor: int) -> void:
	_downed[actor] = true
	var e := EvSurvivorDowned.new()
	e.survivor = actor
	_bus.emit(e)
	_step()


func _eliminate(actor: int) -> void:
	_downed[actor] = true
	var e := EvSurvivorEliminated.new()
	e.survivor = actor
	_bus.emit(e)
	_step()


func _connection(actor: int, status: int) -> void:
	var e := EvPlayerConnectionChanged.new()
	e.player = actor
	e.status = status
	_bus.emit(e)
	_step()


func _dropped_events() -> Array[int]:
	var out: Array[int] = []
	for e in _events:
		if e.objective < SurvivorObjectives.FUSE_ID and e.state == DRIVE.DROPPED:
			out.append(e.objective)
		elif e.objective >= SurvivorObjectives.FUSE_ID and e.objective < SurvivorObjectives.FUSE_BOX_ID \
				and e.state == FUSE.DROPPED:
			out.append(e.objective)
	return out


## The floor centre of volume 1: a valid floor point, so a drop there lands unchanged.
func _floor_spot() -> Vector3:
	var box: AABB = _map.volumes[1].box
	return Vector3(box.get_center().x, box.position.y, box.get_center().z)


# --- AC-1: down drops, pickup by another -------------------------------------------------------

func test_downing_a_carrier_drops_drive_and_fuse_at_their_position() -> void:
	var spot := _floor_spot()
	_load_a(spot)
	_down(A)
	assert_int(_obj.state_of(0)).is_equal(DRIVE.DROPPED)
	assert_int(_obj.carrier_of(0)).is_equal(-1)
	assert_int(_obj.fuse_state_of(0)).is_equal(FUSE.DROPPED)
	assert_int(_obj.fuse_carrier_of(0)).is_equal(-1)
	assert_vector(_obj.dropped_at(SurvivorObjectives.DRIVE_ID)).is_equal(spot)
	assert_vector(_obj.dropped_at(SurvivorObjectives.FUSE_ID)).is_equal(spot)
	assert_array(_dropped_events()).contains_exactly_in_any_order([SurvivorObjectives.DRIVE_ID,
		SurvivorObjectives.FUSE_ID])
	for e in _events:
		assert_bool(e.discovered).is_true() ## "Drive dropped" is marked for all survivors (rule 12)


func test_another_healthy_survivor_picks_the_drops_up_with_a_pickup_hold() -> void:
	var spot := _floor_spot()
	_load_a(spot)
	_down(A)
	_centres[B] = spot
	_hold(B, PICKUPS, _t(_knobs.objectives.pickup_s) - 1)
	assert_int(_obj.state_of(0)).is_equal(DRIVE.DROPPED) ## one tick short of pickup_s
	_hold(B, PICKUPS, _t(_knobs.objectives.pickup_s))
	assert_int(_obj.state_of(0)).is_equal(DRIVE.CARRIED)
	assert_int(_obj.carrier_of(0)).is_equal(B)
	_hold(B, FUSE_PICKUPS, _t(_knobs.objectives.pickup_s))
	assert_int(_obj.fuse_state_of(0)).is_equal(FUSE.CARRIED)
	assert_int(_obj.fuse_carrier_of(0)).is_equal(B)


func test_a_downed_survivor_cannot_pick_their_drop_up() -> void:
	var spot := _floor_spot()
	_load_a(spot)
	_down(A)
	_hold(A, PICKUPS, _t(_knobs.objectives.pickup_s))
	assert_int(_obj.state_of(0)).is_equal(DRIVE.DROPPED)


func test_a_rescued_carrier_does_not_get_the_items_back() -> void:
	var spot := _floor_spot()
	_load_a(spot)
	_down(A)
	_downed.erase(A) ## rescued
	_step()
	assert_int(_obj.carried_by(A)).is_equal(0)
	assert_int(_obj.fuse_carrier_of(0)).is_equal(-1)
	_hold(A, PICKUPS, _t(_knobs.objectives.pickup_s)) ## must pick it up again
	assert_int(_obj.carrier_of(0)).is_equal(A)


func test_a_dropped_item_is_picked_up_where_it_fell_not_at_its_old_points() -> void:
	_load_a(_floor_spot())
	_down(A)
	_centres[B] = _point(&"fuse", 0) ## the fuse's spawn
	_hold(B, FUSES, _t(_knobs.objectives.pickup_s))
	_hold(B, FUSE_PICKUPS, _t(_knobs.objectives.pickup_s))
	assert_int(_obj.fuse_state_of(0)).is_equal(FUSE.DROPPED)
	_centres[B] = _point(&"terminal", 0) ## where ejected drives lie
	_hold(B, PICKUPS, _t(_knobs.objectives.pickup_s))
	assert_int(_obj.state_of(0)).is_equal(DRIVE.DROPPED)


func test_downed_while_docking_cancels_the_dock_and_drops_the_drive() -> void:
	_centres[A] = _point(&"drive", 0)
	_hold(A, 0, _t(_knobs.objectives.drive_extract_s))
	_centres[A] = _point(&"terminal", 0)
	for i in _t(_knobs.objectives.dock_s) - 1:
		_step({A: [_f(true, SLOTS)]})
	_down(A)
	for i in _t(_knobs.objectives.dock_s):
		_step({A: [_f(true, SLOTS)]})
	assert_int(_obj.state_of(0)).is_equal(DRIVE.DROPPED)
	assert_vector(_obj.dropped_at(SurvivorObjectives.DRIVE_ID)).is_equal(_point(&"terminal", 0))


func test_a_drive_dropped_before_docking_is_ejected_at_the_terminal() -> void:
	_centres[A] = _point(&"drive", 0)
	_hold(A, 0, _t(_knobs.objectives.drive_extract_s))
	_centres[A] = _floor_spot()
	_obj.drop(A, SurvivorObjectives.DRIVE_ID)
	_hold(A, PICKUPS, _t(_knobs.objectives.pickup_s))
	assert_int(_obj.carrier_of(0)).is_equal(A)
	_centres[A] = _point(&"drive", 1)
	_hold(A, 1, _t(_knobs.objectives.drive_extract_s))
	_centres[A] = _point(&"terminal", 0)
	for n in 2:
		_hold(A, SLOTS + n, _t(_knobs.objectives.dock_s))
	for n in 2:
		_centres[A] = _point(&"fuse", n)
		_hold(A, FUSES + n, _t(_knobs.objectives.pickup_s))
		_centres[A] = _point(&"fuse_box", n)
		_hold(A, BOXES + n, _t(_knobs.objectives.fuse_install_s))
	_centres[A] = _point(&"terminal", 0)
	_hold(A, PANEL, _t(_knobs.objectives.activation_start_s))
	for i in _t(_knobs.objectives.evac_activation_s):
		_step()
	assert_bool(_obj.exit_open()).is_true()
	assert_vector(_obj.dropped_at(SurvivorObjectives.DRIVE_ID)).is_equal(_point(&"terminal", 0))


# --- AC-2: elimination and disconnect ----------------------------------------------------------

func test_elimination_drops_carried_items_at_once() -> void:
	var spot := _floor_spot()
	_load_a(spot)
	_eliminate(A)
	assert_int(_obj.state_of(0)).is_equal(DRIVE.DROPPED)
	assert_int(_obj.fuse_state_of(0)).is_equal(FUSE.DROPPED)
	assert_vector(_obj.dropped_at(SurvivorObjectives.DRIVE_ID)).is_equal(spot)


func test_eliminated_after_down_does_not_drop_again() -> void:
	_load_a(_floor_spot())
	_down(A)
	_eliminate(A)
	assert_int(_dropped_events().size()).is_equal(2)


func test_disconnect_drops_carried_items_at_once_and_reconnect_changes_nothing() -> void:
	var spot := _floor_spot()
	_load_a(spot)
	_connection(A, EvPlayerConnectionChanged.RECONNECTED)
	assert_int(_obj.carrier_of(0)).is_equal(A)
	_connection(A, EvPlayerConnectionChanged.DISCONNECTED)
	assert_int(_obj.state_of(0)).is_equal(DRIVE.DROPPED)
	assert_int(_obj.fuse_state_of(0)).is_equal(FUSE.DROPPED)
	assert_vector(_obj.dropped_at(SurvivorObjectives.FUSE_ID)).is_equal(spot)
	_connection(A, EvPlayerConnectionChanged.RECONNECTED)
	assert_int(_obj.carried_by(A)).is_equal(0)


func test_a_dropped_item_never_despawns() -> void:
	var spot := _floor_spot()
	_load_a(spot)
	_down(A)
	for i in _t(600.0):
		_step()
	assert_int(_obj.state_of(0)).is_equal(DRIVE.DROPPED)
	assert_vector(_obj.dropped_at(SurvivorObjectives.DRIVE_ID)).is_equal(spot)
	_centres[B] = spot
	_hold(B, PICKUPS, _t(_knobs.objectives.pickup_s))
	assert_int(_obj.carrier_of(0)).is_equal(B)


func test_a_drop_lands_on_the_floor_below_the_carrier() -> void:
	var spot := _floor_spot()
	_load_a(spot + Vector3(0.0, 0.9, 0.0)) ## capsule centre height
	_down(A)
	assert_vector(_obj.dropped_at(SurvivorObjectives.DRIVE_ID)).is_equal(spot)


func test_a_drop_point_inside_geometry_moves_to_the_nearest_valid_floor_point() -> void:
	var v: MapVolume = _map.volumes[0]
	var mid_z := v.box.position.z + v.box.size.z / 2.0
	var inside_wall := Vector3(v.box.position.x - 0.5, 0.9, mid_z) ## west of the west wall
	_load_a(inside_wall)
	_down(A)
	var at := _obj.dropped_at(SurvivorObjectives.DRIVE_ID)
	assert_str(String(MapQueries.new(_map).volume_at(at))).is_equal(String(v.id))
	assert_float(at.y).is_equal(v.box.position.y)
	assert_float(Vector2(at.x - inside_wall.x, at.z - inside_wall.z).length()).is_equal_approx(0.5, 0.01)
	_centres[B] = at
	_hold(B, PICKUPS, _t(_knobs.objectives.pickup_s))
	assert_int(_obj.carrier_of(0)).is_equal(B)


# --- AC-3: manual drop -------------------------------------------------------------------------

func test_a_carrier_drops_one_item_on_purpose_instantly() -> void:
	var spot := _floor_spot()
	_load_a(spot)
	assert_bool(_obj.drop(A, SurvivorObjectives.DRIVE_ID)).is_true()
	assert_int(_obj.state_of(0)).is_equal(DRIVE.DROPPED)
	assert_vector(_obj.dropped_at(SurvivorObjectives.DRIVE_ID)).is_equal(spot)
	assert_int(_obj.fuse_carrier_of(0)).is_equal(A) ## the fuse stays carried
	assert_bool(_obj.drop(A, SurvivorObjectives.FUSE_ID)).is_true()
	assert_int(_obj.fuse_state_of(0)).is_equal(FUSE.DROPPED)
	_bus.flush()
	assert_array(_dropped_events()).contains_exactly([SurvivorObjectives.DRIVE_ID, SurvivorObjectives.FUSE_ID])


func test_only_the_carrier_can_drop_an_item() -> void:
	_load_a(_floor_spot())
	assert_bool(_obj.drop(B, SurvivorObjectives.DRIVE_ID)).is_false()
	assert_bool(_obj.drop(A, SurvivorObjectives.DRIVE_ID + 1)).is_false() ## drive 1 still Secured
	assert_bool(_obj.drop(A, SurvivorObjectives.FUSE_BOX_ID)).is_false()
	assert_bool(_obj.drop(A, SurvivorObjectives.TERMINAL_ID)).is_false()
	assert_int(_obj.carrier_of(0)).is_equal(A)


func test_dropping_during_a_dock_hold_cancels_the_dock() -> void:
	_centres[A] = _point(&"drive", 0)
	_hold(A, 0, _t(_knobs.objectives.drive_extract_s))
	_centres[A] = _point(&"terminal", 0)
	for i in _t(_knobs.objectives.dock_s) - 1:
		_step({A: [_f(true, SLOTS)]})
	assert_bool(_obj.drop(A, SurvivorObjectives.DRIVE_ID)).is_true()
	for i in _t(_knobs.objectives.dock_s):
		_step({A: [_f(true, SLOTS)]})
	assert_int(_obj.state_of(0)).is_equal(DRIVE.DROPPED)
	assert_dict(_holds.hold_of(A)).is_empty()


# --- AC-4: values from the knobs ---------------------------------------------------------------

func test_pickup_time_comes_from_the_knobs() -> void:
	var k := Knobs.load_all()
	k.objectives.pickup_s = 2.0
	assert_array(k.errors()).is_empty()
	_knobs = k
	_build(k)
	var spot := _floor_spot()
	_load_a(spot)
	_down(A)
	_centres[B] = spot
	_hold(B, PICKUPS, k.ticks(2.0) - 1)
	assert_int(_obj.state_of(0)).is_equal(DRIVE.DROPPED)
	_hold(B, PICKUPS, k.ticks(2.0))
	assert_int(_obj.carrier_of(0)).is_equal(B)


# --- Structure ---------------------------------------------------------------------------------

func test_the_module_is_freed_with_the_round_no_reference_cycle() -> void:
	var probe: WeakRef = weakref(_obj)
	_obj = null
	assert_object(probe.get_ref()).is_null()
