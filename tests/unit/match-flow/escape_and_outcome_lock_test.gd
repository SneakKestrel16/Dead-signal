# Story match-flow/003: escape, evidence extraction and outcome lock (design/gdd/match-flow.md rules
# 10, 11, 14, 15, Formulas "Post-escape end time", edge case "Downed survivor crawls into the exit").
# Escape detection runs in MATCH_FLOW_BEGIN from injected positions and the map's exit; events queued
# before step() are delivered after the BEGIN flush, so an escape is detected on the next tick.
extends GdUnitTestSuite

const HZ := 60
const SURVIVORS: Array[int] = [11, 12, 13, 14]
const DEADLINE_S := 540.0
const WINDOW_S := 45.0
## Fixture map: C4's box and exit E as authored in data/maps/research_facility.tres.
const C4_BOX := AABB(Vector3(50.0, 0.0, 12.0), Vector3(10.0, 3.0, 16.0))
const EXIT_AT := Vector3(60.0, 0.0, 20.0)
const EXIT_WIDTH_M := 4.0
const EXIT_ZONE := AABB(Vector3(60.0, 0.0, 18.0), Vector3(2.0, 3.0, 4.0))
const IN_EXIT := Vector3(61.0, 0.0, 20.0)
const IN_ROOM := Vector3(55.0, 0.0, 20.0)

var _server: RoundServer
var _mf: MatchFlow
var _ended: Array[EvRoundEnded]
var _escaped: Array[int]
var _pos: Dictionary[int, Vector3]


func _map() -> MapData:
	var map := MapData.new()
	var v := MapVolume.new()
	v.id = &"C4"
	v.room = &"C4"
	v.box = C4_BOX
	map.volumes.append(v)
	var e := MapPassage.new()
	e.id = &"C4-Outside"
	e.a = &"C4"
	e.b = &"Outside"
	e.kind = MapPassage.EXIT
	e.position = EXIT_AT
	e.width_m = EXIT_WIDTH_M
	map.passages.append(e)
	var z := MapZone.new() ## exit E's authored zone (facility-map story 004)
	z.id = &"Z-E"
	z.kind = MapZone.EXIT
	z.box = EXIT_ZONE
	map.zones.append(z)
	return map


func _position_of(id: int) -> Vector3:
	return _pos.get(id, IN_ROOM)


func _start() -> void:
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_mf = MatchFlow.new()
	_mf.survivor_ids = SURVIVORS
	_mf.set_exit(MapQueries.new(_map()), _position_of)
	_ended = []
	_escaped = []
	_pos = {}
	var errs := _server.start_round({TickOrder.MATCH_FLOW_BEGIN: _mf,
		TickOrder.MATCH_FLOW_RESOLVE: _mf.resolve_step()}, Knobs.load_all())
	assert_array(errs).is_empty()
	_server.bus.subscribe(&"RoundEnded", func(e: ServerEvent) -> void: _ended.append(e as EvRoundEnded))
	_server.bus.subscribe(&"SurvivorEscaped",
		func(e: ServerEvent) -> void: _escaped.append((e as EvSurvivorEscaped).survivor))


func after_test() -> void:
	if _server != null:
		_server.end_round()


func _step_to(seconds: float) -> void:
	var target := roundi(seconds * HZ)
	while _server.tick_runner.current_tick() < target:
		_server.tick_runner.step()


func _tick(events: Array[ServerEvent] = []) -> int:
	for e in events:
		_server.bus.emit(e)
	_server.tick_runner.step()
	return _server.tick_runner.current_tick()


func _elim(id: int) -> EvSurvivorEliminated:
	var e := EvSurvivorEliminated.new()
	e.survivor = id
	return e


func _down(id: int) -> EvSurvivorDowned:
	var e := EvSurvivorDowned.new()
	e.survivor = id
	return e


func _extract(index: int) -> EvObjectiveProgressChanged:
	var e := EvObjectiveProgressChanged.new()
	e.objective = SurvivorObjectives.DRIVE_ID + index
	e.state = SurvivorObjectives.DriveState.EXTRACTED
	return e


func _activated() -> EvObjectiveProgressChanged:
	var e := EvObjectiveProgressChanged.new()
	e.objective = SurvivorObjectives.TERMINAL_ID
	e.state = SurvivorObjectives.TerminalState.ACTIVATED
	return e


func _assert_survivor_win(tick: int) -> void:
	assert_int(_ended.size()).is_equal(1)
	assert_int(_ended[0].outcome).is_equal(MatchFlow.Outcome.SURVIVORS_WIN)
	assert_int(_ended[0].reason).is_equal(MatchFlow.Reason.EVIDENCE_ESCAPED)
	assert_int(_ended[0].tick).is_equal(tick)


# --- the exit volume ----------------------------------------------------------------------------

func test_exit_volume_is_the_opening_past_the_wall() -> void:
	var q := MapQueries.new(_map())
	assert_bool(q.in_exit(IN_EXIT)).is_true()
	assert_bool(q.in_exit(EXIT_AT)).is_true() # the doorway line itself is past C4's east edge
	assert_bool(q.in_exit(Vector3(59.9, 0.0, 20.0))).is_false() # still in C4
	assert_bool(q.in_exit(Vector3(61.0, 0.0, 23.0))).is_false() # beside the opening, outside the wall
	assert_bool(MapQueries.new(MapData.new()).in_exit(IN_EXIT)).is_false() # no exit authored


# --- AC-1: Healthy escape only ------------------------------------------------------------------

func test_healthy_survivor_escapes_and_downed_one_does_not() -> void:
	_start()
	_tick([_down(12), _activated()])
	_pos[11] = IN_EXIT
	_pos[12] = IN_EXIT # crawled in while Downed
	_tick()
	assert_array(_escaped).is_equal([11])
	assert_int(_mf.status_of(11)).is_equal(MatchFlow.Status.ESCAPED)
	assert_int(_mf.status_of(12)).is_equal(MatchFlow.Status.DOWNED)
	_step_to(10.0)
	assert_array(_escaped).is_equal([11]) # emitted once, never for the Downed one


func test_exit_entered_before_activation_is_not_an_escape() -> void:
	_start()
	_pos[11] = IN_EXIT
	_step_to(30.0)
	assert_array(_escaped).is_empty()
	var armed := EvObjectiveProgressChanged.new()
	armed.objective = SurvivorObjectives.TERMINAL_ID
	armed.state = SurvivorObjectives.TerminalState.ARMED
	_tick([armed])
	_tick()
	assert_array(_escaped).is_empty() # armed is not activated
	_tick([_activated()])
	_tick()
	assert_array(_escaped).is_equal([11])


func test_without_an_exit_source_nobody_escapes_by_position() -> void:
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_mf = MatchFlow.new()
	_mf.survivor_ids = SURVIVORS
	_escaped = []
	_server.start_round({TickOrder.MATCH_FLOW_BEGIN: _mf, TickOrder.MATCH_FLOW_RESOLVE: _mf.resolve_step()},
		Knobs.load_all())
	_server.bus.subscribe(&"SurvivorEscaped",
		func(e: ServerEvent) -> void: _escaped.append((e as EvSurvivorEscaped).survivor))
	_tick([_activated()])
	_step_to(5.0)
	assert_array(_escaped).is_empty()


# --- AC-2: win needs both drives ----------------------------------------------------------------

func test_empty_handed_escape_continues_and_one_drive_is_not_a_win() -> void:
	_start()
	_tick([_activated(), _extract(0)])
	_pos[11] = IN_EXIT
	_tick()
	_step_to(60.0)
	assert_int(_mf.status_of(11)).is_equal(MatchFlow.Status.ESCAPED)
	assert_bool(_mf.is_locked()).is_false()
	assert_array(_ended).is_empty()
	_tick([_extract(1)])
	assert_bool(_mf.is_locked()).is_true()


func test_both_drives_on_one_carrier_lock_in_one_tick() -> void:
	_start()
	_tick([_extract(0), _extract(1)])
	assert_bool(_mf.is_locked()).is_true()
	assert_array(_ended).is_empty() # three still inside: the window runs


# --- AC-3: outcome lock and window --------------------------------------------------------------

func test_eliminating_everyone_inside_after_the_lock_keeps_the_survivor_win() -> void:
	_start()
	_tick([_activated(), _extract(0)])
	_pos[11] = IN_EXIT
	_tick()
	_step_to(480.0 - 1.0 / HZ)
	_tick([_extract(1)]) # lock at 480 s
	_step_to(500.0)
	_tick([_elim(12), _elim(13)])
	assert_array(_ended).is_empty()
	var t := _tick([_elim(14)])
	_assert_survivor_win(t) # every survivor Escaped or Eliminated: ends at once, well before 525 s
	assert_int(_mf.status_of(14)).is_equal(MatchFlow.Status.ELIMINATED)


func test_window_ends_the_round_at_525s_and_the_rest_did_not_escape() -> void:
	_start()
	_tick([_activated(), _extract(0), _down(13)])
	_pos[11] = IN_EXIT
	_tick()
	_step_to(480.0 - 1.0 / HZ)
	_tick([_extract(1)])
	_step_to(480.0 + WINDOW_S - 1.0 / HZ)
	assert_array(_ended).is_empty()
	_step_to(480.0 + WINDOW_S)
	_assert_survivor_win(roundi((480.0 + WINDOW_S) * HZ))
	assert_int(_mf.status_of(11)).is_equal(MatchFlow.Status.ESCAPED)
	for id: int in [12, 13, 14]:
		assert_int(_mf.status_of(id)).is_equal(MatchFlow.Status.DID_NOT_ESCAPE)


func test_lock_at_530s_ends_at_the_540s_deadline_as_a_survivor_win() -> void:
	_start()
	_tick([_extract(0)])
	_step_to(530.0 - 1.0 / HZ)
	_tick([_extract(1)])
	_step_to(DEADLINE_S - 1.0 / HZ)
	assert_array(_ended).is_empty()
	_step_to(DEADLINE_S)
	_assert_survivor_win(roundi(DEADLINE_S * HZ))


func test_last_survivor_inside_escaping_after_the_lock_ends_the_round() -> void:
	_start()
	_tick([_activated(), _elim(13), _elim(14)])
	_pos[11] = IN_EXIT
	_tick([_extract(0), _extract(1)])
	assert_array(_ended).is_empty() # 12 still inside
	_pos[12] = IN_EXIT
	var t := _tick()
	_assert_survivor_win(t)
	assert_array(_escaped).is_equal([11, 12])


func test_status_after_a_monster_win_marks_survivors_inside_did_not_escape() -> void:
	_start()
	_step_to(DEADLINE_S)
	assert_int(_ended[0].reason).is_equal(MatchFlow.Reason.DEADLINE)
	assert_int(_mf.status_of(11)).is_equal(MatchFlow.Status.DID_NOT_ESCAPE)


func test_module_with_an_exit_source_frees_when_dropped() -> void:
	var mf := MatchFlow.new()
	mf.survivor_ids = SURVIVORS
	mf.set_exit(MapQueries.new(_map()), _position_of)
	mf.setup(null, EventBus.new(8), StateRegistry.new(), Knobs.load_all())
	var probe: WeakRef = weakref(mf)
	mf = null
	assert_object(probe.get_ref()).is_null()
