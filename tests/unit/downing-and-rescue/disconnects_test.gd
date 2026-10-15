# Story downing-and-rescue/006: disconnects during a commit or while Downed (design/gdd/downing-and-rescue.md
# Edge Cases disconnect rows, rule 6; match-flow.md rule 19; TR-downing-008). A real RoundServer runs Downing
# in the DOWNING slot and a real HoldService in the HOLDS slot. PlayerConnectionChanged is emitted by the
# test (Match Flow owns the grace); a disconnected player leaves HoldService's player list, as the composer's
# roster does once the character is removed.
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const S2 := 3
const S3 := 4
const S4 := 5
const SURVIVORS: Array[int] = [2, 3, 4, 5]

var _knobs: Knobs
var _server: RoundServer
var _d: Downing
var _holds: HoldService
var _abilities: Emitter
var _feed: Dictionary = {}
var _gone: Dictionary = {}
## player id -> position; absent = 1 km per id from everyone (nobody slows bleed-out).
var _pos: Dictionary = {}
var _downed: Array[int] = []
var _eliminated: Array[int] = []
var _reasons: Array[int] = []


func _start(knobs: Knobs = Knobs.load_all()) -> void:
	_knobs = knobs
	_feed = {}
	_gone = {}
	_pos = {}
	_downed = []
	_eliminated = []
	_reasons = []
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_holds = HoldService.new(knobs, _players, _frames, _position, _sight, _no_aim, _body_target)
	_d = Downing.new()
	_d.set_roster(SURVIVORS, MONSTER)
	_d.set_positions(_position)
	_d.set_holds(_holds)
	_abilities = Emitter.new()
	var errs := _server.start_round({TickOrder.MONSTER_ABILITIES: _abilities, TickOrder.DOWNING: _d,
		TickOrder.HOLDS: HoldsStep.new(_holds)}, knobs)
	assert_array(errs).is_empty()
	_server.bus.subscribe(&"SurvivorDowned", _on_downed)
	_server.bus.subscribe(&"SurvivorEliminated", _on_eliminated)


func after_test() -> void:
	if _server != null:
		_server.end_round()


func _on_downed(e: ServerEvent) -> void:
	_downed.append((e as EvSurvivorDowned).survivor)


func _on_eliminated(e: ServerEvent) -> void:
	_eliminated.append((e as EvSurvivorEliminated).survivor)
	_reasons.append((e as EvSurvivorEliminated).reason)


func _players() -> Array:
	return (SURVIVORS + [MONSTER]).filter(func(p: int) -> bool: return not _gone.has(p))


func _frames(actor: int) -> Array:
	return _feed.get(actor, [])


func _position(p: int) -> Vector3:
	return _pos.get(p, Vector3(1000.0 * p, 0.0, 0.0))


func _sight(_actor: int, _i: Interactable) -> bool:
	return true


func _no_aim(_actor: int) -> int:
	return -1


func _body_target(_actor: int, handle: int) -> int:
	return _d.rescue_net_id(handle)


func _ticks(s: float) -> int:
	return _knobs.ticks(s)


func _step(n: int = 1) -> void:
	for i in n:
		_server.tick_runner.step()


func _now() -> int:
	return _server.tick_runner.current_tick()


## Seizes `survivor` on the next tick; returns the tick the commit completes.
func _seize(survivor: int) -> int:
	var hit := EvSurvivorHit.new()
	hit.survivor = survivor
	var t := _now() + 1
	_abilities.at(t, hit)
	_step()
	assert_int(_d.life_state(survivor)).is_equal(Downing.LifeState.SEIZED)
	return t + _ticks(_knobs.downing.takedown_commit_s)


func _conn(p: int, status: int) -> void:
	if status == EvPlayerConnectionChanged.RECONNECTED:
		_gone.erase(p)
	else:
		_gone[p] = true
	var e := EvPlayerConnectionChanged.new()
	e.player = p
	e.status = status
	_server.bus.emit(e)
	_server.bus.flush()


## `actor` holds Rescue on `downed`'s body for `n` ticks.
func _hold(actor: int, downed: int, n: int) -> void:
	var f := InputFrame.new()
	f.interact = true
	f.target_is_body = true
	f.interact_target = downed
	_feed[actor] = [f]
	_step(n)


# AC-1: a victim who disconnects while Seized ----------------------------------------------------

func test_victim_disconnecting_while_seized_is_downed_on_schedule_and_returns_downed() -> void:
	_start()
	var end := _seize(S1)
	_conn(S1, EvPlayerConnectionChanged.DISCONNECTED)
	_step(end - 1 - _now())
	assert_int(_d.life_state(S1)).override_failure_message("-1 tick").is_equal(Downing.LifeState.SEIZED)
	_step()
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.DOWNED)
	assert_array(_downed).is_equal([S1])
	assert_int(_d.downs_taken(S1)).is_equal(1)
	_step(_ticks(5.0))
	assert_float(_d.bleed_elapsed_s(S1)).override_failure_message("bleeds while away").is_equal(5.0)
	_conn(S1, EvPlayerConnectionChanged.RECONNECTED)
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.DOWNED)
	assert_int(_d.downs_taken(S1)).is_equal(1)
	assert_float(_d.bleed_elapsed_s(S1)).is_equal(5.0)


func test_victim_with_one_down_disconnecting_while_seized_is_eliminated() -> void:
	_start()
	_d._downs_taken[S1] = 1
	var end := _seize(S1)
	_conn(S1, EvPlayerConnectionChanged.DISCONNECTED)
	_step(end - _now())
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.ELIMINATED)
	assert_array(_eliminated).is_equal([S1])
	assert_array(_reasons).is_equal([EvSurvivorEliminated.TAKEN_DOWN])
	_conn(S1, EvPlayerConnectionChanged.RECONNECTED)
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.ELIMINATED)


func test_stun_still_cancels_a_disconnected_victims_commit() -> void:
	_start()
	_seize(S1)
	_conn(S1, EvPlayerConnectionChanged.DISCONNECTED)
	var stun := EvMonsterStunned.new()
	stun.monster = MONSTER
	_server.bus.emit(stun)
	_server.bus.flush()
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.HEALTHY)
	assert_bool(_d.committing()).is_false()


# AC-2: a Downed survivor who disconnects --------------------------------------------------------

func test_downed_survivor_bleeds_out_while_disconnected() -> void:
	_start()
	var downed_at := _seize(S1)
	_step(downed_at - _now())
	_conn(S1, EvPlayerConnectionChanged.DISCONNECTED)
	_step(downed_at + _ticks(_knobs.downing.bleedout_s) - 1 - _now())
	assert_array(_eliminated).override_failure_message("-1 tick").is_empty()
	_step()
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.ELIMINATED)
	assert_array(_eliminated).is_equal([S1])
	assert_array(_reasons).is_equal([EvSurvivorEliminated.BLED_OUT])


func test_downed_survivor_disconnecting_mid_rescue_cancels_it_and_keeps_bleeding() -> void:
	_start()
	var downed_at := _seize(S1)
	_step(downed_at - _now())
	_pos[S1] = Vector3.ZERO
	_pos[S2] = Vector3(0.0, 0.0, 1.0)
	_hold(S2, S1, _ticks(2.0))
	var bled := _d.bleed_elapsed_s(S1)
	_conn(S1, EvPlayerConnectionChanged.DISCONNECTED)
	_pos.erase(S1)
	assert_dict(_holds.hold_of(S2)).override_failure_message("no body to rescue").is_empty()
	_hold(S2, S1, _ticks(10.0))
	assert_dict(_holds.hold_of(S2)).override_failure_message("cannot start on an absent body").is_empty()
	assert_float(_d.bleed_elapsed_s(S1)).is_equal(bled + 10.0)
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.DOWNED)


# AC-3: a Healthy survivor who disconnects -------------------------------------------------------

func test_healthy_survivor_disconnecting_stops_slowing_and_cannot_rescue() -> void:
	_start()
	var downed_at := _seize(S1)
	_step(downed_at - _now())
	_pos[S1] = Vector3.ZERO
	_pos[S2] = Vector3(1.0, 0.0, 0.0)
	_step(_ticks(4.0))
	assert_float(_d.bleed_elapsed_s(S1)).is_equal(4.0 * _knobs.downing.camp_slow_mult)
	_conn(S2, EvPlayerConnectionChanged.DISCONNECTED)
	assert_bool(_d.can_rescue(S2, S1)).is_false()
	var before := _d.bleed_elapsed_s(S1)
	_step(_ticks(4.0))
	assert_float(_d.bleed_elapsed_s(S1) - before).override_failure_message("full rate at once").is_equal(4.0)


func test_only_healthy_survivor_disconnecting_leaves_none_counted_healthy() -> void:
	_start()
	for s in [S1, S2, S3]:
		var end := _seize(s)
		_step(end - _now())
	_pos[S1] = Vector3.ZERO
	_pos[MONSTER] = Vector3(2.0, 0.0, 0.0)
	_conn(S4, EvPlayerConnectionChanged.DISCONNECTED)
	var before := _d.bleed_elapsed_s(S1)
	_step(_ticks(4.0))
	assert_float(_d.bleed_elapsed_s(S1) - before).is_equal(4.0)


## Runs HoldService in the HOLDS slot.
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
