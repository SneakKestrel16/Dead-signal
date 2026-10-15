# Story monster-abilities/008: lunge hit, miss and interrupted counts for the results screen
# (design/gdd/monster-abilities.md "HUD & Results Screen"; ADR-0011 §1-2, a getter-only view under
# StateKeys.STATS_ABILITIES read once by RoundResults). Hits, commit ends and stuns are emitted directly,
# as in lunge_resolution_test.
extends GdUnitTestSuite

const MONSTER := 1
const SURVIVOR := 2

var _knobs: Knobs
var _server: RoundServer
var _ma: MonsterAbilities


func before_test() -> void:
	_knobs = Knobs.load_all()
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_start()


func after_test() -> void:
	if _server != null:
		_server.end_round()


func _start() -> void:
	_ma = MonsterAbilities.new()
	_ma.set_monster(MONSTER)
	assert_array(_server.start_round({TickOrder.MONSTER_ABILITIES: _ma}, _knobs)).is_empty()


func _view() -> AbilitiesStatsView:
	return _server.registry.view(StateKeys.STATS_ABILITIES, AbilitiesStatsView) as AbilitiesStatsView


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


func _emit(e: ServerEvent) -> void:
	_server.tick_runner.bus.emit(e)
	_step(1)


## Requests a lunge and waits out any cooldown first; true once wind-up started.
func _lunge() -> bool:
	for i in _knobs.ticks(_knobs.ability.lunge_cooldown_s) + 2:
		_ma.request_ability(MONSTER, MonsterAbilities.request_packet(MonsterAbilities.Ability.LUNGE))
		_step(1)
		if _ma.lunge_state() == MonsterAbilities.Lunge.WIND_UP:
			return true
	return false


func _to_active() -> void:
	_step(_knobs.ticks(_knobs.ability.lunge_windup_s))
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.ACTIVE)


func _miss() -> void:
	assert_bool(_lunge()).is_true()
	_step(_knobs.ticks(_knobs.ability.lunge_windup_s) + _knobs.ticks(_knobs.ability.lunge_dash_s) + 1)
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.COOLDOWN)


func _land() -> void:
	assert_bool(_lunge()).is_true()
	_to_active()
	var hit := EvSurvivorHit.new()
	hit.monster = MONSTER
	hit.survivor = SURVIVOR
	_emit(hit)
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.TAKEDOWN_COMMIT)
	var down := EvSurvivorDowned.new()
	down.survivor = SURVIVOR
	_emit(down)


func _stun() -> void:
	var e := EvMonsterStunned.new()
	e.monster = MONSTER
	_emit(e)


func _assert_counts(landed: int, missed: int, interrupted: int) -> void:
	var v := _view()
	assert_int(v.get_lunges_landed()).is_equal(landed)
	assert_int(v.get_lunges_missed()).is_equal(missed)
	assert_int(v.get_lunges_interrupted()).is_equal(interrupted)


func test_view_registered_and_zero_at_round_start() -> void:
	assert_object(_view()).is_not_null()
	_assert_counts(0, 0, 0)
	assert_int(_view().get_false_signals_used()).is_equal(0)
	assert_int(_view().get_blackouts_used()).is_equal(0)


func test_miss_counts_missed() -> void:
	_miss()
	_assert_counts(0, 1, 0)


func test_hit_counts_landed_once_and_commit_stun_is_not_an_interrupt() -> void:
	_land()
	_assert_counts(1, 0, 0)
	assert_bool(_lunge()).is_true()
	_to_active()
	var hit := EvSurvivorHit.new()
	hit.monster = MONSTER
	hit.survivor = SURVIVOR
	_emit(hit)
	_stun() ## cancels the commit: the lunge still hit
	_assert_counts(2, 0, 0)


func test_stun_in_wind_up_and_active_counts_interrupted() -> void:
	assert_bool(_lunge()).is_true()
	_stun()
	_assert_counts(0, 0, 1)
	assert_bool(_lunge()).is_true()
	_to_active()
	_stun()
	_assert_counts(0, 0, 2)


func test_stun_outside_a_lunge_counts_nothing() -> void:
	_stun()
	_miss()
	_stun() ## in cooldown
	_assert_counts(0, 1, 0)


func test_counts_appear_in_results_payload() -> void:
	_land()
	_miss()
	assert_bool(_lunge()).is_true()
	_stun()
	## MatchFlow's own view, its module already freed: reads -1 ticks (only the monster stats are under test).
	_server.registry.register_view(StateKeys.STATS_MATCH, &"MatchFlow", MatchStatsView.new(MatchFlow.new()))
	var r := RoundResults.read(_server.registry, [] as Array[int], MONSTER, 0, 0, _knobs.net.sim_tick_hz)
	assert_int(r.monster[&"lunges_landed"]).is_equal(1)
	assert_int(r.monster[&"lunges_missed"]).is_equal(1)
	assert_int(r.monster[&"lunges_interrupted"]).is_equal(1)
	assert_array(r.missing).not_contains([StateKeys.STATS_ABILITIES])


func test_counters_reset_at_round_start() -> void:
	_land()
	_miss()
	assert_bool(_lunge()).is_true()
	_stun()
	## the same module into the next round: setup clears its counts
	assert_array(_server.start_round({TickOrder.MONSTER_ABILITIES: _ma}, _knobs)).is_empty()
	_assert_counts(0, 0, 0)
