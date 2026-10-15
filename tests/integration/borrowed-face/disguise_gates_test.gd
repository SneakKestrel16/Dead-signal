# Story borrowed-face/006: disguise gates on objectives, rescue and defense interactions
# (design/gdd/borrowed-face.md rule 12, tell T4, Acceptance Criteria drive/rescue/hiding/barricade/search;
# ADR-0008 §2, §6). Real HoldService with the role Callable on every part. Disguise is not an input:
# HoldService and the owners decide from the role alone, so a disguised and a true-form shapeshifter take
# the same path (no form is consulted anywhere on these gates).
# Objectives: real SurvivorObjectives on the real map (every point fakeable: a fake hold, no state change).
# Rescue: real Downing on a RoundServer (RescueHold not fakeable: Downing.can_rescue refuses the role).
# Hiding, barricade, search: Survivor Defense has not landed, so these are fixture interactables using
# the GDD's eligibility rule (Survivor Defense rules 19, 22, 25-27: hide and barricade are Healthy-survivor
# actions, search is a monster action in any form). Re-run against the real ones when that epic lands.
extends GdUnitTestSuite

const A := 1
const SHIFTER := 5 ## not in survivor_ids
const DRIVES := 0
const FUSES := SurvivorObjectives.ACTIVE_DRIVES
const BOXES := FUSES + SurvivorObjectives.ACTIVE_FUSES
const SLOTS := BOXES + SurvivorObjectives.ACTIVE_FUSE_BOXES
const FAR := Vector3(-100.0, 0.0, -100.0)
## Fixture hold length: any non-zero duration; the gate refuses on the Start tick.
const FIXTURE_HOLD_S := 1.0

## Rescue part (rescue_hold_test.gd roster).
const MONSTER := 1
const S1 := 2 ## the Downed survivor
const R := 3 ## a survivor rescuer (the control)
const SURVIVORS: Array[int] = [2, 3, 4, 5]


## A Survivor Defense stand-in: one hiding spot, barricade or search point. `allowed` is the owner's
## eligibility rule; `completions` is the spot or door state the hold would change.
class Fixture extends Interactable:
	var allowed: Callable
	var completions: int = 0

	func eligible(actor: int) -> bool:
		return allowed.call(actor)

	func start_progress_s() -> float:
		return 0.0

	func on_complete(_actor: int) -> void:
		completions += 1

	func on_cancel(_actor: int, _progress_s: float, _reason: StringName) -> void:
		pass


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
	_obj.setup(null, _bus, StateRegistry.new(), _knobs)


func after_test() -> void:
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


## Healthy-survivor actions (hide, barricade, remove barricade).
func _survivor_only(actor: int) -> bool:
	return actor != SHIFTER


## A monster action in any form (search).
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


func _fixture(rule: Callable) -> Fixture:
	var x := Fixture.new()
	x.allowed = rule
	x.point = Vector3.ZERO
	x.range_m = 2.0
	x.duration_s = FIXTURE_HOLD_S
	_holds.register(x)
	return x


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
	_centres[A] = FAR
	for x: Fixture in [_fixture(_survivor_only), _fixture(_survivor_only), _fixture(_survivor_only)]:
		_centres[SHIFTER] = Vector3.ZERO
		for i in _knobs.ticks(FIXTURE_HOLD_S) + 5:
			_step({SHIFTER: [_f(true, x.net_id)]})
			assert_dict(_holds.hold_of(SHIFTER)).is_empty()
		_step({SHIFTER: [_f(false)]})
		assert_int(x.completions).is_equal(0)
		## the control: a survivor on the same spot completes it
		_centres[A] = Vector3.ZERO
		for i in _knobs.ticks(FIXTURE_HOLD_S) + 2:
			_step({A: [_f(true, x.net_id)]})
		_step({A: [_f(false)]})
		_centres[A] = FAR
		assert_int(x.completions).is_equal(1)


func test_search_is_a_real_monster_hold_in_any_form() -> void:
	var search := _fixture(_monster_only)
	_centres[SHIFTER] = Vector3.ZERO
	_step({SHIFTER: [_f(true, search.net_id)]})
	assert_bool(_holds.hold_of(SHIFTER).fake).is_false()
	for i in _knobs.ticks(FIXTURE_HOLD_S) + 2:
		_step({SHIFTER: [_f(true, search.net_id)]})
	assert_int(search.completions).is_equal(1)


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
