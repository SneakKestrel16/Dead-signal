# Story monster-abilities/007: the Lunge's positional sounds on the server (design/gdd/monster-abilities.md
# rule 5 and Visual/Audio Requirements; ADR-0013 §2, ADR-0004 §6). The wind-up cue goes out from the Lunge
# state on the wind-up tick at the monster's position and lunge_cue_radius_m, the dash starts exactly
# lunge_windup_s later; a miss sends the scrape, a server-confirmed hit (SurvivorHit) the hit sound.
# MonsterAbilities runs with no hit sources: SurvivorHit and MonsterStunned are emitted by the test.
extends GdUnitTestSuite

const MONSTER := 1
const SURVIVOR := 2
const MONSTER_AT := Vector3(3.0, 0.0, -7.0)
const HIT_AT := Vector3(3.0, 0.0, -9.5)

var _knobs: Knobs
var _server: RoundServer
var _ma: MonsterAbilities
var _sounds: Array = [] ## [tick, position, set, radius]
var _locked := false


func before_test() -> void:
	_knobs = Knobs.load_all()
	_sounds = []
	_locked = false
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_ma = MonsterAbilities.new()
	_ma.set_monster(MONSTER)
	_ma.set_position_source(_position_of)
	_ma.set_status_sources(Callable(), Callable(), _locked_of)
	_ma.set_sound_sink(_emit_sound)
	assert_array(_server.start_round({TickOrder.MONSTER_ABILITIES: _ma}, _knobs)).is_empty()


func after_test() -> void:
	if _server != null:
		_server.end_round()


func _position_of(_player: int) -> Vector3:
	return MONSTER_AT


func _locked_of(_player: int) -> bool:
	return _locked


func _emit_sound(position: Vector3, sound_set: StringName, radius_m: float) -> void:
	_sounds.append([_server.tick_runner.current_tick(), position, sound_set, radius_m])


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


func _lunge() -> int:
	_ma.request_ability(MONSTER, MonsterAbilities.request_packet(MonsterAbilities.Ability.LUNGE))
	_step(1)
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.WIND_UP)
	return _server.tick_runner.current_tick()


func _sets() -> Array:
	return _sounds.map(func(s: Array) -> StringName: return s[2])


func test_cue_goes_out_on_the_wind_up_tick_lunge_windup_s_before_the_dash() -> void:
	var start := _lunge()
	assert_array(_sounds).is_equal([[start, MONSTER_AT, MonsterAbilities.CUE_SOUND, _knobs.ability.lunge_cue_radius_m]])
	var windup := _knobs.ticks(_knobs.ability.lunge_windup_s)
	_step(windup - 1)
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.WIND_UP)
	_step(1)
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.ACTIVE)
	assert_int(_server.tick_runner.current_tick() - start).is_equal(windup)


func test_a_miss_sends_one_scrape_at_the_monster() -> void:
	_lunge()
	_step(_knobs.ticks(_knobs.ability.lunge_windup_s) + _knobs.ticks(_knobs.ability.lunge_dash_s) + 2)
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.COOLDOWN)
	assert_array(_sets()).is_equal([MonsterAbilities.CUE_SOUND, MonsterAbilities.SCRAPE_SOUND])
	assert_vector(_sounds[1][1]).is_equal(MONSTER_AT)


func test_a_server_confirmed_hit_sends_the_hit_sound_at_the_hit_position_and_no_scrape() -> void:
	_lunge()
	_step(_knobs.ticks(_knobs.ability.lunge_windup_s))
	var e := EvSurvivorHit.new()
	e.monster = MONSTER
	e.survivor = SURVIVOR
	e.position = HIT_AT
	_server.tick_runner.bus.emit(e)
	_step(_knobs.ticks(_knobs.ability.lunge_dash_s) + 2)
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.TAKEDOWN_COMMIT)
	assert_array(_sets()).is_equal([MonsterAbilities.CUE_SOUND, MonsterAbilities.HIT_SOUND])
	assert_vector(_sounds[1][1]).is_equal(HIT_AT)


func test_a_stun_interrupted_lunge_sends_no_scrape() -> void:
	_lunge()
	var e := EvMonsterStunned.new()
	e.monster = MONSTER
	_server.tick_runner.bus.emit(e)
	_locked = true
	_step(_knobs.ticks(_knobs.ability.lunge_windup_s) + _knobs.ticks(_knobs.ability.lunge_dash_s) + 2)
	assert_array(_sets()).is_equal([MonsterAbilities.CUE_SOUND])


func test_no_sink_sends_nothing_and_still_lunges() -> void:
	_ma.set_sound_sink(Callable())
	_lunge()
	assert_array(_sounds).is_empty()
