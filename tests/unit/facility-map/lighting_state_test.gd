# Story facility-map/009: per-volume lighting state machine and precedence (research-facility.md
# Lighting States, Edge Cases, Acceptance Criterion 12; ADR-0009 §1-4). Server state only; rendering and
# replication are story 010.
extends GdUnitTestSuite

## Stand-in active points: fuse boxes 0 and 1 in B2 and B3, the terminal (T1) in C4.
const BOX_VOLUMES := {20: &"B2", 21: &"B3", 30: &"C4"}
const ZONE_B_ROOM := &"B1"
const OTHER_ROOM := &"A3"

var _knobs: Knobs
var _server: RoundServer
var _lighting: FacilityLighting
var _view: LightingView


func before_test() -> void:
	_knobs = Knobs.load_all()
	_server = auto_free(RoundServer.new())
	_lighting = FacilityLighting.new(MapData.load_map(), _volume_of)
	assert_array(_server.start_round({TickOrder.FACILITY_LIGHTING: _lighting}, _knobs)).is_empty()
	_view = _server.registry.view(StateKeys.LIGHTING_STATE, LightingView) as LightingView


func after_test() -> void:
	_server.end_round()


func _volume_of(objective: int) -> StringName:
	return BOX_VOLUMES.get(objective, &"")


func _emit(e: ServerEvent) -> void:
	_server.bus.emit(e)
	_server.bus.flush()


func _phase(p: int) -> void:
	var e := EvRoundPhaseChanged.new()
	e.phase = p
	_emit(e)


func _objective(objective: int, state: int) -> void:
	var e := EvObjectiveProgressChanged.new()
	e.objective = objective
	e.state = state
	_emit(e)


func _both_fuses() -> void:
	_objective(SurvivorObjectives.FUSE_BOX_ID, SurvivorObjectives.FuseState.INSTALLED)
	_objective(SurvivorObjectives.FUSE_BOX_ID + 1, SurvivorObjectives.FuseState.INSTALLED)
	_objective(SurvivorObjectives.TERMINAL_ID, SurvivorObjectives.TerminalState.POWERED)


func _blackout(volume: StringName) -> void:
	var e := EvAbilityUsed.new()
	e.ability = MonsterAbilities.Ability.BLACKOUT
	for v in MapData.load_map().volumes:
		if v.id == volume:
			e.target = v.box.get_center()
	_emit(e)


func _steps(n: int) -> void:
	for i in n:
		_server.tick_runner.step()


func _duration() -> int:
	return _knobs.ticks(_knobs.ability.blackout_duration_s)


func test_mirrored_constants_match_the_emitters_enums() -> void:
	assert_int(FacilityLighting.PHASE_EVACUATION).is_equal(MatchFlow.Phase.EVACUATION)
	assert_int(FacilityLighting.ABILITY_BLACKOUT).is_equal(MonsterAbilities.Ability.BLACKOUT)
	assert_int(FacilityLighting.FUSE_BOX_ID).is_equal(SurvivorObjectives.FUSE_BOX_ID)
	assert_int(FacilityLighting.TERMINAL_ID).is_equal(SurvivorObjectives.TERMINAL_ID)
	assert_int(FacilityLighting.FUSE_INSTALLED).is_equal(SurvivorObjectives.FuseState.INSTALLED)
	assert_int(FacilityLighting.TERMINAL_ACTIVATING).is_equal(SurvivorObjectives.TerminalState.ACTIVATING)
	assert_int(FacilityLighting.TERMINAL_ACTIVATED).is_equal(SurvivorObjectives.TerminalState.ACTIVATED)
	assert_int(FacilityLighting.TERMINAL_POWERED).is_equal(SurvivorObjectives.TerminalState.POWERED)


func test_round_start_is_low_power_and_one_view_serves_both_keys() -> void:
	assert_int(_view.get_base()).is_equal(FacilityLighting.Base.LOW_POWER)
	assert_object(_server.registry.view(StateKeys.BLACKOUT_ABLE, LightingView)).is_same(_view)
	assert_bool(_view.is_blackout_able(&"C4")).is_true()
	assert_bool(_view.is_dark(&"C4")).is_false()


## AC1 / edge case "Terminal armed during Infiltration": Power Restored straight to Evacuation; there is
## no Investigation base, so a late Investigation phase event never lowers it.
func test_armed_in_infiltration_goes_power_restored_straight_to_evacuation() -> void:
	_both_fuses()
	assert_int(_view.get_base()).is_equal(FacilityLighting.Base.POWER_RESTORED)
	_phase(MatchFlow.Phase.EVACUATION)
	assert_int(_view.get_base()).is_equal(FacilityLighting.Base.EVACUATION)
	_phase(MatchFlow.Phase.INVESTIGATION)
	_objective(SurvivorObjectives.TERMINAL_ID, SurvivorObjectives.TerminalState.POWERED)
	assert_int(_view.get_base()).is_equal(FacilityLighting.Base.EVACUATION)


## AC2 first half: a Blackout outlives Power Restored landing, then the room shows Power Restored.
func test_blackout_when_power_restored_lands_keeps_dark_for_its_duration() -> void:
	_blackout(ZONE_B_ROOM)
	_both_fuses()
	assert_bool(_view.is_dark(ZONE_B_ROOM)).is_true()
	assert_bool(_view.is_dark(OTHER_ROOM)).is_false()
	_steps(_duration() - 1)
	assert_bool(_view.is_dark(ZONE_B_ROOM)).is_true()
	_steps(1)
	assert_bool(_view.is_dark(ZONE_B_ROOM)).is_false()
	assert_int(_view.get_base()).is_equal(FacilityLighting.Base.POWER_RESTORED)


## AC2 second half: Evacuation ends a Blackout in the active terminal room at once and bars new ones.
func test_evacuation_ends_blackout_in_the_active_terminal_room_at_once() -> void:
	_blackout(&"C4")
	assert_bool(_view.is_dark(&"C4")).is_true()
	_phase(MatchFlow.Phase.EVACUATION)
	assert_bool(_view.is_dark(&"C4")).is_false()
	assert_bool(_view.is_blackout_able(&"C4")).is_false()
	_blackout(&"C4")
	assert_bool(_view.is_dark(&"C4")).is_false()


func test_evacuation_lets_a_blackout_elsewhere_run_out() -> void:
	_blackout(OTHER_ROOM)
	_steps(1)
	_phase(MatchFlow.Phase.EVACUATION)
	assert_bool(_view.is_dark(OTHER_ROOM)).is_true()
	assert_bool(_view.is_blackout_able(OTHER_ROOM)).is_true()
	_steps(_duration() - 2)
	assert_bool(_view.is_dark(OTHER_ROOM)).is_true()
	_steps(1)
	assert_bool(_view.is_dark(OTHER_ROOM)).is_false()


## AC3 (research-facility.md AC 12): both fuses, Evacuation, Blackout in a Zone B room; after it ends
## the room shows Evacuation, not Power Restored. Overlays stay on their own fixtures.
func test_precedence_blackout_ends_into_evacuation() -> void:
	_both_fuses()
	_phase(MatchFlow.Phase.EVACUATION)
	_blackout(ZONE_B_ROOM)
	assert_bool(_view.is_dark(ZONE_B_ROOM)).is_true()
	assert_int(_view.get_overlays(&"B2")).is_equal(FacilityLighting.OVERLAY_FUSE_INSTALLED)
	assert_int(_view.get_overlays(ZONE_B_ROOM)).is_equal(0)
	_steps(_duration())
	assert_bool(_view.is_dark(ZONE_B_ROOM)).is_false()
	assert_int(_view.get_base()).is_equal(FacilityLighting.Base.EVACUATION)


func test_terminal_activation_and_exit_overlays() -> void:
	_objective(SurvivorObjectives.TERMINAL_ID, SurvivorObjectives.TerminalState.ACTIVATING)
	assert_int(_view.get_overlays(&"C4")).is_equal(FacilityLighting.OVERLAY_TERMINAL_ACTIVATING)
	_objective(SurvivorObjectives.TERMINAL_ID, SurvivorObjectives.TerminalState.ACTIVATED)
	assert_int(_view.get_overlays(&"C4")).is_equal(
		FacilityLighting.OVERLAY_TERMINAL_ACTIVATING | FacilityLighting.OVERLAY_EXIT_OPEN)


## AC4: after RoundEnded every volume is Low Power with no overlays, no Blackout, blackout_able restored.
func test_round_ended_resets_every_volume() -> void:
	_both_fuses()
	_objective(SurvivorObjectives.TERMINAL_ID, SurvivorObjectives.TerminalState.ACTIVATING)
	_blackout(ZONE_B_ROOM)
	_phase(MatchFlow.Phase.EVACUATION)
	_emit(EvRoundEnded.new())
	assert_int(_view.get_base()).is_equal(FacilityLighting.Base.LOW_POWER)
	for v in MapData.load_map().volumes:
		assert_int(_view.get_overlays(v.id)).override_failure_message(v.id).is_equal(0)
		assert_bool(_view.is_dark(v.id)).override_failure_message(v.id).is_false()
		assert_bool(_view.is_blackout_able(v.id)).override_failure_message(v.id).is_true()
