# Story monster-abilities/003: Lunge hit test on rewound positions (design/gdd/monster-abilities.md rule 7
# "Latency" and Formulas "Dodge window"; ADR-0003 §3-5, NA-7 LagCompensation). The monster reports a view
# tick from its RTT (ack = tick - RTT, view = ack - interp delay, as the client's interpolation shows);
# survivor positions come from a per-tick schedule pushed into RewindHistory, so which tick the hit test
# read is visible in whether it hit. Eligibility and sight are current state (Downing.is_eligible here).
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const SURVIVORS: Array[int] = [2]
const H := 1.8
const R := 0.3
const AWAY := Vector3(100.0, 0.0, 100.0)
## In range and cone: 1 m straight ahead of a monster at the origin facing -Z.
const IN := Vector3(0.0, 0.0, -1.0)
## Dodge smoke (AC-6): survivor 3 m ahead strafing at 4.0 m/s from 0.25 s after the cue, 150 ms RTT.
const DODGE_DIST := 3.0
const DODGE_SPEED := 4.0
const DODGE_REACTION_S := 0.25
const DODGE_RTT_MS := 150.0
const FAR_TICK := 1000000

var _knobs: Knobs
var _server: RoundServer
var _ma: MonsterAbilities
var _lc: LagCompensation
var _history: RewindHistory
var _frame := InputFrame.new()
var _hits: Array[EvSurvivorHit] = []
var _rtt_ms := 0.0
## S1 stands at IN through this tick and AWAY after it (-1 = the dodge schedule).
var _in_until := 0
var _hidden := false
var _grace_end := 0
## Dodge smoke state: the monster's position and facing, the cue (wind-up start) tick.
var _m_pos := Vector3.ZERO
var _m_facing := Vector3.FORWARD
var _cue_tick := 0
var _s_pos := AWAY


func before_test() -> void:
	_knobs = Knobs.load_all()
	_history = RewindHistory.new(_knobs.net.history_ticks)
	_frame = InputFrame.new()
	_lc = LagCompensation.new(_knobs, _history, _frame_of)
	_hits = []
	_hidden = false
	_grace_end = 0
	_m_pos = Vector3.ZERO
	_m_facing = Vector3.FORWARD
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_ma = MonsterAbilities.new()
	_ma.set_monster(MONSTER)
	_ma.set_hit_sources(_lc, SURVIVORS, _eligible, _facing_of)
	var errs := _server.start_round({TickOrder.MONSTER_ABILITIES: _ma}, _knobs)
	assert_array(errs).is_empty()
	_server.tick_runner.input_stage = _in_stage
	_server.tick_runner.history_stage = _push
	_server.tick_runner.bus.subscribe(&"SurvivorHit", _on_hit)


func after_test() -> void:
	if _server != null:
		_server.end_round()


func _ticks_of(ms: float) -> float:
	return ms * _knobs.net.sim_tick_hz / 1000.0


func _cap() -> float:
	return _ticks_of(_knobs.ability.max_rewind_ms)


func _in_stage(tick: int) -> void:
	var ack := tick - roundi(_ticks_of(_rtt_ms))
	_frame.ack_snapshot_tick = ack
	_frame.view_tick = ack - _ticks_of(_knobs.net.interp_delay_ms)


func _push(tick: int) -> void:
	var s := _s_pos
	if _in_until >= 0:
		s = IN if tick <= _in_until else AWAY
	_history.push(tick, S1, s, H, R, s + Vector3(0.0, H - R, 0.0))
	_history.push(tick, MONSTER, _m_pos, H, R, _m_pos + Vector3(0.0, H - R, 0.0))


func _frame_of(_player: int) -> InputFrame:
	return _frame


func _facing_of(_player: int) -> Vector3:
	return _m_facing


func _eligible(p: int) -> bool:
	return Downing.is_eligible(Downing.LifeState.HEALTHY, _hidden, _server.tick_runner.current_tick(), _grace_end)


func _on_hit(e: ServerEvent) -> void:
	_hits.append(e as EvSurvivorHit)


func _now() -> int:
	return _server.tick_runner.current_tick()


func _step(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


## The tick Active begins for a lunge requested now.
func _active_tick() -> int:
	return _now() + 1 + _knobs.ticks(_knobs.ability.lunge_windup_s)


func _lunge() -> void:
	_ma.request_ability(MONSTER, MonsterAbilities.request_packet(MonsterAbilities.Ability.LUNGE))
	_step(1 + _knobs.ticks(_knobs.ability.lunge_windup_s) + _knobs.ticks(_knobs.ability.lunge_dash_s) + 2)


func _clamps() -> Array[Dictionary]:
	return _lc.records.filter(func(r: Dictionary) -> bool: return r.kind == "clamped")


# AC-5: rewind -----------------------------------------------------------------------------------

func test_80_ms_rtt_rewinds_to_the_viewed_tick() -> void:
	_rtt_ms = 80.0
	var lag := roundi(_ticks_of(_rtt_ms)) + _ticks_of(_knobs.net.interp_delay_ms)
	assert_float(lag).is_less(_cap())
	var active := _active_tick()
	_in_until = active - ceili(lag) ## in range at the viewed tick only, gone by the current one
	_lunge()
	assert_int(_hits.size()).is_equal(1)
	assert_int(_hits[0].tick).is_equal(active)
	assert_array(_clamps()).is_empty()


func test_80_ms_rtt_does_not_hit_what_left_before_the_viewed_tick() -> void:
	_rtt_ms = 80.0
	var lag := roundi(_ticks_of(_rtt_ms)) + _ticks_of(_knobs.net.interp_delay_ms)
	_in_until = _active_tick() - ceili(lag) - 2
	_lunge()
	assert_array(_hits).is_empty()


func test_300_ms_rtt_rewinds_exactly_the_cap() -> void:
	_rtt_ms = 300.0
	var active := _active_tick()
	_in_until = active - floori(_cap())
	_lunge()
	assert_int(_hits.size()).is_equal(1)
	assert_int(_hits[0].tick).is_equal(active)
	var c := _clamps()
	assert_bool(c.is_empty()).is_false()
	assert_float(c[0].applied).is_equal_approx(_cap(), 1e-6)


func test_300_ms_rtt_never_rewinds_past_the_cap() -> void:
	_rtt_ms = 300.0
	_in_until = _active_tick() - floori(_cap()) - 2 ## in view at 300 ms, but older than the cap
	_lunge()
	assert_array(_hits).is_empty()


func test_rewind_one_tick_either_side_of_the_cap() -> void:
	var t := 100
	_frame.ack_snapshot_tick = t - 20
	_frame.view_tick = t - (_cap() - 1.0)
	assert_float(_lc.rewind_ticks(MONSTER, t)).is_equal_approx(_cap() - 1.0, 1e-6)
	_frame.view_tick = t - (_cap() + 1.0)
	assert_float(_lc.rewind_ticks(MONSTER, t)).is_equal_approx(_cap(), 1e-6)


func test_unset_view_tick_clamps_to_the_cap() -> void:
	var t := 100
	_frame = InputFrame.new() ## view_tick and ack unset (0)
	assert_float(_lc.rewind_ticks(MONSTER, t)).is_equal_approx(_cap(), 1e-6)


func test_survivor_hidden_after_the_rewound_time_is_not_hit() -> void:
	_rtt_ms = 80.0
	_in_until = FAR_TICK
	_hidden = true ## hid after the viewed tick: eligibility is current state
	_lunge()
	assert_array(_hits).is_empty()


func test_survivor_in_grace_after_the_rewound_time_is_not_hit() -> void:
	_rtt_ms = 80.0
	_in_until = FAR_TICK
	_grace_end = FAR_TICK
	_lunge()
	assert_array(_hits).is_empty()


# AC-6: dodge smoke ---------------------------------------------------------------------------------

## Steering pursuit (monster-abilities.md Formulas, governing model): the monster turns toward the
## survivor's current position within the wind-up / dash turn caps and dashes along its facing; the
## survivor strafes +X at walk speed from 0.25 s after the cue. Rerun after any change to wind-up, turn
## rates, dash, radius or cone (Control Manifest guardrail).
func test_strafing_survivor_dodges_at_150_ms_rtt() -> void:
	_rtt_ms = DODGE_RTT_MS
	_in_until = -1
	_s_pos = Vector3(0.0, 0.0, -DODGE_DIST)
	_server.tick_runner.movement_stage = _dodge_move
	_cue_tick = _now() + 1
	_lunge()
	assert_int(_ma.lunge_state()).is_equal(MonsterAbilities.Lunge.COOLDOWN)
	assert_array(_hits).is_empty()
	assert_float(_m_pos.length()).override_failure_message("the dash ran").is_greater(_knobs.ability.lunge_distance_m * 0.9)


func _dodge_move(tick: int) -> void:
	var hz := float(_knobs.net.sim_tick_hz)
	var t := (tick - _cue_tick) / hz
	if t > DODGE_REACTION_S:
		_s_pos.x = DODGE_SPEED * (t - DODGE_REACTION_S)
	var state := _ma.lunge_state()
	var turn_deg := 0.0
	if state == MonsterAbilities.Lunge.WIND_UP:
		turn_deg = _knobs.ability.lunge_windup_turn_deg_s
	elif state == MonsterAbilities.Lunge.ACTIVE:
		turn_deg = _knobs.ability.lunge_dash_turn_deg_s
	else:
		return
	var want := Vector2(_s_pos.x - _m_pos.x, _s_pos.z - _m_pos.z)
	var have := Vector2(_m_facing.x, _m_facing.z)
	var step := clampf(have.angle_to(want), -deg_to_rad(turn_deg) / hz, deg_to_rad(turn_deg) / hz)
	have = have.rotated(step)
	_m_facing = Vector3(have.x, 0.0, have.y)
	if state == MonsterAbilities.Lunge.ACTIVE:
		var speed := _knobs.ability.lunge_distance_m * hz / _knobs.ticks(_knobs.ability.lunge_dash_s)
		_m_pos += _m_facing * speed / hz

