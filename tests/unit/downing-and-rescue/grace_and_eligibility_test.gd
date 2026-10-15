# Story downing-and-rescue/002: grace windows and takedown eligibility
# (design/gdd/downing-and-rescue.md rules 3, 4.4, 8; Acceptance Criteria "rescued survivor ... 3 s").
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const S2 := 3
const SURVIVORS: Array[int] = [2, 3, 4, 5]
const HZ := 60
## takedown_commit_s 1.5 s, post_release_grace_s 2 s, post_rescue_grace_s 3 s at 60 Hz
## (data/knobs/downing.tres, net.tres).
const COMMIT_TICKS := 90
const RELEASE_TICKS := 120
const RESCUE_TICKS := 180

var _server: RoundServer
var _d: Downing
var _defense: Emitter
var _abilities: Emitter
var _hidden: Array[int]


func _start(knobs: Knobs = Knobs.load_all()) -> void:
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_d = Downing.new()
	_d.set_roster(SURVIVORS, MONSTER)
	_hidden = []
	_d.set_hidden(_is_hidden)
	_defense = Emitter.new()
	_abilities = Emitter.new()
	var errs := _server.start_round({TickOrder.SURVIVOR_DEFENSE: _defense,
		TickOrder.MONSTER_ABILITIES: _abilities, TickOrder.DOWNING: _d}, knobs)
	assert_array(errs).is_empty()


func _is_hidden(p: int) -> bool:
	return p in _hidden


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


func _now() -> int:
	return _server.tick_runner.current_tick()


func _view() -> Downing.LifeView:
	return _server.registry.view(StateKeys.TAKEDOWN_ELIGIBILITY, Downing.LifeView) as Downing.LifeView


func _land_hit(survivor: int) -> int:
	var t := _now() + 1
	var e := EvSurvivorHit.new()
	e.survivor = survivor
	_abilities.at(t, e)
	_step(1)
	return t


## Seizes S1 and stuns the monster on the next tick; returns the stun tick.
func _seize_and_stun() -> int:
	_land_hit(S1)
	var t := _now() + 1
	var e := EvMonsterStunned.new()
	e.monster = MONSTER
	e.true_form = true
	_defense.at(t, e)
	_step(1)
	return t


func after_test() -> void:
	if _server != null:
		_server.end_round()


# Pure eligibility -----------------------------------------------------------------------------

func test_is_eligible_needs_healthy_unhidden_and_grace_over() -> void:
	assert_bool(Downing.is_eligible(Downing.LifeState.HEALTHY, false, 100, 100)).is_true()
	assert_bool(Downing.is_eligible(Downing.LifeState.HEALTHY, false, 99, 100)).is_false()
	assert_bool(Downing.is_eligible(Downing.LifeState.HEALTHY, true, 100, 0)).is_false()
	assert_bool(Downing.is_eligible(Downing.LifeState.SEIZED, false, 100, 0)).is_false()
	assert_bool(Downing.is_eligible(Downing.LifeState.DOWNED, false, 100, 0)).is_false()
	assert_bool(Downing.is_eligible(Downing.LifeState.ELIMINATED, false, 100, 0)).is_false()


# AC-1: post-release grace ---------------------------------------------------------------------

func test_stun_release_grants_two_seconds_of_grace() -> void:
	_start()
	var t := _seize_and_stun()
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.HEALTHY)
	assert_bool(_view().eligible(S1)).is_false()
	_step(t + RELEASE_TICKS - 2 - _now())
	_land_hit(S1) # tick t + 119: absorbed by grace
	assert_bool(_d.committing()).is_false()
	assert_bool(_view().eligible(S1)).is_false()
	assert_int(_land_hit(S1)).is_equal(t + RELEASE_TICKS) # first eligible tick: seizes
	assert_int(_d.victim()).is_equal(S1)


func test_monster_disconnect_release_grants_grace() -> void:
	_start()
	_land_hit(S1)
	var e := EvPlayerConnectionChanged.new()
	e.player = MONSTER
	e.status = EvPlayerConnectionChanged.DISCONNECTED
	_server.bus.emit(e)
	_server.bus.flush()
	var t := _now()
	_step(RELEASE_TICKS - 1)
	assert_bool(_view().eligible(S1)).is_false()
	_step(1)
	assert_int(_now()).is_equal(t + RELEASE_TICKS)
	assert_bool(_view().eligible(S1)).is_true()


func test_grace_covers_only_the_released_victim() -> void:
	_start()
	_seize_and_stun()
	assert_bool(_view().eligible(S2)).is_true()


func test_release_grace_length_comes_from_knobs() -> void:
	var k := Knobs.load_all()
	k.downing.post_release_grace_s = 1.0
	_start(k)
	var t := _seize_and_stun()
	_step(t + HZ - 1 - _now())
	assert_bool(_view().eligible(S1)).is_false()
	_step(1)
	assert_bool(_view().eligible(S1)).is_true()


# AC-1: post-rescue grace ----------------------------------------------------------------------

func test_rescue_stand_up_grants_three_seconds_of_grace() -> void:
	_start()
	var t := _land_hit(S1)
	_step(t + COMMIT_TICKS - _now())
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.DOWNED)
	var up := _now()
	_d.stand_up(S1)
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.HEALTHY)
	assert_int(_d.downs_taken(S1)).is_equal(1)
	assert_float(_d.bleed_elapsed_s(S1)).is_equal(0.0)
	_step(RESCUE_TICKS - 1)
	assert_bool(_view().eligible(S1)).is_false()
	_step(1)
	assert_int(_now()).is_equal(up + RESCUE_TICKS)
	assert_bool(_view().eligible(S1)).is_true()


func test_rescue_grace_length_comes_from_knobs() -> void:
	var k := Knobs.load_all()
	k.downing.post_rescue_grace_s = 1.0
	_start(k)
	var t := _land_hit(S1)
	_step(t + COMMIT_TICKS - _now())
	_d.stand_up(S1)
	_step(HZ - 1)
	assert_bool(_view().eligible(S1)).is_false()
	_step(1)
	assert_bool(_view().eligible(S1)).is_true()


func test_stand_up_ignores_a_survivor_who_is_not_downed() -> void:
	_start()
	_d.stand_up(S1)
	assert_bool(_view().eligible(S1)).is_true()


# AC-2: hidden ---------------------------------------------------------------------------------

func test_hidden_survivor_is_ineligible_and_hit_ignored() -> void:
	_start()
	_hidden = [S2]
	assert_bool(_view().eligible(S2)).is_false()
	_land_hit(S2)
	assert_bool(_d.committing()).is_false()
	_hidden = []
	assert_bool(_view().eligible(S2)).is_true()


func test_absent_hidden_owner_reads_as_not_hidden() -> void:
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_d = Downing.new()
	_d.set_roster(SURVIVORS, MONSTER)
	assert_array(_server.start_round({TickOrder.DOWNING: _d}, Knobs.load_all())).is_empty()
	assert_bool(_view().eligible(S1)).is_true()


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
