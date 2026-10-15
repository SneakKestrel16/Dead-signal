# Story monster-abilities/010: Blackout (design/gdd/monster-abilities.md rules 17-21, Acceptance
# Criteria "Multi-client" Blackout line; ADR-0009 §2-4, ADR-0008). Real MonsterAbilities, FacilityLighting
# and HoldService on the shipped map; no physics: stub centre, aim and sight. Replication to the 5 clients
# is facility-map story 010; here the server state every client mirrors is checked.
extends GdUnitTestSuite

const MONSTER := 1
const S1 := 2
const S2 := 3
## A3 is the monster's room; A4's centre is 12.5 m away, A5's 16 m (blackout_range_m is 15).
const OWN := &"A3"
const NEAR := &"A4"
const FAR := &"A5"

var _knobs: Knobs
var _server: RoundServer
var _map: MapData
var _queries: MapQueries
var _ma: MonsterAbilities
var _lighting: FacilityLighting
var _view: LightingView
var _holds: HoldService
var _switches: Dictionary[StringName, BackupSwitch] = {}
var _clear := true
var _form := BorrowedFace.TRUE_FORM
var _terminal := &""
var _frame := InputFrame.new()
var _holder := S1
var _centre := Vector3.ZERO
var _form_changes := 0


## The Holds step (ControllerAuthority's job, minus movement): runs HoldService at TickOrder.HOLDS.
class HoldsStep extends RefCounted:
	var _holds: HoldService

	func _init(holds: HoldService) -> void:
		_holds = holds

	func setup(_tr: TickRunner, _bus: EventBus, _reg: StateRegistry, _k: Knobs) -> void:
		pass

	func server_tick(tick: int) -> void:
		_holds.server_tick(tick)


func before_test() -> void:
	_knobs = Knobs.load_all()
	_map = MapData.load_map()
	_queries = MapQueries.new(_map)
	_clear = true
	_form = BorrowedFace.TRUE_FORM
	_terminal = &""
	_frame = InputFrame.new()
	_holder = S1
	_form_changes = 0
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_ma = MonsterAbilities.new()
	_ma.set_monster(MONSTER)
	_ma.set_status_sources(_form_of, Callable())
	_ma.set_position_source(_position_of)
	_ma.set_blackout_sources(_queries.volume_at, _sight)
	_lighting = FacilityLighting.new(_map, _objective_volume)
	_holds = HoldService.new(_knobs, _players, _frames, _centre_of, _sight_item, _aim, Callable(), _is_monster)
	assert_array(_server.start_round({TickOrder.MONSTER_ABILITIES: _ma, TickOrder.FACILITY_LIGHTING: _lighting,
		TickOrder.HOLDS: HoldsStep.new(_holds)}, _knobs)).is_empty()
	_view = _server.registry.view(StateKeys.BLACKOUT_ABLE, LightingView) as LightingView
	_server.bus.subscribe(&"FormChanged", _on_form_changed)
	_switches = {}
	var ids := BackupSwitch.register_all(_holds, _map, _lighting, _knobs, _is_survivor)
	assert_int(ids.size()).is_greater(0)
	# Stand-in registrations to read the switches back: register_all keeps none itself.
	for s: Resource in _map.interactables():
		var m := s as MapMarker
		if m != null and m.type == &"switch":
			var b := BackupSwitch.new()
			b.volume = m.volume
			b.net_id = ids[_switches.size()]
			b.point = m.position + Vector3.UP * MapQueries.InteractRules.from_knobs(_knobs).point_height_m
			_switches[m.volume] = b


func after_test() -> void:
	_server.end_round()


func _on_form_changed(_e: ServerEvent) -> void:
	_form_changes += 1


func _form_of() -> int:
	return _form


func _position_of(_p: int) -> Vector3:
	return _centre_of_volume(OWN)


func _sight(_p: int, _aim_point: Vector3) -> bool:
	return _clear


func _objective_volume(objective: int) -> StringName:
	return _terminal if objective == SurvivorObjectives.TERMINAL_ID else &""


func _is_survivor(actor: int) -> bool:
	return actor != MONSTER


func _is_monster(actor: int) -> bool:
	return actor == MONSTER


func _players() -> Array[int]:
	return [MONSTER, S1, S2]


func _frames(actor: int) -> Array:
	return [_frame] if actor == _holder else []


func _centre_of(_actor: int) -> Vector3:
	return _centre


func _sight_item(_actor: int, _i: Interactable) -> bool:
	return true


func _aim(_actor: int) -> int:
	return _frame.interact_target


func _centre_of_volume(id: StringName) -> Vector3:
	for v in _map.volumes:
		if v.id == id:
			return v.box.get_center()
	return Vector3.INF


func _now() -> int:
	return _server.tick_runner.current_tick()


func _step(n: int = 1) -> void:
	for i in n:
		_server.tick_runner.step()


func _duration() -> int:
	return _knobs.ticks(_knobs.ability.blackout_duration_s)


func _hold_ticks() -> int:
	return _knobs.ticks(_knobs.ability.backup_switch_hold_s)


## Requests Blackout at `point` and steps one tick; true when accepted.
func _request(point: Vector3) -> bool:
	var before := _ma.blackouts_used()
	_ma.request_ability(MONSTER, MonsterAbilities.request_packet(MonsterAbilities.Ability.BLACKOUT, point))
	_step()
	return _ma.blackouts_used() == before + 1


func _blackout(zone: StringName) -> bool:
	return _request(_centre_of_volume(zone))


## Darkens `zone` as an earlier Blackout would (FacilityLighting's own input), bypassing the cooldown.
func _dark_already(zone: StringName) -> void:
	var e := EvAbilityUsed.new()
	e.ability = MonsterAbilities.Ability.BLACKOUT
	e.target = _centre_of_volume(zone)
	_server.bus.emit(e)
	_server.bus.flush()


## `_holder` holds `zone`'s switch for `ticks` ticks, then releases it.
func _hold_switch(zone: StringName, ticks: int) -> void:
	var s: BackupSwitch = _switches[zone]
	_centre = s.point
	_frame = InputFrame.new()
	_frame.interact = true
	_frame.interact_target = s.net_id
	_step(ticks)
	_frame = InputFrame.new()
	_frame.interact_target = s.net_id
	_step()


# AC-1 ------------------------------------------------------------------------------------------

func test_rejected_targets_cost_no_cooldown() -> void:
	_terminal = NEAR
	var e := EvRoundPhaseChanged.new()
	e.phase = MatchFlow.Phase.EVACUATION
	_server.bus.emit(e)
	_server.bus.flush()
	assert_bool(_view.is_blackout_able(NEAR)).is_false()
	assert_bool(_blackout(NEAR)).override_failure_message("not blackout_able").is_false()
	_dark_already(OWN)
	assert_bool(_blackout(OWN)).override_failure_message("already dark").is_false()
	assert_bool(_blackout(FAR)).override_failure_message("beyond range").is_false()
	assert_bool(_view.is_dark(FAR)).is_false()
	assert_bool(_request(Vector3(-100, 1, -100))).override_failure_message("no zone").is_false()
	assert_int(_ma.ready_tick(MonsterAbilities.Ability.BLACKOUT)).is_equal(0)
	assert_int(_ma.blackouts_used()).is_equal(0)


func test_line_of_sight_needed_except_in_own_zone() -> void:
	_clear = false
	assert_bool(_blackout(NEAR)).override_failure_message("no sight").is_false()
	assert_bool(_blackout(OWN)).override_failure_message("own zone needs no sight").is_true()
	assert_bool(_view.is_dark(OWN)).is_true()


func test_in_range_with_sight_accepted_and_cooldown_runs_from_activation() -> void:
	assert_bool(_blackout(NEAR)).is_true()
	var used := _now()
	assert_bool(_view.is_dark(NEAR)).is_true()
	assert_bool(_view.is_dark(OWN)).is_false() # one zone per Blackout
	var ready := used + _knobs.ticks(_knobs.ability.blackout_cooldown_s)
	assert_int(_ma.ready_tick(MonsterAbilities.Ability.BLACKOUT)).is_equal(ready)
	_step(ready - 2 - _now())
	assert_bool(_blackout(OWN)).override_failure_message("one tick early").is_false()
	assert_int(_now()).is_equal(ready - 1)
	assert_bool(_blackout(OWN)).override_failure_message("on the ready tick").is_true()
	assert_int(_ma.blackouts_used()).is_equal(2)
	var stats := _server.registry.view(StateKeys.STATS_ABILITIES, AbilitiesStatsView) as AbilitiesStatsView
	assert_int(stats.get_blackouts_used()).is_equal(2) ## story 008: the results view reads it


# AC-2 ------------------------------------------------------------------------------------------

func test_zone_stays_dark_for_the_duration() -> void:
	assert_bool(_blackout(NEAR)).is_true()
	var end := _now() + _duration()
	while _now() + 1 < end:
		_step()
		assert_bool(_view.is_dark(NEAR)).override_failure_message("tick %d" % _now()).is_true()
	_step()
	assert_bool(_view.is_dark(NEAR)).is_false()


# AC-3 ------------------------------------------------------------------------------------------

func test_backup_switch_held_full_time_restores_its_own_zone_only() -> void:
	assert_bool(_blackout(OWN)).is_true()
	_dark_already(NEAR)
	var ready := _ma.ready_tick(MonsterAbilities.Ability.BLACKOUT)
	_hold_switch(OWN, _hold_ticks())
	assert_bool(_view.is_dark(OWN)).is_false()
	assert_bool(_view.is_dark(NEAR)).is_true()
	assert_int(_ma.ready_tick(MonsterAbilities.Ability.BLACKOUT)).is_equal(ready) # no cooldown refund


func test_backup_switch_released_early_does_nothing() -> void:
	assert_bool(_blackout(OWN)).is_true()
	_hold_switch(OWN, _hold_ticks() - 1)
	assert_bool(_view.is_dark(OWN)).is_true()


func test_shapeshifter_cannot_hold_a_backup_switch() -> void:
	assert_bool(_blackout(OWN)).is_true()
	_holder = MONSTER
	_hold_switch(OWN, _hold_ticks() + 1)
	assert_bool(_view.is_dark(OWN)).is_true()


# AC-4 ------------------------------------------------------------------------------------------

func test_blackout_while_disguised_accepted_and_disguise_kept() -> void:
	_form = S1
	assert_bool(_blackout(NEAR)).is_true()
	assert_bool(_view.is_dark(NEAR)).is_true()
	assert_int(_form_changes).is_equal(0)
