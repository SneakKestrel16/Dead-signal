# Story downing-and-rescue/004: rescue hold with persisting progress (design/gdd/downing-and-rescue.md
# rules 7 and 8, Formulas "Rescue progress", Edge Cases rescue rows; ADR-0008). A real RoundServer runs
# Downing in the DOWNING slot and a real HoldService in the HOLDS slot; frames, centres and sight are fed
# by the test. Rescuers target the Downed body (target_is_body); a handle here is the player id.
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2 ## the Downed survivor
const A := 3 ## rescuer
const B := 4 ## second rescuer
const SURVIVORS: Array[int] = [2, 3, 4, 5]

var _knobs: Knobs
var _server: RoundServer
var _d: Downing
var _holds: HoldService
var _abilities: Emitter
var _feed: Dictionary = {}
var _hidden: Dictionary = {}
var _at: Dictionary = {} ## player -> centre; absent = the origin, where the body lies
var _rescued: Array[EvSurvivorRescued] = []


func _start(knobs: Knobs = Knobs.load_all()) -> void:
	_knobs = knobs
	_feed = {}
	_hidden = {}
	_at = {}
	_rescued = []
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_holds = HoldService.new(knobs, _players, _frames, _centre, _sight, _no_aim, _body_target)
	_d = Downing.new()
	_d.set_roster(SURVIVORS, MONSTER)
	_d.set_positions(_centre)
	_d.set_hidden(_is_hidden)
	_d.set_holds(_holds)
	_abilities = Emitter.new()
	var errs := _server.start_round({TickOrder.MONSTER_ABILITIES: _abilities, TickOrder.DOWNING: _d,
		TickOrder.HOLDS: HoldsStep.new(_holds)}, knobs)
	assert_array(errs).is_empty()
	_server.bus.subscribe(&"SurvivorRescued", _on_rescued)
	_down(S1)


func after_test() -> void:
	if _server != null:
		_server.end_round()


func _on_rescued(e: ServerEvent) -> void:
	_rescued.append(e as EvSurvivorRescued)


func _players() -> Array:
	return SURVIVORS + [MONSTER]


func _frames(actor: int) -> Array:
	return _feed.get(actor, [])


## The body lies at the origin and never moves here.
func _centre(actor: int) -> Vector3:
	return _at.get(actor, Vector3.ZERO)


func _sight(_actor: int, _i: Interactable) -> bool:
	return true


func _no_aim(_actor: int) -> int:
	return -1


func _body_target(_actor: int, handle: int) -> int:
	return _d.rescue_net_id(handle)


func _is_hidden(p: int) -> bool:
	return _hidden.has(p)


func _ticks(s: float) -> int:
	return _knobs.ticks(s)


func _step(n: int = 1) -> void:
	for i in n:
		_server.tick_runner.step()


func _now() -> int:
	return _server.tick_runner.current_tick()


func _down(survivor: int) -> void:
	var hit := EvSurvivorHit.new()
	hit.survivor = survivor
	_abilities.at(_now() + 1, hit)
	_step(1 + _ticks(_knobs.downing.takedown_commit_s))
	assert_int(_d.life_state(survivor)).is_equal(Downing.LifeState.DOWNED)


func _frame(interact: bool) -> InputFrame:
	var f := InputFrame.new()
	f.interact = interact
	f.target_is_body = true
	f.interact_target = S1
	return f


## Each actor in `actors` holds Rescue on S1 for `n` ticks; everyone else is released.
func _hold(actors: Array, n: int) -> void:
	for p: int in _players():
		_feed[p] = [_frame(actors.has(p))]
	_step(n)


func _release(n: int = 1) -> void:
	_hold([], n)


func _downed() -> bool:
	return _d.life_state(S1) == Downing.LifeState.DOWNED


# AC-1: 6 s uninterrupted; release at 4 s and resume 3 s later needs 3.5 s more -------------------

func test_six_second_hold_rescues() -> void:
	_start()
	var full := _ticks(_knobs.downing.rescue_duration_s)
	_hold([A], full - 1)
	assert_bool(_downed()).override_failure_message("not before 6 s").is_true()
	_hold([A], 2)
	assert_bool(_downed()).override_failure_message("rescued within 6 s +1 tick").is_false()


func test_released_at_four_resumed_three_later_needs_three_and_a_half() -> void:
	_start()
	_hold([A], _ticks(4.0))
	_release()
	assert_float(_d.rescue_progress_s(S1)).is_equal_approx(4.0, 1e-6)
	_release(_ticks(3.0) - 1)
	assert_float(_d.rescue_progress_s(S1)).override_failure_message("4.0 - 3 s * 0.5, one tick of decay to come").is_equal_approx(2.5, 0.01)
	var left := _ticks(3.5)
	_hold([A], left - 1)
	assert_bool(_downed()).override_failure_message("needs 3.5 s more").is_true()
	_hold([A], 2)
	assert_bool(_downed()).is_false()


func test_progress_decays_to_zero_not_below() -> void:
	_start()
	_hold([A], _ticks(1.0))
	_release(_ticks(10.0))
	assert_float(_d.rescue_progress_s(S1)).is_equal(0.0)


func test_any_survivor_may_resume() -> void:
	_start()
	var full := _ticks(_knobs.downing.rescue_duration_s)
	_hold([A], _ticks(4.0))
	_release()
	_hold([B], full - _ticks(4.0) - 2)
	assert_bool(_downed()).override_failure_message("B resumes from A's progress, not before").is_true()
	_hold([B], 3)
	assert_bool(_downed()).is_false()


# AC-2: one rescuer counts; hidden cannot start -----------------------------------------------------

func test_second_rescuer_is_refused_and_rescue_still_takes_six_seconds() -> void:
	_start()
	var full := _ticks(_knobs.downing.rescue_duration_s)
	_hold([A], 1)
	_hold([A, B], full - 2)
	assert_dict(_holds.hold_of(B)).override_failure_message("already being rescued").is_empty()
	assert_bool(_downed()).is_true()
	_hold([A, B], 2)
	assert_bool(_downed()).is_false()
	assert_int(_rescued[0].rescuer).is_equal(A)


func test_hidden_survivor_cannot_start() -> void:
	_start()
	_hidden[A] = true
	_hold([A], 2)
	assert_dict(_holds.hold_of(A)).is_empty()
	assert_float(_d.rescue_progress_s(S1)).is_equal(0.0)


func test_monster_and_downed_cannot_rescue() -> void:
	_start()
	_hold([MONSTER, S1], 2)
	assert_dict(_holds.hold_of(MONSTER)).is_empty()
	assert_dict(_holds.hold_of(S1)).is_empty()


func test_hold_roots_rescuer_and_pauses_bleed_out() -> void:
	_start()
	_hold([A], 1)
	assert_bool(_holds.hold_of(A).roots).is_true()
	var bled := _d.bleed_elapsed_s(S1)
	_hold([A], _ticks(2.0))
	assert_float(_d.bleed_elapsed_s(S1)).is_equal(bled)
	_release(_ticks(1.0))
	assert_float(_d.bleed_elapsed_s(S1)).is_greater(bled)


# AC-3: hit or shock interrupts (kept, decaying); rescued stands up Healthy, downs 1, event ----------

func test_hit_rescuer_interrupts_and_keeps_progress() -> void:
	_start()
	_hold([A], _ticks(2.0))
	var hit := EvSurvivorHit.new()
	hit.survivor = A
	_abilities.at(_now() + 1, hit)
	_hold([A], 1)
	assert_int(_d.life_state(A)).is_equal(Downing.LifeState.SEIZED)
	assert_dict(_holds.hold_of(A)).is_empty()
	var kept := _d.rescue_progress_s(S1)
	assert_float(kept).is_equal_approx(2.0, 2.0 / _knobs.net.sim_tick_hz)
	_hold([A], 10)
	assert_float(_d.rescue_progress_s(S1)).is_less(kept)


func test_hit_on_completion_tick_wins() -> void:
	_start()
	var full := _ticks(_knobs.downing.rescue_duration_s)
	_hold([A], full - 1)
	var hit := EvSurvivorHit.new()
	hit.survivor = A
	_abilities.at(_now() + 1, hit)
	_hold([A], 1)
	assert_bool(_downed()).override_failure_message("hit before interactions").is_true()
	assert_array(_rescued).is_empty()


func test_shocked_rescuer_interrupts_and_keeps_progress() -> void:
	_start()
	_hold([A], _ticks(2.0))
	var shock := EvPlayerShocked.new()
	shock.player = A
	_abilities.at(_now() + 1, shock)
	_hold([A], 1)
	assert_dict(_holds.hold_of(A)).is_empty()
	assert_float(_d.rescue_progress_s(S1)).is_greater(1.9)
	_hold([A], 2)
	assert_dict(_holds.hold_of(A)).override_failure_message("held input does not restart").is_empty()


func test_rescued_survivor_stands_up_healthy_with_one_down() -> void:
	_start()
	_hold([A], _ticks(_knobs.downing.rescue_duration_s))
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.HEALTHY)
	assert_int(_d.downs_taken(S1)).is_equal(1)
	assert_int(_rescued.size()).is_equal(1)
	assert_int(_rescued[0].survivor).is_equal(S1)
	assert_int(_d.rescue_net_id(S1)).override_failure_message("no rescue on a standing body").is_equal(-1)
	assert_bool(_d.eligible(S1)).override_failure_message("post-rescue grace").is_false()
	assert_float(_d.rescue_progress_s(S1)).is_equal(0.0)


func test_bleed_out_removes_the_rescue() -> void:
	_start()
	for p: int in _players():
		if p != S1:
			_at[p] = Vector3(50.0, 0.0, 0.0) ## beyond camp_slow_radius_m: full-rate bleed-out
	_release(_ticks(_knobs.downing.bleedout_s))
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.ELIMINATED)
	assert_int(_d.rescue_net_id(S1)).is_equal(-1)


# AC-4: values from DowningKnobs ---------------------------------------------------------------------

func test_duration_and_decay_follow_the_knobs() -> void:
	var k := Knobs.load_all()
	k.downing.rescue_duration_s = 4.0
	k.downing.rescue_decay_rate = 0.0
	k.downing.rescue_range_m = 2.0
	_start(k)
	_hold([A], _ticks(1.0))
	_release(_ticks(5.0))
	assert_float(_d.rescue_progress_s(S1)).override_failure_message("decay 0 keeps progress").is_equal_approx(1.0, 1e-6)
	_hold([A], _ticks(3.0) - 1)
	assert_bool(_downed()).is_true()
	_hold([A], 2)
	assert_bool(_downed()).override_failure_message("4 s rescue").is_false()


func test_start_range_follows_the_knob() -> void:
	_start()
	_at[A] = Vector3(1.8, 0.0, 0.0)
	_hold([A], 1)
	assert_dict(_holds.hold_of(A)).override_failure_message("1.8 m is beyond the shipped 1.5 m").is_empty()
	after_test()
	var k := Knobs.load_all()
	k.downing.rescue_range_m = 2.0
	_start(k)
	_at[A] = Vector3(1.8, 0.0, 0.0)
	_hold([A], 1)
	assert_int(_holds.hold_of(A).get("net_id", -1)).is_equal(_d.rescue_net_id(S1))


## Runs HoldService in the HOLDS slot (stands in for the composer's Holds step).
class HoldsStep extends RefCounted:
	var _holds: HoldService

	func _init(holds: HoldService) -> void:
		_holds = holds

	func setup(_runner: TickRunner, _bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
		pass

	func server_tick(tick: int) -> void:
		_holds.server_tick(tick)


## Emits each scheduled event in its own tick slot (stands in for Monster Abilities / Survivor Defense).
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
