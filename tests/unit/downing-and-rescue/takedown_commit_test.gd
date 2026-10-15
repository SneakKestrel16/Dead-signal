# Story downing-and-rescue/001: life state and takedown commit (design/gdd/downing-and-rescue.md
# rules 2-5, Formulas "Takedown outcome", Edge Cases).
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const S2 := 3
const SURVIVORS: Array[int] = [2, 3, 4, 5]
## takedown_commit_s 1.5 s at 60 Hz (data/knobs/downing.tres, net.tres).
const COMMIT_TICKS := 90

var _server: RoundServer
var _d: Downing
## Scheduled emitters standing in for Survivor Defense and Monster Abilities (no code yet).
var _defense: Emitter
var _abilities: Emitter
var _downed: Array[int]
var _eliminated: Array[int]


func _start(d: Downing = Downing.new(), knobs: Knobs = Knobs.load_all()) -> void:
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_d = d
	_d.set_roster(SURVIVORS, MONSTER)
	_defense = Emitter.new()
	_abilities = Emitter.new()
	_downed = []
	_eliminated = []
	var errs := _server.start_round({TickOrder.SURVIVOR_DEFENSE: _defense,
		TickOrder.MONSTER_ABILITIES: _abilities, TickOrder.DOWNING: _d}, knobs)
	assert_array(errs).is_empty()
	_server.bus.subscribe(&"SurvivorDowned", func(e: ServerEvent) -> void:
		_downed.append((e as EvSurvivorDowned).survivor))
	_server.bus.subscribe(&"SurvivorEliminated", func(e: ServerEvent) -> void:
		_eliminated.append((e as EvSurvivorEliminated).survivor))


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


func _now() -> int:
	return _server.tick_runner.current_tick()


func _hit(survivor: int) -> EvSurvivorHit:
	var e := EvSurvivorHit.new()
	e.survivor = survivor
	return e


func _stun(monster: int = MONSTER) -> EvMonsterStunned:
	var e := EvMonsterStunned.new()
	e.monster = monster
	e.true_form = true
	return e


func _conn(player: int, status: int) -> EvPlayerConnectionChanged:
	var e := EvPlayerConnectionChanged.new()
	e.player = player
	e.status = status
	return e


## Lands a hit in the Monster Abilities slot of the next tick; returns that tick.
func _land_hit(survivor: int) -> int:
	var t := _now() + 1
	_abilities.at(t, _hit(survivor))
	_step(1)
	return t


func after_test() -> void:
	if _server != null:
		_server.end_round()


# AC-1 -------------------------------------------------------------------------------------------

func test_healthy_survivor_commit_completes_to_downed() -> void:
	_start()
	_step(5)
	var t := _land_hit(S1)
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.SEIZED)
	assert_bool(_d.committing()).is_true()
	_step(t + COMMIT_TICKS - _now())
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.DOWNED)
	assert_int(_d.downs_taken(S1)).is_equal(1)
	assert_bool(_d.committing()).is_false()
	assert_array(_downed).is_equal([S1])
	assert_array(_eliminated).is_empty()


func test_survivor_with_one_down_is_eliminated_without_entering_downed() -> void:
	_start()
	_d._downs_taken[S2] = 1 # stands in for a completed rescue (story 003)
	var states: Array[int] = []
	var t := _land_hit(S2)
	while _now() < t + COMMIT_TICKS:
		_step(1)
		states.append(_d.life_state(S2))
	assert_int(_d.life_state(S2)).is_equal(Downing.LifeState.ELIMINATED)
	assert_int(_d.downs_taken(S2)).is_equal(2)
	assert_array(states).not_contains([Downing.LifeState.DOWNED])
	assert_array(_eliminated).is_equal([S2])
	assert_array(_downed).is_empty()


func test_commit_boundary_one_tick_before_and_after() -> void:
	_start()
	var t := _land_hit(S1)
	_step(t + COMMIT_TICKS - 1 - _now())
	assert_int(_d.life_state(S1)).override_failure_message("-1 tick").is_equal(Downing.LifeState.SEIZED)
	assert_array(_downed).is_empty()
	_step(1)
	assert_int(_d.life_state(S1)).override_failure_message("on time").is_equal(Downing.LifeState.DOWNED)
	_step(1)
	assert_int(_d.life_state(S1)).override_failure_message("+1 tick").is_equal(Downing.LifeState.DOWNED)
	assert_array(_downed).is_equal([S1]) # exactly one event


func test_commit_length_and_outcome_come_from_knobs() -> void:
	var k := Knobs.load_all()
	k.downing.takedown_commit_s = 1.0
	k.downing.bleedout_s = 45.0
	_start(Downing.new(), k)
	var bleed: Array[float] = []
	_server.bus.subscribe(&"SurvivorDowned", func(e: ServerEvent) -> void:
		bleed.append((e as EvSurvivorDowned).bleed_out_s))
	var t := _land_hit(S1)
	_step(t + 59 - _now())
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.SEIZED)
	_step(1)
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.DOWNED)
	assert_array(bleed).is_equal([45.0])


func test_downs_to_eliminate_comes_from_knobs() -> void:
	var k := Knobs.load_all()
	k.downing.downs_to_eliminate = 1 # outside the shipped range: driven without RoundServer
	var bus := EventBus.new(8)
	var d := Downing.new()
	d.set_roster(SURVIVORS, MONSTER)
	d.setup(null, bus, StateRegistry.new(), k)
	var hit := _hit(S1)
	hit.tick = 1
	bus.emit(hit)
	bus.flush()
	d.server_tick(1 + COMMIT_TICKS)
	assert_int(d.life_state(S1)).is_equal(Downing.LifeState.ELIMINATED)


# AC-2 -------------------------------------------------------------------------------------------

func test_stun_during_commit_cancels_and_keeps_downs() -> void:
	_start()
	var t := _land_hit(S1)
	_defense.at(t + 30, _stun())
	_step(t + COMMIT_TICKS + 5 - _now())
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.HEALTHY)
	assert_int(_d.downs_taken(S1)).is_equal(0)
	assert_bool(_d.committing()).is_false()
	assert_array(_downed).is_empty()


func test_stun_on_the_completion_tick_wins() -> void:
	_start()
	var t := _land_hit(S1)
	_defense.at(t + COMMIT_TICKS, _stun())
	_step(t + COMMIT_TICKS + 5 - _now())
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.HEALTHY)
	assert_int(_d.downs_taken(S1)).is_equal(0)
	assert_array(_downed).is_empty()


func test_stun_one_tick_after_completion_leaves_the_down_standing() -> void:
	_start()
	var t := _land_hit(S1)
	_defense.at(t + COMMIT_TICKS + 1, _stun())
	_step(t + COMMIT_TICKS + 5 - _now())
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.DOWNED)
	assert_int(_d.downs_taken(S1)).is_equal(1)
	assert_array(_downed).is_equal([S1])


func test_stun_of_another_body_does_not_cancel() -> void:
	_start()
	var t := _land_hit(S1)
	_defense.at(t + 10, _stun(S2))
	_step(t + COMMIT_TICKS - _now())
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.DOWNED)


# AC-3 -------------------------------------------------------------------------------------------

func test_hit_on_downed_survivor_changes_nothing() -> void:
	_start()
	var t := _land_hit(S1)
	_step(t + COMMIT_TICKS - _now())
	_land_hit(S1)
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.DOWNED)
	assert_int(_d.downs_taken(S1)).is_equal(1)
	assert_bool(_d.committing()).is_false()
	_step(COMMIT_TICKS + 5)
	assert_array(_downed).is_equal([S1])
	assert_array(_eliminated).is_empty()


func test_hit_on_survivor_in_grace_changes_nothing() -> void:
	var d := GraceStub.new()
	d.graced = [S2]
	_start(d)
	_land_hit(S2)
	assert_int(_d.life_state(S2)).is_equal(Downing.LifeState.HEALTHY)
	assert_bool(_d.committing()).is_false()
	_step(COMMIT_TICKS + 5)
	assert_int(_d.downs_taken(S2)).is_equal(0)
	assert_array(_downed).is_empty()


func test_hit_during_active_commit_is_ignored() -> void:
	_start()
	var t := _land_hit(S1)
	_step(10)
	_land_hit(S2) # another survivor
	_land_hit(S1) # the victim again: must not restart the timer
	assert_int(_d.life_state(S2)).is_equal(Downing.LifeState.HEALTHY)
	assert_int(_d.victim()).is_equal(S1)
	_step(t + COMMIT_TICKS - _now())
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.DOWNED)
	_step(COMMIT_TICKS)
	assert_int(_d.life_state(S2)).is_equal(Downing.LifeState.HEALTHY)
	assert_array(_downed).is_equal([S1])


func test_hit_on_non_survivor_is_ignored() -> void:
	_start()
	_land_hit(MONSTER)
	assert_bool(_d.committing()).is_false()


func test_monster_disconnect_mid_commit_cancels() -> void:
	_start()
	var t := _land_hit(S1)
	_step(20)
	_server.bus.emit(_conn(MONSTER, EvPlayerConnectionChanged.DISCONNECTED))
	_server.bus.flush()
	_step(t + COMMIT_TICKS + 5 - _now())
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.HEALTHY)
	assert_int(_d.downs_taken(S1)).is_equal(0)
	assert_array(_downed).is_empty()


func test_victim_disconnect_while_seized_does_not_cancel() -> void:
	_start()
	var t := _land_hit(S1)
	_server.bus.emit(_conn(S1, EvPlayerConnectionChanged.DISCONNECTED))
	_server.bus.flush()
	_step(t + COMMIT_TICKS - _now())
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.DOWNED)


# Registry and lifetime --------------------------------------------------------------------------

func test_life_state_downs_and_committing_are_published_in_the_registry() -> void:
	_start()
	var life := _server.registry.view(StateKeys.TAKEDOWN_ELIGIBILITY, Downing.LifeView) as Downing.LifeView
	var commit := _server.registry.view(StateKeys.COMMITTING_STATE, Downing.CommitView) as Downing.CommitView
	assert_bool(life.eligible(S1)).is_true()
	var t := _land_hit(S1)
	assert_int(life.life_state(S1)).is_equal(Downing.LifeState.SEIZED)
	assert_bool(life.eligible(S1)).is_false()
	assert_bool(commit.committing()).is_true()
	assert_int(commit.victim()).is_equal(S1)
	_step(t + COMMIT_TICKS - _now())
	assert_int(life.downs_taken(S1)).is_equal(1)
	assert_bool(commit.committing()).is_false()


## The views and bus subscriptions hold the module weakly: dropping it frees it.
func test_views_do_not_keep_the_module_alive() -> void:
	var bus := EventBus.new(8)
	var registry := StateRegistry.new()
	var d := Downing.new()
	d.set_roster(SURVIVORS, MONSTER)
	d.setup(null, bus, registry, Knobs.load_all())
	var probe: WeakRef = weakref(d)
	d = null
	assert_object(probe.get_ref()).is_null()
	bus.emit(_hit(S1))
	bus.flush() # freed module: no crash
	var life := registry.view(StateKeys.TAKEDOWN_ELIGIBILITY, Downing.LifeView) as Downing.LifeView
	assert_bool(life.eligible(S1)).is_false()
	var commit := registry.view(StateKeys.COMMITTING_STATE, Downing.CommitView) as Downing.CommitView
	assert_bool(commit.committing()).is_false()


## Emits each scheduled event in its own tick slot (stands in for an emitting module).
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


## Story 002 stand-in: survivors in `graced` are ineligible.
class GraceStub extends Downing:
	var graced: Array[int] = []

	func eligible(player: int) -> bool:
		return super(player) and player not in graced
