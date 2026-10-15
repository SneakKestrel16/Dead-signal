# Story monster-abilities/004: Lunge resolution, cooldown and miss slow (design/gdd/monster-abilities.md
# rules 9-12, "States and Transitions", Edge Cases "Monster disconnects mid-lunge"; ADR-0007 miss slow as a
# controller modifier). MonsterAbilities runs on a RoundServer with no hit sources, so every dash misses
# unless the test emits SurvivorHit itself; Downing's commit end and Survivor Defense's stun are emitted
# directly too (QA plan: until MA-6 and SD-12 re-run against the real modules).
extends GdUnitTestSuite

const MONSTER := 1
const SURVIVOR := 2

var _knobs: Knobs
var _server: RoundServer
var _ma: MonsterAbilities
var _mods: MovementModifiers
var _hits: Array[EvSurvivorHit] = []
var _cd := 0
var _slow := 0
var _locked := false


func before_test() -> void:
	_knobs = Knobs.load_all()
	_cd = _knobs.ticks(_knobs.ability.lunge_cooldown_s)
	_slow = _knobs.ticks(_knobs.ability.miss_slow_s)
	_mods = MovementModifiers.new()
	_hits = []
	_locked = false
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_ma = MonsterAbilities.new()
	_ma.set_monster(MONSTER)
	_ma.set_modifiers(_mods_of)
	_ma.set_status_sources(Callable(), Callable(), _locked_of)
	assert_array(_server.start_round({TickOrder.MONSTER_ABILITIES: _ma}, _knobs)).is_empty()
	_server.tick_runner.bus.subscribe(&"SurvivorHit", _on_hit)


func after_test() -> void:
	if _server != null:
		_server.end_round()


func _mods_of(player: int) -> MovementModifiers:
	return _mods if player == MONSTER else null


func _locked_of(_player: int) -> bool:
	return _locked


func _on_hit(e: ServerEvent) -> void:
	_hits.append(e as EvSurvivorHit)


func _now() -> int:
	return _server.tick_runner.current_tick()


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


func _windup() -> int:
	return _knobs.ticks(_knobs.ability.lunge_windup_s)


func _dash() -> int:
	return _knobs.ticks(_knobs.ability.lunge_dash_s)


## Requests a lunge on the next tick; true when it was accepted (wind-up started that tick).
func _try_lunge() -> bool:
	_ma.request_ability(MONSTER, MonsterAbilities.request_packet(MonsterAbilities.Ability.LUNGE))
	_step(1)
	return _ma.lunge_state() == MonsterAbilities.Lunge.WIND_UP


## Emits `e` between ticks (it takes the last stepped tick and is flushed at the end of the next step);
## returns its tick.
func _emit(e: ServerEvent) -> int:
	_server.tick_runner.bus.emit(e)
	_step(1)
	return e.tick


func _stun() -> int:
	var e := EvMonsterStunned.new()
	e.monster = MONSTER
	return _emit(e)


func _hit() -> int:
	var e := EvSurvivorHit.new()
	e.monster = MONSTER
	e.survivor = SURVIVOR
	return _emit(e)


func _disconnect(player: int = MONSTER) -> int:
	var e := EvPlayerConnectionChanged.new()
	e.player = player
	e.status = EvPlayerConnectionChanged.DISCONNECTED
	return _emit(e)


## Steps until the Lunge leaves Active; returns the resolution tick.
func _run_out_dash() -> int:
	for i in _windup() + _dash() + 2:
		_step(1)
		if _ma.lunge_state() == MonsterAbilities.Lunge.COOLDOWN:
			return _now()
	fail("the dash never resolved")
	return -1


## Rejected on every tick until `ready`, accepted on `ready` (tick quantisation of 9.99 s vs 10 s).
func _assert_ready_at(ready: int) -> void:
	_step(ready - 1 - _now() - 1)
	assert_bool(_try_lunge()).is_false() ## request served on ready - 1
	assert_bool(_try_lunge()).is_true() ## request served on ready
	assert_int(_now()).is_equal(ready)


# AC-1: miss slow and cooldown -------------------------------------------------------------------

func test_miss_slows_for_miss_slow_s_and_cooldown_runs_from_resolution() -> void:
	assert_bool(_try_lunge()).is_true()
	var r := _run_out_dash()
	assert_array(_hits).is_empty()
	assert_float(_mods.speed_scale).is_equal(_knobs.ability.miss_slow_multiplier)
	assert_float(_mods.dash_speed).is_equal(0.0)
	_step(_slow - 1) ## last slowed tick is r + slow - 1
	assert_float(_mods.speed_scale).is_equal(_knobs.ability.miss_slow_multiplier)
	_step(1)
	assert_int(_now()).is_equal(r + _slow)
	assert_float(_mods.speed_scale).is_equal(1.0)
	assert_int(_ma.ready_tick(MonsterAbilities.Ability.LUNGE)).is_equal(r + _cd)
	_assert_ready_at(r + _cd)


func test_dash_blocked_by_a_door_is_a_miss() -> void:
	assert_bool(_try_lunge()).is_true()
	_step(_windup())
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.ACTIVE)
	_mods.dash_blocked = true ## the movement step met the closed door
	_step(1)
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.COOLDOWN)
	assert_float(_mods.speed_scale).is_equal(_knobs.ability.miss_slow_multiplier)
	assert_int(_ma.ready_tick(MonsterAbilities.Ability.LUNGE)).is_equal(_now() + _cd)


# AC-2: Borrowed Face rule 7 reads "not attacking" during the slow --------------------------------

func test_not_attacking_during_the_miss_slow_so_a_transformation_may_start() -> void:
	var view := LungeView.new(_ma)
	assert_bool(_try_lunge()).is_true()
	assert_bool(view.is_attacking(MONSTER)).is_true()
	_run_out_dash()
	assert_bool(view.is_attacking(MONSTER)).is_false()
	_step(_slow - 1) ## the final slowed tick
	assert_float(_mods.speed_scale).is_less(1.0)
	assert_bool(view.is_attacking(MONSTER)).is_false()


# AC-3: cooldown after a hit ---------------------------------------------------------------------

func test_commit_completing_at_t_readies_the_lunge_at_t_plus_cooldown() -> void:
	assert_bool(_try_lunge()).is_true()
	_step(_windup())
	_hit()
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.TAKEDOWN_COMMIT)
	var downed := EvSurvivorDowned.new()
	downed.survivor = SURVIVOR
	var t := _emit(downed)
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.COOLDOWN)
	assert_float(_mods.speed_scale).is_equal(1.0) ## a hit is no miss
	_assert_ready_at(t + _cd)


func test_commit_cancelled_by_a_stun_at_t_readies_the_lunge_at_t_plus_cooldown() -> void:
	assert_bool(_try_lunge()).is_true()
	_step(_windup())
	_hit()
	var t := _stun()
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.COOLDOWN)
	assert_float(_mods.speed_scale).is_equal(1.0)
	_assert_ready_at(t + _cd)


# AC-4: stun in wind-up or dash ------------------------------------------------------------------

func test_stun_in_windup_resolves_with_no_hit_and_no_slow() -> void:
	assert_bool(_try_lunge()).is_true()
	var t := _stun()
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.COOLDOWN)
	_step(_windup() + _dash())
	assert_array(_hits).is_empty()
	assert_float(_mods.effective_scale()).is_equal(1.0)
	assert_int(_ma.ready_tick(MonsterAbilities.Ability.LUNGE)).is_equal(t + _cd)


func test_stun_locking_the_monster_on_the_dash_last_tick_resolves_with_no_slow() -> void:
	assert_bool(_try_lunge()).is_true()
	_step(_windup() + _dash() - 1)
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.ACTIVE)
	_locked = true ## Survivor Defense's slot stunned the monster earlier on the last dash tick
	_step(1)
	var t := _now()
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.COOLDOWN)
	assert_array(_hits).is_empty()
	assert_float(_mods.effective_scale()).is_equal(1.0)
	assert_int(_ma.ready_tick(MonsterAbilities.Ability.LUNGE)).is_equal(t + _cd)


func test_stun_flushed_after_the_miss_on_the_same_tick_replaces_the_slow() -> void:
	assert_bool(_try_lunge()).is_true()
	var r := _run_out_dash()
	assert_float(_mods.speed_scale).is_equal(_knobs.ability.miss_slow_multiplier)
	var t := _stun() ## carries the resolution tick
	assert_int(t).is_equal(r)
	assert_float(_mods.effective_scale()).is_equal(1.0)
	assert_int(_ma.ready_tick(MonsterAbilities.Ability.LUNGE)).is_equal(t + _cd)


# AC-5: disconnect -------------------------------------------------------------------------------

func test_disconnect_mid_dash_ends_the_lunge_with_no_hit_and_no_slow() -> void:
	assert_bool(_try_lunge()).is_true()
	_step(_windup())
	_disconnect(SURVIVOR) ## someone else's disconnect changes nothing
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.ACTIVE)
	_disconnect()
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.COOLDOWN)
	_step(_dash())
	assert_array(_hits).is_empty()
	assert_float(_mods.effective_scale()).is_equal(1.0)
	assert_float(_mods.dash_speed).is_equal(0.0)


func test_disconnect_flushed_with_the_hit_still_ends_the_lunge() -> void:
	assert_bool(_try_lunge()).is_true()
	_step(_windup())
	var hit := EvSurvivorHit.new()
	hit.monster = MONSTER
	hit.survivor = SURVIVOR
	_server.tick_runner.bus.emit(hit)
	_disconnect() ## same flush as the hit
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.COOLDOWN)
	assert_float(_mods.effective_scale()).is_equal(1.0)
