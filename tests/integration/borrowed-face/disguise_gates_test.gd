# Story borrowed-face/006: disguise gates on objectives, rescue and defense interactions
# (design/gdd/borrowed-face.md rule 12, tell T4, Acceptance Criteria drive/rescue/hiding/barricade/search;
# ADR-0008 §2, §6). Real HoldService with the role Callable on every part. Disguise is not an input:
# HoldService and the owners decide from the role alone, so a disguised and a true-form shapeshifter take
# the same path (no form is consulted anywhere on these gates).
# Objectives: real SurvivorObjectives on the real map (every point fakeable: a fake hold, no state change).
# Rescue: real Downing on a RoundServer (RescueHold not fakeable: Downing.can_rescue refuses the role).
# Hiding, barricade, search: the real HidingSpots, Doors and Barricades on the real map, on the same HoldService
# (Survivor Defense rules 19, 22, 25-27; survivor-defense story 012 retired the fixture interactables).
extends GdUnitTestSuite

const A := 1
const SHIFTER := 5 ## not in survivor_ids
const DRIVES := 0
const FUSES := SurvivorObjectives.ACTIVE_DRIVES
const BOXES := FUSES + SurvivorObjectives.ACTIVE_FUSES
const SLOTS := BOXES + SurvivorObjectives.ACTIVE_FUSE_BOXES
const FAR := Vector3(-100.0, 0.0, -100.0)

## Rescue part (rescue_hold_test.gd roster).
const MONSTER := 1
const S1 := 2 ## the Downed survivor
const R := 3 ## a survivor rescuer (the control)
const SURVIVORS: Array[int] = [2, 3, 4, 5]


var _knobs: Knobs
var _map: MapData
var _holds: HoldService
var _obj: SurvivorObjectives
var _bus: EventBus
var _events: Array[EvObjectiveProgressChanged] = []
var _feed: Dictionary = {}
var _centres: Dictionary = {}
var _tick := 0
var _server: RoundServer
var _d: Downing
var _registry: StateRegistry
var _hs: HidingSpots
var _bars: Barricades
var _doors: Doors
var _door_holds: HoldService
## SurvivorDefense.set_hidden as HidingSpots drives it: actor -> hidden.
var _hidden: Dictionary[int, bool] = {}


func before_test() -> void:
	_knobs = Knobs.load_all()
	_feed = {}
	_events = []
	_tick = 0
	_server = null
	_map = MapData.load_map()
	_centres = {A: FAR, SHIFTER: FAR}
	_holds = HoldService.new(_knobs, _ids, _frames, _centre, _sight, _claimed, Callable(), _is_shifter)
	_obj = SurvivorObjectives.new(_holds, _map, Callable(), Callable(), _centre)
	_obj.survivor_ids.assign([A])
	_bus = EventBus.new(_knobs.core.max_flush_rounds)
	_bus.subscribe(&"ObjectiveProgressChanged", _on_progress)
	_registry = StateRegistry.new()
	_obj.placement = FirstMarkers.of(_map)
	_obj.setup(null, _bus, _registry, _knobs)
	_hidden = {}
	## Registered after the objectives, so their net ids (DRIVES..SLOTS) are unchanged.
	## Doors take net ids 0.. (a door's net id is its map index), so doors and barricades get their own
	## HoldService with the same role gate; the objectives above keep theirs.
	_door_holds = HoldService.new(_knobs, _ids, _frames, _centre, _sight, _claimed, Callable(), _is_shifter)
	_doors = Doors.new(_door_holds, _map, _no_capsules)
	_doors.setup(null, null, _registry, _knobs)
	_bars = Barricades.new(_door_holds, _doors, _map, _survivor_only, _no_capsules, _monster_only)
	_bars.setup(null, _bus, _registry, _knobs)
	_hs = HidingSpots.new(_holds, _map, _survivor_only, _monster_only, _set_hidden)
	_hs.setup(null, _bus, _registry, _knobs)


func after_test() -> void:
	_registry.clear()
	if _server != null:
		_server.end_round()


func _ids() -> Array:
	return _centres.keys()


func _frames(actor: int) -> Array:
	return _feed.get(actor, [])


func _centre(actor: int) -> Vector3:
	return _centres.get(actor, Vector3.ZERO)


func _sight(_actor: int, _i: Interactable) -> bool:
	return true


func _is_shifter(actor: int) -> bool:
	return actor == SHIFTER


func _is_monster(actor: int) -> bool:
	return actor == MONSTER


func _no_capsules() -> Array[Vector4]:
	return []


func _set_hidden(actor: int, on: bool) -> void:
	_hidden[actor] = on


## Healthy-survivor actions (hide, barricade, remove barricade): HidingSpots' and Barricades' `healthy`.
func _survivor_only(actor: int) -> bool:
	return actor != SHIFTER


## A monster action in any form (search, break): their `is_monster` / `monster`.
func _monster_only(actor: int) -> bool:
	return actor == SHIFTER


func _on_progress(e: ServerEvent) -> void:
	_events.append(e as EvObjectiveProgressChanged)


func _claimed(actor: int) -> int:
	var id := -1
	for f: InputFrame in _feed.get(actor, []):
		if f.interact:
			id = f.interact_target
	return id


func _f(interact: bool, target := 0, body := false) -> InputFrame:
	var f := InputFrame.new()
	f.interact = interact
	f.interact_target = target
	f.target_is_body = body
	return f


func _step(frames: Dictionary = {}) -> void:
	for actor: int in frames:
		_feed[actor] = frames[actor]
	_holds.server_tick(_tick)
	if _door_holds != null:
		_door_holds.server_tick(_tick)
	_obj.server_tick(_tick)
	_bus.flush()
	_tick += 1


func _point(type: StringName, n: int) -> Vector3:
	var seen := 0
	for m: MapMarker in _map.markers:
		if m.type == type:
			if seen == n:
				return m.position
			seen += 1
	return Vector3.ZERO


## Longer than any objective hold, so a real hold would have completed.
func _long() -> int:
	var o := _knobs.objectives
	return _knobs.ticks(maxf(maxf(o.drive_extract_s, o.fuse_install_s), maxf(o.dock_s, o.pickup_s))) + 5


## The shapeshifter holds `net_id` at `at` for _long() ticks, then releases. True when it never held
## anything but a fake.
func _try(net_id: int, at: Vector3) -> bool:
	_centres[SHIFTER] = at
	var faked := true
	for i in _long():
		_step({SHIFTER: [_f(true, net_id)]})
		var h := _holds.hold_of(SHIFTER)
		faked = faked and (h.is_empty() or h.fake)
	_step({SHIFTER: [_f(false)]})
	return faked


## `actor` stands on `at` and holds `net_id` on `holds` for `n` ticks, then releases. The shapeshifter
## never gets a hold.
func _hold(actor: int, net_id: int, at: Vector3, n: int, holds := _holds) -> void:
	_centres[actor] = at
	# SD-14: an alt hold (a door's Barricade, Remove, Break) answers interact_alt only.
	var f := _f(true, net_id)
	f.interact_alt = holds._items[net_id].alt
	for i in n:
		_step({actor: [f]})
		if actor == SHIFTER:
			assert_dict(holds.hold_of(SHIFTER)).is_empty()
	_step({actor: [_f(false)]})
	_centres[actor] = FAR


## The first barricadable door's net id and its interaction point.
func _door() -> Array:
	var targets := _map.interactables()
	for i in targets.size():
		var p := targets[i] as MapPassage
		if p != null and p.kind == MapPassage.BARRICADABLE:
			return [i, p.position + Vector3.UP * MapQueries.InteractRules.from_knobs(_knobs).point_height_m]
	return [-1, FAR]


# AC-1: pickup and install requests change no objective state, so no client sees a change -----------

func test_pickups_and_installs_change_no_objective_state() -> void:
	for n in 2:
		assert_bool(_try(DRIVES + n, _point(&"drive", n))).is_true()
		assert_bool(_try(FUSES + n, _point(&"fuse", n))).is_true()
		assert_bool(_try(BOXES + n, _point(&"fuse_box", n))).is_true()
		assert_bool(_try(SLOTS + n, _point(&"terminal", 0))).is_true()
	## No ObjectiveProgressChanged: the only thing clients rebuild objective state from (story SO-010).
	assert_array(_events).is_empty()
	for n in 2:
		assert_int(_obj.state_of(n)).is_equal(SurvivorObjectives.DriveState.SECURED)
		assert_int(_obj.fuse_state_of(n)).is_equal(SurvivorObjectives.FuseState.UNFOUND)
		assert_int(_obj.box_fuse_of(n)).is_equal(-1)
	assert_int(_obj.carried_by(SHIFTER)).is_equal(0)


# AC-3: hide, barricade and remove-barricade are refused; search plays for the monster ---------------

func test_hide_barricade_and_unbarricade_are_refused_with_state_unchanged() -> void:
	var hide_n := _knobs.ticks(_knobs.defense.hide_transition_s) + 2
	var build_n := _knobs.ticks(_knobs.defense.barricade_duration_s) + 2
	var remove_n := _knobs.ticks(_knobs.defense.barricade_remove_s) + 2
	var door: int = _door()[0]
	var at_door: Vector3 = _door()[1]
	assert_int(door).is_not_equal(-1)
	## hide: refused; the control, a survivor, enters and then leaves
	_hold(SHIFTER, _hs.hide_id(0), _hs.point(0), hide_n)
	assert_int(_hs.occupant(0)).is_equal(-1)
	assert_bool(_hidden.has(SHIFTER)).is_false()
	_hold(A, _hs.hide_id(0), _hs.point(0), hide_n)
	assert_int(_hs.occupant(0)).is_equal(A)
	_hold(A, _hs.hide_id(0), _hs.point(0), hide_n)
	assert_int(_hs.occupant(0)).is_equal(-1)
	## barricade (on a closed door, rule 25): refused; the control builds it
	assert_bool(_doors.toggle(door)).is_true()
	_hold(SHIFTER, _bars.build_id(door), at_door, build_n, _door_holds)
	assert_bool(_bars.is_barricaded(door)).is_false()
	_hold(A, _bars.build_id(door), at_door, build_n, _door_holds)
	assert_bool(_bars.is_barricaded(door)).is_true()
	## remove barricade: refused; the control removes it
	_hold(SHIFTER, _bars.remove_id(door), at_door, remove_n, _door_holds)
	assert_bool(_bars.is_barricaded(door)).is_true()
	_hold(A, _bars.remove_id(door), at_door, remove_n, _door_holds)
	assert_bool(_bars.is_barricaded(door)).is_false()


func test_search_is_a_real_monster_hold_in_any_form() -> void:
	_hold(A, _hs.hide_id(0), _hs.point(0), _knobs.ticks(_knobs.defense.hide_transition_s) + 2)
	assert_int(_hs.occupant(0)).is_equal(A)
	_centres[SHIFTER] = _hs.point(0)
	_step({SHIFTER: [_f(true, _hs.search_id(0))]})
	assert_bool(_holds.hold_of(SHIFTER).fake).is_false()
	for i in _knobs.ticks(_knobs.defense.search_duration_s) + 2:
		_step({SHIFTER: [_f(true, _hs.search_id(0))]})
	assert_int(_hs.occupant(0)).is_equal(-1) ## the search ejected the hidden survivor
	assert_bool(_hidden[A]).is_false()


# AC-2: a rescue request on a Downed survivor is refused and the bleed-out timer runs as if nobody held -

func _start_downing() -> void:
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_feed = {}
	_centres = {} ## everyone stands at the origin, on the body, in range
	_holds = HoldService.new(_knobs, _downing_players, _frames, _centre, _sight, _no_aim, _body_target,
		_is_monster)
	_d = Downing.new()
	_d.set_roster(SURVIVORS, MONSTER)
	_d.set_positions(_centre)
	_d.set_holds(_holds)
	var abilities := Emitter.new()
	assert_array(_server.start_round({TickOrder.MONSTER_ABILITIES: abilities, TickOrder.DOWNING: _d,
		TickOrder.HOLDS: HoldsStep.new(_holds)}, _knobs)).is_empty()
	var hit := EvSurvivorHit.new()
	hit.survivor = S1
	abilities.at(_server.tick_runner.current_tick() + 1, hit)
	_tick_server(1 + _knobs.ticks(_knobs.downing.takedown_commit_s))
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.DOWNED)


func _downing_players() -> Array:
	return SURVIVORS + [MONSTER]


func _no_aim(_actor: int) -> int:
	return -1


func _body_target(_actor: int, handle: int) -> int:
	return _d.rescue_net_id(handle)


func _tick_server(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


## `actor` (or nobody, -1) holds Rescue on S1 for `n` ticks; returns the bleed-out time that elapsed.
func _bleed_over(actor: int, n: int) -> float:
	for p: int in _downing_players():
		_feed[p] = [_f(p == actor, S1, true)]
	var before := _d.bleed_elapsed_s(S1)
	for i in n:
		_tick_server(1)
		if actor == MONSTER:
			assert_dict(_holds.hold_of(MONSTER)).is_empty()
	return _d.bleed_elapsed_s(S1) - before


func test_rescue_is_refused_and_bleed_out_is_unchanged() -> void:
	_start_downing()
	var n := _knobs.ticks(_knobs.downing.rescue_duration_s) + 2
	var idle := _bleed_over(-1, n)
	var held := _bleed_over(MONSTER, n)
	assert_float(idle).is_greater(0.0)
	assert_float(held).is_equal_approx(idle, 1e-6)
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.DOWNED)
	## the control: a survivor's hold pauses bleed-out (so the measure can see a change). Downing runs
	## before Holds, so the Start tick still bleeds; measure from the next one.
	_bleed_over(R, 1)
	assert_float(_bleed_over(R, 3)).is_equal(0.0)


## Runs HoldService in the HOLDS slot (stands in for the composer's Holds step).
class HoldsStep extends RefCounted:
	var _holds: HoldService

	func _init(holds: HoldService) -> void:
		_holds = holds

	func setup(_runner: TickRunner, _bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
		pass

	func server_tick(tick: int) -> void:
		_holds.server_tick(tick)


## Emits each scheduled event in its own tick slot (stands in for Monster Abilities).
class Emitter extends RefCounted:
	var _bus: EventBus
	var _due: Dictionary[int, Array] = {}

	func setup(_runner: TickRunner, bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
		_bus = bus

	func at(tick: int, e: ServerEvent) -> void:
		if not _due.has(tick):
			_due[tick] = []
		_due[tick].append(e)

	func server_tick(tick: int) -> void:
		for e: ServerEvent in _due.get(tick, []):
			_bus.emit(e)
