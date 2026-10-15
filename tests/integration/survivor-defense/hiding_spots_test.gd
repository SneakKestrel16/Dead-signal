# Story survivor-defense/006: hiding spots, enter, exit, occupancy and search
# (design/gdd/survivor-defense.md rules 15, 18-20, 22, 23, 28a and the hiding edge cases; ADR-0008 holds).
# Integration: real HoldService, SurvivorDefense (hidden state, items, the shock that stuns and cancels),
# Downing (lunge eligibility reads the hidden state) and SurvivorObjectives on the real map's hiding
# spots. Bodies are fixture centres standing on the spots; the Healthy gate is the composer's Callable.
extends GdUnitTestSuite

const A := 1 ## survivor
const B := 2 ## survivor
const M := 3 ## the monster
const SURVIVORS: Array[int] = [A, B]
const FAR := Vector3(-100.0, 0.0, -100.0)

var _knobs: Knobs
var _map: MapData
var _server: RoundServer
var _holds: HoldService
var _sd: SurvivorDefense
var _d: Downing
var _obj: SurvivorObjectives
var _hs: HidingSpots
var _feed: Dictionary = {}
var _centres: Dictionary = {}
var _mods: Dictionary = {}
var _downed: Dictionary = {}
var _placed: Array = []


## Runs HoldService in the HOLDS slot (stands in for the composer's Holds step).
class HoldsStep extends RefCounted:
	var _holds: HoldService

	func _init(holds: HoldService) -> void:
		_holds = holds

	func setup(_runner: TickRunner, _bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
		pass

	func server_tick(tick: int) -> void:
		_holds.server_tick(tick)


func before_test() -> void:
	_knobs = Knobs.load_all()
	_map = MapData.load_map()
	_feed = {}
	_downed = {}
	_placed = []
	_centres = {A: FAR, B: FAR, M: FAR}
	_mods = {A: MovementModifiers.new(), B: MovementModifiers.new(), M: MovementModifiers.new()}
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_holds = HoldService.new(_knobs, _players, _frames, _centre, _sight, _claimed)
	_sd = SurvivorDefense.new()
	_sd.set_roster(SURVIVORS, M)
	_sd.set_holds(_holds)
	_sd.set_modifiers(_mods_of)
	_holds.set_barred(_sd.locked)
	_d = Downing.new()
	_d.set_roster(SURVIVORS, M)
	_d.set_positions(_centre)
	_d.set_holds(_holds)
	_d.set_hidden(_sd.is_hidden)
	_obj = SurvivorObjectives.new(_holds, _map, _not_hidden, _sd.is_hidden, _centre)
	_obj.survivor_ids.assign(SURVIVORS)
	_obj.placement = FirstMarkers.of(_map)
	_obj.setup(null, EventBus.new(_knobs.core.max_flush_rounds), StateRegistry.new(), _knobs)
	_hs = HidingSpots.new(_holds, _map, _healthy, _is_monster, _sd.set_hidden, _mods_of, _place)
	_hs.setup(null, null, StateRegistry.new(), _knobs)
	assert_array(_server.start_round({TickOrder.SURVIVOR_DEFENSE: _sd, TickOrder.DOWNING: _d,
		TickOrder.HOLDS: HoldsStep.new(_holds)}, _knobs)).is_empty()


func after_test() -> void:
	_server.end_round()


func _players() -> Array:
	return _centres.keys()


func _frames(actor: int) -> Array:
	return _feed.get(actor, [])


func _centre(actor: int) -> Vector3:
	return _centres.get(actor, FAR)


func _sight(_actor: int, _i: Interactable) -> bool:
	return true


func _claimed(actor: int) -> int:
	var id := -1
	for f: InputFrame in _feed.get(actor, []):
		if f.interact:
			id = f.interact_target
	return id


func _mods_of(actor: int) -> MovementModifiers:
	return _mods.get(actor)


## The composer's Healthy gate: a survivor not Downed (Downing) and not shock-locked.
func _healthy(actor: int) -> bool:
	return SURVIVORS.has(actor) and not _downed.has(actor) and not _sd.locked(actor)


## Objectives' is_healthy as the composer wires it: its pickups and installs read only this gate (its
## is_hidden feeds the terminal zone), so the composer folds SurvivorDefense's hidden state in.
func _not_hidden(actor: int) -> bool:
	return not _sd.is_hidden(actor)


func _is_monster(actor: int) -> bool:
	return actor == M


func _place(actor: int, at: Vector3) -> void:
	_placed.append([actor, at])


func _f(interact: bool, target: int) -> InputFrame:
	var f := InputFrame.new()
	f.interact = interact
	f.interact_target = target
	return f


func _tick() -> int:
	return _server.tick_runner.current_tick()


## One server tick; each actor in `frames` holds (true) or releases (false) interact on its target.
func _step(frames: Dictionary) -> void:
	_feed = {}
	for actor: int in frames:
		_feed[actor] = [_f(frames[actor][1], frames[actor][0])]
	_server.tick_runner.step()


func _hold(actors: Dictionary, n: int) -> void:
	var frames := {}
	for actor: int in actors:
		frames[actor] = [actors[actor], true]
	for i in n:
		_step(frames)


func _release(actor: int) -> void:
	_step({actor: [-1, false]})


func _at_spot(actor: int, spot: int) -> void:
	_centres[actor] = _hs.point(spot)


func _t_hide() -> int:
	return _knobs.ticks(_knobs.defense.hide_transition_s)


func _t_search() -> int:
	return _knobs.ticks(_knobs.defense.search_duration_s)


func _hide(actor: int, spot: int) -> void:
	_at_spot(actor, spot)
	_hold({actor: _hs.hide_id(spot)}, _t_hide())
	_release(actor)
	assert_bool(_sd.is_hidden(actor)).is_true()


# --- AC-1: entering -----------------------------------------------------------------------------------

func test_enter_takes_hide_transition_rooted_and_resets_on_cancel() -> void:
	_at_spot(A, 0)
	_hold({A: _hs.hide_id(0)}, _t_hide() - 1)
	assert_bool(_sd.is_hidden(A)).is_false()
	assert_bool(_holds.hold_of(A).roots).is_true()
	assert_bool(_d.eligible(A)).is_true() ## targetable until hidden
	_release(A)
	_hold({A: _hs.hide_id(0)}, _t_hide() - 1)
	assert_bool(_sd.is_hidden(A)).is_false() ## progress was reset
	_hold({A: _hs.hide_id(0)}, 1)
	assert_bool(_sd.is_hidden(A)).is_true()
	assert_int(_hs.occupant(0)).is_equal(A)
	assert_bool((_mods[A] as MovementModifiers).rooted).is_true()
	assert_bool(_d.eligible(A)).is_false()


func test_two_survivors_entering_the_same_tick_leave_one_occupant() -> void:
	_at_spot(A, 0)
	_at_spot(B, 0)
	_hold({A: _hs.hide_id(0), B: _hs.hide_id(0)}, _t_hide() + 2)
	assert_int(int(_sd.is_hidden(A)) + int(_sd.is_hidden(B))).is_equal(1)
	var out := B if _sd.is_hidden(A) else A
	_release(out)
	_hold({out: _hs.hide_id(0)}, _t_hide() + 2) ## an occupied spot refuses a second survivor
	assert_bool(_sd.is_hidden(out)).is_false()
	assert_dict(_holds.hold_of(out)).is_empty()


func test_exit_takes_hide_transition_and_frees_the_spot() -> void:
	_hide(A, 0)
	_hold({A: _hs.hide_id(0)}, _t_hide() - 1)
	assert_bool(_sd.is_hidden(A)).is_true()
	_hold({A: _hs.hide_id(0)}, 1)
	assert_bool(_sd.is_hidden(A)).is_false()
	assert_int(_hs.occupant(0)).is_equal(-1)
	assert_bool((_mods[A] as MovementModifiers).rooted).is_false()


# --- AC-2: hidden limits --------------------------------------------------------------------------------

func test_hidden_survivor_cannot_fire_object_or_be_lunged_and_keeps_kit() -> void:
	_sd.request_intent(A, SurvivorDefense.light_packet(true))
	_hide(A, 0)
	var charges := _sd.charges(A)
	assert_int(charges).is_greater(0)
	assert_bool(_sd.can_fire(A, _tick())).is_false()
	_sd.request_intent(A, SurvivorDefense.fire_packet())
	_step({})
	assert_int(_sd.charges(A)).is_equal(charges)
	assert_bool(_sd.flashlight_on(A)).is_true()
	assert_bool(_d.eligible(A)).is_false() ## lunge target
	## an objective hold is refused while hidden (Objectives reads the same hidden state)
	_centres[A] = _marker(&"drive")
	_hold({A: 0}, 2)
	assert_dict(_holds.hold_of(A)).is_empty()
	_centres[B] = _marker(&"drive") ## the control: a survivor who is not hidden starts it
	_hold({B: 0}, 1)
	assert_bool(_holds.hold_of(B).is_empty()).is_false()


func test_hit_on_the_tick_hiding_completes_wins() -> void:
	_at_spot(A, 0)
	_hold({A: _hs.hide_id(0)}, _t_hide() - 1)
	_sd.shock(A, _tick() + 1) ## SurvivorDefense's slot runs before Holds on that tick
	_hold({A: _hs.hide_id(0)}, 1)
	assert_bool(_sd.is_hidden(A)).is_false()
	assert_int(_hs.occupant(0)).is_equal(-1)


# --- AC-3: search ---------------------------------------------------------------------------------------

func test_search_ejects_the_occupant_in_front_without_a_down() -> void:
	_hide(A, 0)
	_at_spot(M, 0)
	_hold({M: _hs.search_id(0)}, _t_search() - 1)
	assert_bool(_holds.hold_of(M).roots).is_true()
	assert_bool(_sd.is_hidden(A)).is_true()
	_hold({M: _hs.search_id(0)}, 1)
	assert_bool(_sd.is_hidden(A)).is_false()
	assert_int(_hs.occupant(0)).is_equal(-1)
	assert_bool((_mods[A] as MovementModifiers).rooted).is_false()
	assert_array(_placed).is_equal([[A, _placed_front(0)]]) ## SD-13: in front of the spot
	assert_int(_d.life_state(A)).is_equal(Downing.LifeState.HEALTHY)
	assert_bool(_d.eligible(A)).is_true()


func test_search_of_an_empty_spot_does_nothing_and_survivors_cannot_search() -> void:
	_at_spot(A, 1)
	_hold({A: _hs.search_id(1)}, 2)
	assert_dict(_holds.hold_of(A)).is_empty()
	_release(A)
	_at_spot(M, 0)
	_hold({M: _hs.search_id(0)}, _t_search() + 1)
	assert_array(_placed).is_empty()
	assert_int(_hs.occupant(0)).is_equal(-1)
	assert_bool(_sd.is_hidden(A)).is_false()


func test_stun_interrupts_the_search_and_resets_it() -> void:
	_hide(A, 0)
	_at_spot(M, 0)
	_hold({M: _hs.search_id(0)}, _t_search() - 1)
	_sd.shock(M, _tick())
	assert_dict(_holds.hold_of(M)).is_empty()
	_release(M)
	_hold({M: _hs.search_id(0)}, _knobs.ticks(_knobs.defense.stun_duration_s))
	assert_bool(_sd.is_hidden(A)).is_true()
	_release(M)
	_hold({M: _hs.search_id(0)}, _t_search() - 1)
	assert_bool(_sd.is_hidden(A)).is_true() ## progress started over
	_hold({M: _hs.search_id(0)}, 1)
	assert_bool(_sd.is_hidden(A)).is_false()


func test_search_ending_the_tick_the_occupant_leaves() -> void:
	_hide(A, 0)
	_at_spot(M, 0)
	_hold({M: _hs.search_id(0)}, _t_search() - _t_hide())
	_hold({M: _hs.search_id(0), A: _hs.hide_id(0)}, _t_hide())
	assert_bool(_sd.is_hidden(A)).is_false()
	assert_int(_hs.occupant(0)).is_equal(-1)
	assert_bool((_mods[A] as MovementModifiers).rooted).is_false()
	assert_int(_d.life_state(A)).is_equal(Downing.LifeState.HEALTHY)


# --- AC-4: search during entry; only Healthy survivors hide ----------------------------------------------

func test_search_on_a_spot_being_entered_lets_entry_finish_then_ejects() -> void:
	_at_spot(M, 0)
	_at_spot(A, 0)
	var lead := _t_search() - _t_hide() + 2 ## the search completes two ticks before the entry
	_hold({M: _hs.search_id(0)}, lead)
	_hold({M: _hs.search_id(0), A: _hs.hide_id(0)}, _t_hide() - 2)
	assert_dict(_holds.hold_of(M)).is_empty() ## search done
	assert_bool(_holds.hold_of(A).is_empty()).is_false() ## entry still running
	assert_bool(_sd.is_hidden(A)).is_false()
	assert_array(_placed).is_empty()
	_hold({A: _hs.hide_id(0)}, 2)
	assert_bool(_sd.is_hidden(A)).is_false()
	assert_int(_hs.occupant(0)).is_equal(-1)
	assert_int(_placed.size()).is_equal(1)
	assert_bool(_placed[0][1].is_equal_approx(_placed_front(0))).is_true() ## SD-13: in front after the entry
	## the pending eject was spent: a later entry stays hidden
	_release(A)
	_hold({A: _hs.hide_id(0)}, _t_hide())
	assert_bool(_sd.is_hidden(A)).is_true()


func test_entry_cancelled_after_a_search_leaves_nothing_pending() -> void:
	_at_spot(M, 0)
	_at_spot(A, 0)
	_hold({M: _hs.search_id(0)}, _t_search() - _t_hide() + 2)
	_hold({M: _hs.search_id(0), A: _hs.hide_id(0)}, _t_hide() - 2)
	_release(A)
	_hold({A: _hs.hide_id(0)}, _t_hide())
	assert_bool(_sd.is_hidden(A)).is_true()
	assert_array(_placed).is_empty()


func test_only_healthy_survivors_can_hide() -> void:
	_downed[A] = true
	_at_spot(A, 0)
	_hold({A: _hs.hide_id(0)}, _t_hide() + 1)
	assert_dict(_holds.hold_of(A)).is_empty()
	assert_bool(_sd.is_hidden(A)).is_false()
	_at_spot(M, 1)
	_hold({M: _hs.hide_id(1)}, _t_hide() + 1)
	assert_dict(_holds.hold_of(M)).is_empty()
	assert_int(_hs.occupant(1)).is_equal(-1)


## The first `type` marker's floor position (SurvivorObjectives registers its points there).
func _marker(type: StringName) -> Vector3:
	for m: MapMarker in _map.markers:
		if m.type == type:
			return m.position
	return FAR


## Spot `spot`'s eject point (SD-13): the hiding marker's floor + hide_eject_offset_m along its yaw.
func _placed_front(spot: int) -> Vector3:
	var h: MapMarker = _map.markers.filter(func(m: MapMarker) -> bool: return m.type == &"hiding")[spot]
	var facing := Basis(Vector3.UP, deg_to_rad(h.yaw_deg)) * Vector3.FORWARD
	return h.position + facing * _knobs.defense.hide_eject_offset_m
