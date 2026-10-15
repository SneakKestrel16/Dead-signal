# Story match-flow/001: round clock and phase machine (design/gdd/match-flow.md rules 4-7).
extends GdUnitTestSuite

const HZ := 60
const ARMED := SurvivorObjectives.TerminalState.ARMED

var _server: RoundServer
var _mf: MatchFlow
var _phases: Array[int]


func _start(knobs: Knobs = Knobs.load_all()) -> void:
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_mf = MatchFlow.new()
	_phases = []
	var errs := _server.start_round({TickOrder.MATCH_FLOW_BEGIN: _mf,
		TickOrder.MATCH_FLOW_RESOLVE: _mf.resolve_step()}, knobs)
	assert_array(errs).is_empty()
	_server.bus.subscribe(&"RoundPhaseChanged", func(e: ServerEvent) -> void:
		_phases.append((e as EvRoundPhaseChanged).phase))


func _step_to(seconds: float) -> void:
	var target := roundi(seconds * HZ)
	while _server.tick_runner.current_tick() < target:
		_server.tick_runner.step()


func _arm(state: int = ARMED, objective: int = SurvivorObjectives.TERMINAL_ID) -> void:
	var e := EvObjectiveProgressChanged.new()
	e.objective = objective
	e.state = state
	_server.bus.emit(e)
	_server.bus.flush()


func after_test() -> void:
	if _server != null:
		_server.end_round()


func test_default_run_phases_change_at_boundaries_and_deadline_hits_zero() -> void:
	_start()
	_step_to(119.0 + 59.0 / HZ)
	assert_int(_mf.phase()).is_equal(MatchFlow.Phase.INFILTRATION)
	_step_to(120.0)
	assert_int(_mf.phase()).is_equal(MatchFlow.Phase.INVESTIGATION)
	_step_to(419.0 + 59.0 / HZ)
	assert_int(_mf.phase()).is_equal(MatchFlow.Phase.INVESTIGATION)
	_step_to(420.0)
	assert_int(_mf.phase()).is_equal(MatchFlow.Phase.EVACUATION)
	_step_to(539.0 + 59.0 / HZ)
	assert_float(_mf.time_remaining_s()).is_greater(0.0)
	_step_to(540.0)
	assert_float(_mf.time_remaining_s()).is_equal(0.0)
	assert_float(_mf.elapsed_s()).is_equal(540.0)
	assert_array(_phases).is_equal([MatchFlow.Phase.INVESTIGATION, MatchFlow.Phase.EVACUATION])


func test_phase_and_time_remaining_are_published_in_the_registry() -> void:
	_start()
	_step_to(130.0)
	var v := _server.registry.view(StateKeys.ROUND_CLOCK, MatchFlow.ClockView) as MatchFlow.ClockView
	assert_int(v.phase()).is_equal(MatchFlow.Phase.INVESTIGATION)
	assert_float(v.time_remaining_s()).is_equal(410.0)


func test_static_phase_function_covers_boundaries_without_a_round() -> void:
	assert_int(MatchFlow.phase_at(119.99, false, 120.0, 420.0)).is_equal(MatchFlow.Phase.INFILTRATION)
	assert_int(MatchFlow.phase_at(120.0, false, 120.0, 420.0)).is_equal(MatchFlow.Phase.INVESTIGATION)
	assert_int(MatchFlow.phase_at(420.0, false, 120.0, 420.0)).is_equal(MatchFlow.Phase.EVACUATION)
	assert_int(MatchFlow.phase_at(0.0, true, 120.0, 420.0)).is_equal(MatchFlow.Phase.EVACUATION)
	assert_float(MatchFlow.time_remaining_at(600.0, 540.0)).is_equal(0.0)


func test_arming_at_300s_switches_to_evacuation_and_keeps_deadline() -> void:
	_start()
	_step_to(300.0)
	_arm()
	assert_int(_mf.phase()).is_equal(MatchFlow.Phase.EVACUATION)
	assert_float(_mf.time_remaining_s()).is_equal(240.0)
	_step_to(540.0)
	assert_float(_mf.time_remaining_s()).is_equal(0.0)


func test_arming_at_60s_skips_investigation_with_exactly_one_event() -> void:
	_start()
	_step_to(60.0)
	_arm()
	_step_to(540.0)
	assert_array(_phases).is_equal([MatchFlow.Phase.EVACUATION])


func test_arming_on_the_tick_investigation_begins_yields_two_ordered_events() -> void:
	_start()
	_step_to(120.0)
	_arm()
	assert_array(_phases).is_equal([MatchFlow.Phase.INVESTIGATION, MatchFlow.Phase.EVACUATION])


func test_full_round_arming_at_300s_sends_three_changes_never_backwards() -> void:
	_start()
	_step_to(300.0)
	_arm()
	_arm(0) # a non-armed state afterwards changes nothing
	_arm()  # repeated arming emits nothing new
	_step_to(540.0)
	assert_array(_phases).is_equal([MatchFlow.Phase.INVESTIGATION, MatchFlow.Phase.EVACUATION])
	assert_int(_mf.phase()).is_equal(MatchFlow.Phase.EVACUATION)


func test_unrelated_objective_state_does_not_arm() -> void:
	_start()
	_step_to(10.0)
	_arm(ARMED + 1)
	assert_int(_mf.phase()).is_equal(MatchFlow.Phase.INFILTRATION)


func test_resolve_hook_runs_each_tick_in_the_resolve_slot() -> void:
	_server = auto_free(RoundServer.new())
	add_child(_server)
	var counter := ResolveCounter.new()
	_server.start_round({TickOrder.MATCH_FLOW_BEGIN: counter,
		TickOrder.MATCH_FLOW_RESOLVE: counter.resolve_step()}, Knobs.load_all())
	_server.tick_runner.step()
	_server.tick_runner.step()
	assert_int(counter.resolved).is_equal(2)


## The clock view and resolve step hold the module weakly: dropping the module frees it even while
## the registry and resolve step are still alive (no cycle for end_round() to miss).
func test_view_and_resolve_step_do_not_keep_the_module_alive() -> void:
	var bus := EventBus.new(8)
	var registry := StateRegistry.new()
	var mf := MatchFlow.new()
	mf.setup(null, bus, registry, Knobs.load_all())
	var step := mf.resolve_step()
	var probe: WeakRef = weakref(mf)
	mf = null
	assert_object(probe.get_ref()).is_null()
	step.server_tick(1) # freed module: no crash
	var v := registry.view(StateKeys.ROUND_CLOCK, MatchFlow.ClockView) as MatchFlow.ClockView
	assert_float(v.time_remaining_s()).is_equal(0.0)


class ResolveCounter extends MatchFlow:
	var resolved := 0

	func _on_resolve(_tick: int) -> void:
		resolved += 1


func test_validate_cross_rejects_infiltration_overlapping_evacuation() -> void:
	var k := MatchFlowKnobs.new()
	k.infiltration_end_s = 180.0
	k.round_duration_s = 420.0
	k.evacuation_window_s = 240.0
	var errs := k.validate_cross()
	assert_int(errs.size()).is_equal(1)
	assert_str(errs[0]).contains("infiltration_end_s")


func test_validate_cross_rejects_equality_and_accepts_defaults() -> void:
	var k := MatchFlowKnobs.new()
	k.infiltration_end_s = 180.0
	k.round_duration_s = 420.0
	k.evacuation_window_s = 240.0 # evac_start == 180
	assert_int(k.validate_cross().size()).is_equal(1)
	assert_array(Knobs.load_all().match_flow.validate_cross()).is_empty()


func test_bad_cross_knobs_refuse_to_host() -> void:
	var k := Knobs.load_all()
	k.match_flow.round_duration_s = 420.0
	k.match_flow.evacuation_window_s = 180.0
	k.match_flow.infiltration_end_s = 240.0 # evac_start 240: equality refuses
	var server: RoundServer = auto_free(RoundServer.new())
	assert_array(server.start_round({}, k)).is_not_empty()
	assert_object(server.tick_runner).is_null()


## A drive reported CARRIED has the same state number as the terminal's ARMED; only the terminal's own
## id arms it (SO-1 / MF-1 merge, 2026-10-14).
func test_a_drive_carried_event_does_not_arm_the_terminal() -> void:
	_start()
	_step_to(60.0)
	_arm(SurvivorObjectives.DriveState.CARRIED, SurvivorObjectives.DRIVE_ID)
	_step_to(61.0)
	assert_int(_mf.phase()).is_equal(MatchFlow.Phase.INFILTRATION)
	assert_array(_phases).is_empty()
