# Story monster-abilities/003: Lunge hit test (design/gdd/monster-abilities.md rules 7-8, Formulas
# "Lunge hit check"; ADR-0003 §3-6). MonsterAbilities runs on a RoundServer with a RewindHistory fed by
# the test's history stage; eligibility is Downing.is_eligible over test-held life, hidden and grace
# state; chest line of sight is a test door plane (MapQueries.clear_sight in the composer). The
# monster stands at the origin facing -Z and does not move (no movement modifiers are injected).
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const S2 := 3
const S3 := 4
const S4 := 5
const SURVIVORS: Array[int] = [2, 3, 4, 5]
const H := 1.8
const R := 0.3
## Where bodies not in a test stand.
const AWAY := Vector3(100.0, 0.0, 100.0)
## View lag in ticks, well inside the rewind cap; positions here are static so it only exercises the path.
const VIEW_LAG := 4.0
## A test door leaf across the -Z path at this z (closed when _door_closed).
const DOOR_Z := -0.5
const FAR_TICK := 1000000

var _knobs: Knobs
var _server: RoundServer
var _ma: MonsterAbilities
var _lc: LagCompensation
var _history: RewindHistory
var _frame := InputFrame.new()
var _pos: Dictionary[int, Vector3] = {}
var _life: Dictionary[int, int] = {}
var _hidden: Dictionary[int, bool] = {}
var _grace_end: Dictionary[int, int] = {}
var _hits: Array[EvSurvivorHit] = []
var _states: Array = [] ## [Lunge, tick] per transition
var _door_closed := false
var _locked := false


func before_test() -> void:
	_knobs = Knobs.load_all()
	_history = RewindHistory.new(_knobs.net.history_ticks)
	_frame = InputFrame.new()
	_lc = LagCompensation.new(_knobs, _history, _frame_of)
	_pos = {MONSTER: Vector3.ZERO}
	_life = {}
	_hidden = {}
	_grace_end = {}
	_hits = []
	_states = []
	_door_closed = false
	_locked = false
	for s in SURVIVORS:
		_pos[s] = AWAY + Vector3(s * 10.0, 0.0, 0.0)
		_life[s] = Downing.LifeState.HEALTHY
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_ma = MonsterAbilities.new()
	_ma.set_monster(MONSTER)
	_ma.set_status_sources(Callable(), Callable(), _locked_of)
	_ma.set_hit_sources(_lc, SURVIVORS, _eligible, _facing_of, _sight)
	_ma.on_lunge_state = _on_state
	var errs := _server.start_round({TickOrder.MONSTER_ABILITIES: _ma}, _knobs)
	assert_array(errs).is_empty()
	_server.tick_runner.input_stage = _in_stage
	_server.tick_runner.history_stage = _push
	_server.tick_runner.bus.subscribe(&"SurvivorHit", _on_hit)


func after_test() -> void:
	if _server != null:
		_server.end_round()


func _in_stage(tick: int) -> void:
	_frame.view_tick = tick - VIEW_LAG
	_frame.ack_snapshot_tick = int(tick - VIEW_LAG)


func _push(tick: int) -> void:
	for id: int in _pos:
		_history.push(tick, id, _pos[id], H, R, _pos[id] + Vector3(0.0, H - R, 0.0))


func _frame_of(_player: int) -> InputFrame:
	return _frame


func _facing_of(_player: int) -> Vector3:
	return Vector3.FORWARD


func _locked_of(_player: int) -> bool:
	return _locked


func _eligible(p: int) -> bool:
	return Downing.is_eligible(_life[p], _hidden.get(p, false), _now(), _grace_end.get(p, 0))


func _sight(_from: Vector3, to: Vector3) -> bool:
	return not (_door_closed and to.z < DOOR_Z)


func _on_hit(e: ServerEvent) -> void:
	_hits.append(e as EvSurvivorHit)


func _on_state(state: MonsterAbilities.Lunge, tick: int) -> void:
	_states.append([state, tick])


func _now() -> int:
	return _server.tick_runner.current_tick()


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


## Requests a lunge and steps through acceptance; returns the tick Active begins.
func _request() -> int:
	_ma.request_ability(MONSTER, MonsterAbilities.request_packet(MonsterAbilities.Ability.LUNGE))
	_step(1)
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.WIND_UP)
	return _now() + _knobs.ticks(_knobs.ability.lunge_windup_s)


## A whole lunge: request, wind-up and dash. Returns the hit survivors in order.
func _lunge() -> Array[int]:
	_request()
	_step(_knobs.ticks(_knobs.ability.lunge_windup_s) + _knobs.ticks(_knobs.ability.lunge_dash_s) + 2)
	var ids: Array[int] = []
	for h in _hits:
		ids.append(h.survivor)
	return ids


## `dist` m from the monster's centre (feet), `deg` degrees right of -Z.
func _ahead(dist: float, deg: float = 0.0) -> Vector3:
	var a := deg_to_rad(deg)
	return Vector3(sin(a), 0.0, -cos(a)) * dist


func _surface(gap: float) -> float:
	return gap + R


# AC-1: eligibility, range, cone, line of sight -------------------------------------------------

func test_only_the_eligible_survivor_is_hit_when_ineligible_ones_are_closer() -> void:
	_pos[S1] = _ahead(1.0)
	_pos[S2] = _ahead(0.6, 10.0)
	_hidden[S2] = true
	_pos[S3] = _ahead(0.7, -10.0)
	_life[S3] = Downing.LifeState.SEIZED
	_pos[S4] = _ahead(0.8, 5.0)
	_grace_end[S4] = FAR_TICK
	assert_array(_lunge()).is_equal([S1])
	assert_int(_hits[0].monster).is_equal(MONSTER)
	assert_vector(_hits[0].position).is_equal(_pos[S1])


func test_downed_survivor_is_not_hit() -> void:
	_pos[S1] = _ahead(1.0)
	_life[S1] = Downing.LifeState.DOWNED
	assert_array(_lunge()).is_empty()


func test_exactly_1_2_m_from_the_body_is_hit() -> void:
	_pos[S1] = _ahead(_surface(_knobs.ability.lunge_hit_radius_m))
	assert_array(_lunge()).is_equal([S1])


func test_beyond_1_2_m_is_not_hit() -> void:
	_pos[S1] = _ahead(_surface(_knobs.ability.lunge_hit_radius_m + 0.01))
	assert_array(_lunge()).is_empty()


func test_exactly_on_the_cone_edge_is_hit() -> void:
	_pos[S1] = _ahead(1.0, _knobs.ability.lunge_cone_deg / 2.0)
	assert_array(_lunge()).is_equal([S1])


func test_outside_the_cone_is_not_hit() -> void:
	_pos[S1] = _ahead(1.0, _knobs.ability.lunge_cone_deg / 2.0 + 1.0)
	_pos[S2] = _ahead(1.0, -(_knobs.ability.lunge_cone_deg / 2.0 + 1.0))
	assert_array(_lunge()).is_empty()


func test_stun_during_windup_blocks_the_hit() -> void:
	_pos[S1] = _ahead(1.0)
	_request()
	var stun := EvMonsterStunned.new()
	stun.monster = MONSTER
	_server.tick_runner.bus.emit(stun)
	_step(_knobs.ticks(_knobs.ability.lunge_windup_s) + _knobs.ticks(_knobs.ability.lunge_dash_s) + 2)
	assert_array(_hits).is_empty()


func test_monster_locked_on_the_active_tick_hits_nobody() -> void:
	_pos[S1] = _ahead(1.0)
	var active := _request()
	_locked = true ## stunned or shock-locked now: current state, never rewound (ADR-0003 §5)
	_step(active - _now())
	assert_array(_hits).is_empty()


# AC-2: two valid targets --------------------------------------------------------------------------

func test_only_the_closer_of_two_is_hit_and_the_dash_ends_that_tick() -> void:
	_pos[S1] = _ahead(1.2)
	_pos[S2] = _ahead(0.9, 10.0)
	var active := _request()
	_step(active - _now())
	assert_int(_hits.size()).is_equal(1)
	assert_int(_hits[0].survivor).is_equal(S2)
	assert_int(_hits[0].tick).is_equal(active)
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.TAKEDOWN_COMMIT)
	assert_array(_states.back()).is_equal([MonsterAbilities.Lunge.TAKEDOWN_COMMIT, active])
	_step(3)
	assert_int(_hits.size()).is_equal(1)


func test_equal_distance_tie_goes_to_the_lower_player_id() -> void:
	_pos[S2] = _ahead(1.0, 10.0)
	_pos[S1] = _ahead(1.0, -10.0)
	assert_array(_lunge()).is_equal([S1])


# AC-3: closed door -----------------------------------------------------------------------------

func test_survivor_behind_a_closed_door_is_never_hit() -> void:
	_pos[S1] = _ahead(1.0)
	_door_closed = true
	assert_array(_lunge()).is_empty()


func test_door_opened_on_a_dash_tick_hits_on_that_tick() -> void:
	_pos[S1] = _ahead(1.0)
	_door_closed = true
	var active := _request()
	_step(active - _now() + 2)
	assert_array(_hits).is_empty()
	_door_closed = false ## door state is current, never rewound
	_step(1)
	assert_int(_hits.size()).is_equal(1)
	assert_int(_hits[0].tick).is_equal(active + 3)


# AC-4: grace and hidden ----------------------------------------------------------------------------

func test_grace_and_hidden_survivors_in_cone_and_radius_are_not_hit() -> void:
	_pos[S1] = _ahead(1.0)
	_grace_end[S1] = FAR_TICK ## post-rescue grace
	_pos[S2] = _ahead(1.0, 10.0)
	_grace_end[S2] = FAR_TICK ## post-release grace: the same grace_end in Downing
	_pos[S3] = _ahead(1.0, -10.0)
	_hidden[S3] = true
	assert_array(_lunge()).is_empty()


func test_grace_expiring_on_a_dash_tick_is_hit_on_that_tick() -> void:
	_pos[S1] = _ahead(1.0)
	_ma.request_ability(MONSTER, MonsterAbilities.request_packet(MonsterAbilities.Ability.LUNGE))
	var active := _now() + 1 + _knobs.ticks(_knobs.ability.lunge_windup_s)
	_grace_end[S1] = active + 2
	_step(active - _now() + 1)
	assert_array(_hits).is_empty()
	_step(1)
	assert_int(_hits.size()).is_equal(1)
	assert_int(_hits[0].tick).is_equal(active + 2)
