# Story downing-and-rescue/003: bleed-out timer and anti-camping slow (design/gdd/downing-and-rescue.md
# rule 6, rule 10, Formulas "Bleed-out", Edge Cases).
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const S2 := 3
const S3 := 4
const S4 := 5
const SURVIVORS: Array[int] = [2, 3, 4, 5]
## takedown_commit_s 1.5 s, bleedout_s 60 s at 60 Hz (data/knobs/downing.tres, net.tres).
const COMMIT_TICKS := 90
const BLEED_TICKS := 3600
const HZ := 60

var _server: RoundServer
var _d: Downing
var _abilities: Emitter
var _eliminated: Array[int]
var _reasons: Array[int]
## player id -> position; a player absent from it stands 1 km from every other (FAR * id).
var _pos: Dictionary[int, Vector3]
const FAR := Vector3(1000.0, 0.0, 0.0)


func _start(knobs: Knobs = Knobs.load_all()) -> void:
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_d = Downing.new()
	_d.set_roster(SURVIVORS, MONSTER)
	_pos = {}
	_d.set_positions(func(p: int) -> Vector3: return _pos.get(p, FAR * p))
	_abilities = Emitter.new()
	_eliminated = []
	_reasons = []
	var errs := _server.start_round({TickOrder.MONSTER_ABILITIES: _abilities, TickOrder.DOWNING: _d}, knobs)
	assert_array(errs).is_empty()
	_server.bus.subscribe(&"SurvivorEliminated", func(e: ServerEvent) -> void:
		_eliminated.append((e as EvSurvivorEliminated).survivor)
		_reasons.append((e as EvSurvivorEliminated).reason))


func after_test() -> void:
	if _server != null:
		_server.end_round()


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


func _now() -> int:
	return _server.tick_runner.current_tick()


func _emit(e: ServerEvent) -> void:
	_server.bus.emit(e)
	_server.bus.flush()


## Runs a full takedown commit on `survivor`.
func _commit(survivor: int) -> void:
	var hit := EvSurvivorHit.new()
	hit.survivor = survivor
	var t := _now() + 1
	_abilities.at(t, hit)
	_step(t + COMMIT_TICKS - _now())


## Downs `survivor` through a full commit; returns the tick it became Downed.
func _down(survivor: int) -> int:
	_commit(survivor)
	assert_int(_d.life_state(survivor)).is_equal(Downing.LifeState.DOWNED)
	return _now()


func _escape(s: int) -> void:
	var e := EvSurvivorEscaped.new()
	e.survivor = s
	_emit(e)


func _conn(p: int, status: int) -> void:
	var e := EvPlayerConnectionChanged.new()
	e.player = p
	e.status = status
	_emit(e)


# Static step ------------------------------------------------------------------------------------

func test_bleed_step_follows_the_formula() -> void:
	assert_float(Downing.bleed_step(10.0, 1.0, false, 50.0, 1, 10.0, 0.25)).is_equal(11.0)
	assert_float(Downing.bleed_step(10.0, 1.0, false, 9.0, 1, 10.0, 0.25)).is_equal(10.25)
	assert_float(Downing.bleed_step(10.0, 1.0, false, 10.0, 1, 10.0, 0.25)).override_failure_message(
		"exactly the radius slows").is_equal(10.25)
	assert_float(Downing.bleed_step(10.0, 1.0, false, 9.0, 0, 10.0, 0.25)).override_failure_message(
		"no Healthy survivor: full rate").is_equal(11.0)
	assert_float(Downing.bleed_step(10.0, 1.0, true, 50.0, 1, 10.0, 0.25)).override_failure_message(
		"rescue pauses").is_equal(10.0)


# AC-1 -------------------------------------------------------------------------------------------

func test_lone_downed_survivor_bleeds_out_on_time_with_reason() -> void:
	_start()
	var t := _down(S1)
	_step(t + BLEED_TICKS - 1 - _now())
	assert_int(_d.life_state(S1)).override_failure_message("-1 tick").is_equal(Downing.LifeState.DOWNED)
	assert_array(_eliminated).is_empty()
	_step(1)
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.ELIMINATED)
	assert_array(_eliminated).is_equal([S1])
	assert_array(_reasons).is_equal([EvSurvivorEliminated.BLED_OUT])
	assert_str(EvSurvivorEliminated.REASON_TEXT[EvSurvivorEliminated.BLED_OUT]).is_equal("Bled out")
	_step(10)
	assert_array(_eliminated).is_equal([S1]) # exactly once


func test_rescue_hold_pauses_and_release_resumes_from_same_value() -> void:
	_start()
	var t := _down(S1)
	_step(10 * HZ)
	assert_float(_d.bleed_elapsed_s(S1)).is_equal(10.0)
	_d.set_rescuing(S1, true)
	_step(3 * HZ)
	assert_float(_d.bleed_elapsed_s(S1)).is_equal(10.0)
	_d.set_rescuing(S1, false)
	_step(HZ)
	assert_float(_d.bleed_elapsed_s(S1)).is_equal(11.0)
	_step(t + BLEED_TICKS + 3 * HZ - 1 - _now())
	assert_array(_eliminated).is_empty()
	_step(1)
	assert_array(_eliminated).is_equal([S1])


func test_hold_over_the_expiry_tick_wins() -> void:
	_start()
	var t := _down(S1)
	_step(t + BLEED_TICKS - 1 - _now())
	_d.set_rescuing(S1, true)
	_step(5 * HZ)
	assert_int(_d.life_state(S1)).is_equal(Downing.LifeState.DOWNED)
	assert_array(_eliminated).is_empty()


func test_bleedout_length_comes_from_knobs() -> void:
	var k := Knobs.load_all()
	k.downing.bleedout_s = 30.0
	_start(k)
	var t := _down(S1)
	_step(t + 30 * HZ - _now())
	assert_array(_eliminated).is_equal([S1])


# AC-2 -------------------------------------------------------------------------------------------

func test_other_player_at_9m_slows_and_at_11m_does_not() -> void:
	_start()
	_down(S1)
	_pos[S1] = Vector3.ZERO
	_pos[MONSTER] = Vector3(9.0, 0.0, 0.0)
	_step(10 * HZ)
	assert_float(_d.bleed_elapsed_s(S1)).is_equal(2.5)
	_pos[MONSTER] = Vector3(11.0, 0.0, 0.0)
	_step(10 * HZ)
	assert_float(_d.bleed_elapsed_s(S1)).is_equal(12.5)


func test_survivor_slows_like_the_monster_and_exactly_10m_slows() -> void:
	_start()
	_down(S1)
	_pos[S1] = Vector3.ZERO
	_pos[S2] = Vector3(0.0, 0.0, 10.0)
	_step(10 * HZ)
	assert_float(_d.bleed_elapsed_s(S1)).is_equal(2.5)


func test_slow_mult_and_radius_come_from_knobs() -> void:
	var k := Knobs.load_all()
	k.downing.camp_slow_mult = 0.5
	k.downing.camp_slow_radius_m = 5.0
	_start(k)
	_down(S1)
	_pos[S1] = Vector3.ZERO
	_pos[MONSTER] = Vector3(6.0, 0.0, 0.0)
	_step(10 * HZ)
	assert_float(_d.bleed_elapsed_s(S1)).is_equal(10.0)
	_pos[MONSTER] = Vector3(5.0, 0.0, 0.0)
	_step(10 * HZ)
	assert_float(_d.bleed_elapsed_s(S1)).is_equal(15.0)


func test_eliminated_escaped_and_disconnected_players_never_slow() -> void:
	_start()
	_down(S1)
	_d._downs_taken[S2] = 1 # S2's next down eliminates
	_commit(S2)
	_escape(S3)
	_conn(S4, EvPlayerConnectionChanged.DISCONNECTED)
	_conn(MONSTER, EvPlayerConnectionChanged.DISCONNECTED)
	assert_int(_d.life_state(S2)).is_equal(Downing.LifeState.ELIMINATED)
	_pos[S1] = Vector3.ZERO
	for p in [S2, S3, S4, MONSTER]:
		_pos[p] = Vector3(1.0, 0.0, 0.0)
	var before := _d.bleed_elapsed_s(S1)
	_step(10 * HZ)
	assert_float(_d.bleed_elapsed_s(S1) - before).is_equal(10.0)


func test_reconnected_player_slows_again() -> void:
	_start()
	_down(S1)
	_pos[S1] = Vector3.ZERO
	_pos[S2] = Vector3(1.0, 0.0, 0.0)
	_conn(S2, EvPlayerConnectionChanged.DISCONNECTED)
	_step(4 * HZ)
	assert_float(_d.bleed_elapsed_s(S1)).is_equal(4.0)
	_conn(S2, EvPlayerConnectionChanged.RECONNECTED)
	_step(4 * HZ)
	assert_float(_d.bleed_elapsed_s(S1)).is_equal(5.0)


func test_only_healthy_survivor_disconnecting_restores_full_rate() -> void:
	_start()
	_down(S1)
	_down(S2)
	_down(S3)
	_pos[S1] = Vector3.ZERO
	_pos[MONSTER] = Vector3(2.0, 0.0, 0.0)
	var before := _d.bleed_elapsed_s(S1)
	_step(4 * HZ)
	assert_float(_d.bleed_elapsed_s(S1) - before).is_equal(1.0)
	_conn(S4, EvPlayerConnectionChanged.DISCONNECTED)
	_step(4 * HZ)
	assert_float(_d.bleed_elapsed_s(S1) - before).is_equal(5.0)


# AC-3 -------------------------------------------------------------------------------------------

func test_all_downed_bleed_at_full_rate_each_on_own_timer() -> void:
	_start()
	var downed_at: Dictionary[int, int] = {}
	for s in SURVIVORS:
		downed_at[s] = _down(s)
	_pos[S1] = Vector3.ZERO
	_pos[MONSTER] = Vector3(5.0, 0.0, 0.0)
	_step(downed_at[S1] + BLEED_TICKS - _now())
	assert_array(_eliminated).is_equal([S1])
	for s in [S2, S3, S4]:
		_step(downed_at[s] + BLEED_TICKS - _now())
		assert_int(_d.life_state(s)).is_equal(Downing.LifeState.ELIMINATED)
	assert_array(_eliminated).is_equal(SURVIVORS)


func test_escaped_survivor_does_not_count_as_healthy() -> void:
	_start()
	_down(S1)
	_down(S2)
	_down(S3)
	_escape(S4)
	_pos[S1] = Vector3.ZERO
	_pos[MONSTER] = Vector3(5.0, 0.0, 0.0)
	var before := _d.bleed_elapsed_s(S1)
	_step(10 * HZ)
	assert_float(_d.bleed_elapsed_s(S1) - before).is_equal(10.0)


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
