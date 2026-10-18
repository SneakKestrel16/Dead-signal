# Audio pass, state-driven client sounds (entity-inventory.md Audio rows 2, 7, 8, 16, 20, 34, 35): ClientSfx
# turns the HUD model's frame state into sprint breathing, heartbeat, flashlight clicks, the generator, the
# terminal activation tone, the PA's spoken lines and phase stings.
extends GdUnitTestSuite

const HERE := Vector3(1, 2, 3)
const TERMINAL := Vector3(40, 0, 20)

var _knobs: Knobs
var _sfx: ClientSfx
var _ids: Array[StringName] = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_ids.clear()
	var play := func(id: StringName, _at: Vector3) -> void:
		_ids.append(id)
	_sfx = auto_free(ClientSfx.new(SoundBank.new(), play, func() -> Vector3: return HERE,
			func() -> Vector3: return TERMINAL, _knobs))


func _state(over := {}) -> Dictionary:
	var s := {"phase": MatchFlow.Phase.INFILTRATION, "left_s": 600.0, "sprint": false, "bleed_s": -1.0,
		"light": false, "activation": {}, "ended": false, "won": false}
	s.merge(over, true)
	return s


func _count(id: StringName) -> int:
	return _ids.count(id)


func test_flashlight_clicks_on_each_change_not_on_the_first_frame() -> void:
	_sfx.update(0.016, _state({"light": true}))
	_sfx.update(0.016, _state({"light": true}))
	_sfx.update(0.016, _state({"light": false}))
	_sfx.update(0.016, _state({"light": true}))
	assert_int(_count(ClientSfx.CLICK)).is_equal(2)


func test_breathing_fades_in_while_sprinting_and_out_after() -> void:
	for i in 10:
		_sfx.update(0.1, _state({"sprint": true}))
	assert_float(_sfx.breath_level).is_equal_approx(1.0, 1e-6)
	_sfx.update(0.3, _state())
	assert_float(_sfx.breath_level).is_equal_approx(0.5, 1e-6)
	_sfx.update(0.3, _state())
	assert_float(_sfx.breath_level).is_equal_approx(0.0, 1e-6)


func test_heartbeat_slows_as_the_bleed_out_runs_down() -> void:
	var full := _knobs.downing.bleedout_s
	for i in 100: ## 10 s with most of it left
		_sfx.update(0.1, _state({"bleed_s": full}))
	var fast := _count(ClientSfx.HEART)
	_ids.clear()
	for i in 100: ## 10 s near the end
		_sfx.update(0.1, _state({"bleed_s": 0.5}))
	var slow := _count(ClientSfx.HEART)
	assert_int(fast).is_equal(ceili(10.0 / ClientSfx.HEART_FAST_S))
	assert_int(slow).is_less(fast)
	_ids.clear()
	_sfx.update(5.0, _state())
	assert_int(_count(ClientSfx.HEART)).is_equal(0)


func test_terminal_tone_rises_with_progress_stalls_when_paused_and_stops() -> void:
	var evac := _knobs.objectives.evac_activation_s
	_sfx.update(0.016, _state({"activation": {"remaining_s": evac, "paused": false}}))
	assert_bool(_sfx.tone_on).is_true()
	assert_float(_sfx.tone_pitch).is_equal_approx(ClientSfx.TONE_PITCH.x, 1e-4)
	for i in 100:
		_sfx.update(0.1, _state({"activation": {"remaining_s": 0.01, "paused": false}}))
	assert_float(_sfx.tone_pitch).is_equal_approx(ClientSfx.TONE_PITCH.y, 1e-2)
	for i in 100:
		_sfx.update(0.1, _state({"activation": {"remaining_s": evac / 2.0, "paused": true}}))
	assert_float(_sfx.tone_pitch).is_equal_approx(ClientSfx.TONE_STALL_PITCH, 1e-4)
	_sfx.update(0.016, _state())
	assert_bool(_sfx.tone_on).is_false()


func _run_evacuation(from_left: float, start_phase: int) -> void:
	_sfx.update(0.016, _state({"phase": start_phase, "left_s": from_left + 0.25}))
	var left := from_left
	while left > 0.0:
		_sfx.update(0.25, _state({"phase": MatchFlow.Phase.EVACUATION, "left_s": left}))
		left -= 0.25


func test_timed_evacuation_announces_itself_then_counts_down_and_the_clock_ticks_the_final_30_s() -> void:
	_run_evacuation(_knobs.match_flow.evacuation_window_s, MatchFlow.Phase.INVESTIGATION)
	assert_int(_count(ClientSfx.PA_EVAC_TIMED)).is_equal(1)
	assert_int(_count(ClientSfx.PA_EVAC_ARMED)).is_equal(0)
	assert_int(_count(&"pa/t_120")).override_failure_message("a timed start is the 2:00 mark").is_equal(0)
	for id in [&"pa/t_60", &"pa/t_30", &"pa/t_10", &"pa/count_5", &"pa/count_4", &"pa/count_3", &"pa/count_2", &"pa/count_1"]:
		assert_int(_count(id)).override_failure_message("%s once" % id).is_equal(1)
	assert_int(_count(ClientSfx.TICK)).is_equal(int(ClientSfx.TICK_FROM_S))


func test_early_evacuation_says_the_terminal_is_armed_and_calls_the_2_minute_mark() -> void:
	_run_evacuation(200.0, MatchFlow.Phase.INVESTIGATION)
	assert_int(_count(ClientSfx.PA_EVAC_ARMED)).is_equal(1)
	assert_int(_count(ClientSfx.PA_EVAC_TIMED)).is_equal(0)
	assert_int(_count(&"pa/t_120")).is_equal(1)


func test_joining_mid_evacuation_announces_nothing() -> void:
	_sfx.update(0.016, _state({"phase": MatchFlow.Phase.EVACUATION, "left_s": 100.0}))
	assert_int(_count(ClientSfx.PA_EVAC_TIMED) + _count(ClientSfx.PA_EVAC_ARMED)).is_equal(0)


func test_lockdown_only_when_the_deadline_ends_the_round() -> void:
	_sfx.update(0.016, _state({"ended": true, "won": false, "deadline": true}))
	assert_int(_count(ClientSfx.PA_LOCKDOWN)).is_equal(1)
	before_test()
	_sfx.update(0.016, _state({"ended": true, "won": true, "deadline": false}))
	assert_int(_count(ClientSfx.PA_LOCKDOWN)).is_equal(0)


func test_activation_announces_its_start_each_pause_and_its_completion_once() -> void:
	_sfx.update(0.016, _state({"activation": {"remaining_s": 15.0, "paused": false}}))
	_sfx.update(0.016, _state({"activation": {"remaining_s": 14.0, "paused": false}}))
	_sfx.update(0.016, _state({"activation": {"remaining_s": 14.0, "paused": true}}))
	_sfx.update(0.016, _state({"activation": {"remaining_s": 14.0, "paused": true}}))
	_sfx.update(0.016, _state({"activation": {"remaining_s": 13.0, "paused": false}}))
	_sfx.update(0.016, _state({"activation": {"remaining_s": 13.0, "paused": true}}))
	assert_int(_count(ClientSfx.PA_ACTIVATION_START)).is_equal(1)
	assert_int(_count(ClientSfx.PA_ACTIVATION_PAUSED)).is_equal(2)
	var done := {"objective": SurvivorObjectives.TERMINAL_ID, "state": SurvivorObjectives.TerminalState.ACTIVATED}
	_sfx.on_objective(1, done)
	_sfx.on_objective(2, done)
	assert_int(_count(ClientSfx.PA_ACTIVATION_DONE)).is_equal(1)


func test_investigation_tone_once_on_entering_investigation() -> void:
	_sfx.update(0.016, _state({"phase": MatchFlow.Phase.INVESTIGATION})) ## joining mid-round: no sting
	assert_int(_count(ClientSfx.INVESTIGATION)).is_equal(0)
	before_test()
	_sfx.update(0.016, _state())
	_sfx.update(0.016, _state({"phase": MatchFlow.Phase.INVESTIGATION}))
	_sfx.update(0.016, _state({"phase": MatchFlow.Phase.INVESTIGATION}))
	assert_int(_count(ClientSfx.INVESTIGATION)).is_equal(1)


func test_round_end_plays_the_own_roles_sting_once_and_silences_the_loops() -> void:
	_sfx.update(0.016, _state({"sprint": true, "activation": {"remaining_s": 5.0, "paused": false}}))
	_sfx.update(0.016, _state({"ended": true, "won": true}))
	_sfx.update(0.016, _state({"ended": true, "won": true}))
	assert_int(_count(ClientSfx.WIN)).is_equal(1)
	assert_int(_count(ClientSfx.LOSS)).is_equal(0)
	assert_float(_sfx.breath_level).is_equal(0.0)
	assert_bool(_sfx.tone_on).is_false()


func test_generator_spins_up_once_on_power_restored() -> void:
	var powered := {"objective": SurvivorObjectives.TERMINAL_ID, "state": SurvivorObjectives.TerminalState.POWERED}
	_sfx.on_objective(1, powered)
	_sfx.on_objective(2, powered)
	_sfx.on_objective(3, {"objective": SurvivorObjectives.TERMINAL_ID, "state": SurvivorObjectives.TerminalState.ARMED})
	assert_int(_count(ClientSfx.GENERATOR)).is_equal(1)


func test_every_sound_resolves_in_the_shipped_bank() -> void:
	var bank := SoundBank.load_shipped()
	for id in [ClientSfx.BREATH, ClientSfx.HEART, ClientSfx.CLICK, ClientSfx.GENERATOR, ClientSfx.TONE,
			ClientSfx.INVESTIGATION, ClientSfx.TICK, ClientSfx.WIN, ClientSfx.LOSS, ClientSfx.FACE, ClientSfx.PING,
			ClientSfx.PING_WARNING, ClientSfx.PA_EVAC_TIMED, ClientSfx.PA_EVAC_ARMED, ClientSfx.PA_LOCKDOWN,
			ClientSfx.PA_ACTIVATION_START, ClientSfx.PA_ACTIVATION_PAUSED, ClientSfx.PA_ACTIVATION_DONE, WorldSfx.CLATTER, WorldSfx.EJECT, WorldSfx.ALERT, WorldSfx.RELAY, WorldSfx.RELIEF,
			WorldSfx.ELIMINATED, HidingSpots.SEARCH_SOUND, BodySfx.STRUGGLE, BodySfx.GASP, BodySfx.COLLAPSE] + BodySfx.LOOPS.values() + ClientSfx.PA_MARKS.values():
		var e := bank.resolve(id)
		assert_object(e).override_failure_message("no bank entry for %s" % id).is_not_null()
		assert_object(e.stream).is_not_null()
	assert_bool(bank.resolve(ClientSfx.BREATH).loop).is_true()
	assert_bool(bank.resolve(ClientSfx.TONE).loop).is_true()
	for id in BodySfx.LOOPS.values():
		assert_bool(bank.resolve(id).loop).override_failure_message("%s should loop" % id).is_true()


func test_a_face_becoming_available_ticks_once() -> void:
	_sfx.update(0.016, _state({"faces": 1})) ## the first frame is the baseline
	_sfx.update(0.016, _state({"faces": 2}))
	_sfx.update(0.016, _state({"faces": 2}))
	_sfx.update(0.016, _state({"faces": 1}))
	assert_int(_count(ClientSfx.FACE)).is_equal(1)


func test_pings_tick_at_their_point_and_warnings_sound_sharper() -> void:
	_sfx.on_ping(1, {"kind": PingsCallouts.LOCATION, "point": TERMINAL})
	_sfx.on_ping(2, {"kind": PingsCallouts.WARNING_POINT, "point": TERMINAL})
	_sfx.on_ping(3, {"kind": PingsCallouts.LOCATION})
	assert_array(_ids).is_equal([ClientSfx.PING, ClientSfx.PING_WARNING])
