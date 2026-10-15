# Story match-flow/002: win evaluation order and immediate endings (design/gdd/match-flow.md rules
# 8-18, Edge Cases). Events are queued, then one step() delivers them inside that tick (after the
# MATCH_FLOW_BEGIN flush), so the RESOLVE check sees them on the same tick.
extends GdUnitTestSuite

const HZ := 60
const SURVIVORS: Array[int] = [11, 12, 13, 14]
const SHAPESHIFTER := 15
const DEADLINE_S := 540.0

var _server: RoundServer
var _mf: MatchFlow
var _ended: Array[EvRoundEnded]


func _start(mf: MatchFlow = MatchFlow.new()) -> void:
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_mf = mf
	_mf.survivor_ids = SURVIVORS
	_ended = []
	var errs := _server.start_round({TickOrder.MATCH_FLOW_BEGIN: _mf,
		TickOrder.MATCH_FLOW_RESOLVE: _mf.resolve_step()}, Knobs.load_all())
	assert_array(errs).is_empty()
	_server.bus.subscribe(&"RoundEnded", func(e: ServerEvent) -> void: _ended.append(e as EvRoundEnded))


func after_test() -> void:
	if _server != null:
		_server.end_round()


func _step_to(seconds: float) -> void:
	var target := roundi(seconds * HZ)
	while _server.tick_runner.current_tick() < target:
		_server.tick_runner.step()


## Runs one tick with `events` delivered inside it; returns that tick.
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


func _escape(id: int) -> EvSurvivorEscaped:
	var e := EvSurvivorEscaped.new()
	e.survivor = id
	return e


func _conn(id: int, status: int) -> EvPlayerConnectionChanged:
	var e := EvPlayerConnectionChanged.new()
	e.player = id
	e.status = status
	return e


func _extract(index: int) -> EvObjectiveProgressChanged:
	var e := EvObjectiveProgressChanged.new()
	e.objective = SurvivorObjectives.DRIVE_ID + index
	e.state = SurvivorObjectives.DriveState.EXTRACTED
	return e


func _assert_one_end(outcome: int, reason: int, tick: int) -> void:
	assert_int(_ended.size()).is_equal(1)
	assert_int(_ended[0].outcome).is_equal(outcome)
	assert_int(_ended[0].reason).is_equal(reason)
	assert_int(_ended[0].tick).is_equal(tick)


func _assert_monster(reason: int, tick: int) -> void:
	_assert_one_end(MatchFlow.Outcome.SHAPESHIFTER_WINS, reason, tick)


func _assert_survivors(reason: int, tick: int) -> void:
	_assert_one_end(MatchFlow.Outcome.SURVIVORS_WIN, reason, tick)


# --- AC-1: all eliminated -----------------------------------------------------------------------

func test_all_eliminated_ends_on_the_tick_of_the_last_one_bleed_out_included() -> void:
	_start()
	_step_to(100.0)
	_tick([_elim(11)])
	_tick([_elim(12)])
	_tick([_down(13)]) # 13 is downed and later bleeds out (Downing emits Eliminated)
	_tick([_elim(14)])
	assert_array(_ended).is_empty() # only a Downed survivor left: the round waits
	_step_to(130.0)
	assert_array(_ended).is_empty()
	var t := _tick([_elim(13)])
	_assert_monster(MatchFlow.Reason.ALL_ELIMINATED, t)


func test_all_downed_waits_then_ends_when_the_second_bleeds_out() -> void:
	_start()
	_step_to(50.0)
	_tick([_elim(11), _elim(12)])
	_tick([_down(13), _down(14)]) # rescuer downed while rescuing the only other survivor
	_step_to(80.0)
	_tick([_elim(13)])
	assert_array(_ended).is_empty()
	var t := _tick([_elim(14)])
	_assert_monster(MatchFlow.Reason.ALL_ELIMINATED, t)


func test_last_elimination_on_the_deadline_tick_reads_all_eliminated() -> void:
	_start()
	_tick([_elim(11), _elim(12), _elim(13)])
	_step_to(DEADLINE_S - 1.0 / HZ)
	var t := _tick([_elim(14)]) # also covers: a bleed-out on the deadline tick, monster wins either way
	assert_float(_mf.time_remaining_s()).is_equal(0.0)
	_assert_monster(MatchFlow.Reason.ALL_ELIMINATED, t)


func test_rescued_survivor_counts_inside_again() -> void:
	_start()
	_tick([_down(11)])
	var r := EvSurvivorRescued.new()
	r.survivor = 11
	r.rescuer = 12
	_tick([r])
	assert_int(_mf.status_of(11)).is_equal(MatchFlow.Status.HEALTHY)


# --- AC-2: evidence lost ------------------------------------------------------------------------

func test_one_drive_out_and_last_inside_eliminated_is_evidence_lost() -> void:
	_start()
	_tick([_extract(0), _escape(11)])
	_tick([_elim(12), _elim(13)])
	assert_array(_ended).is_empty()
	var t := _tick([_elim(14)]) # eliminated holding the other drive
	_assert_monster(MatchFlow.Reason.EVIDENCE_LOST, t)


func test_survivor_in_reconnect_grace_keeps_the_round_running() -> void:
	_start()
	_tick([_extract(0), _escape(11), _elim(12)])
	_tick([_conn(13, EvPlayerConnectionChanged.DISCONNECTED)])
	_tick([_elim(14)])
	assert_array(_ended).is_empty() # 13 counts as inside while in grace
	_step_to(60.0)
	assert_array(_ended).is_empty()
	var t := _tick([_conn(13, EvPlayerConnectionChanged.GRACE_EXPIRED)])
	_assert_monster(MatchFlow.Reason.EVIDENCE_LOST, t)


func test_reconnect_inside_grace_changes_nothing() -> void:
	_start()
	_tick([_conn(13, EvPlayerConnectionChanged.DISCONNECTED)])
	_tick([_conn(13, EvPlayerConnectionChanged.RECONNECTED)])
	assert_int(_mf.status_of(13)).is_equal(MatchFlow.Status.HEALTHY)
	assert_array(_ended).is_empty()


func test_only_downed_inside_is_not_evidence_lost() -> void:
	_start()
	_tick([_extract(0), _escape(11), _elim(12), _elim(13)])
	_tick([_down(14)])
	_step_to(30.0)
	assert_array(_ended).is_empty()
	var t := _tick([_elim(14)]) # bled out: one escaped, so not "all eliminated"
	_assert_monster(MatchFlow.Reason.EVIDENCE_LOST, t)


func test_all_downed_with_none_escaped_ends_all_eliminated_not_evidence_lost() -> void:
	_start()
	_tick([_down(11), _down(12), _down(13), _down(14)])
	_step_to(30.0)
	assert_array(_ended).is_empty()
	_tick([_elim(11), _elim(12), _elim(13)])
	var t := _tick([_elim(14)])
	_assert_monster(MatchFlow.Reason.ALL_ELIMINATED, t)


func test_downed_survivor_bleeding_out_in_grace_is_eliminated() -> void:
	_start()
	_tick([_elim(11), _elim(12), _elim(13), _down(14)])
	_tick([_conn(14, EvPlayerConnectionChanged.DISCONNECTED)])
	assert_array(_ended).is_empty()
	var t := _tick([_elim(14)])
	_assert_monster(MatchFlow.Reason.ALL_ELIMINATED, t)


func test_escape_without_drives_does_not_end_the_round() -> void:
	_start()
	_tick([_escape(11)])
	_step_to(30.0)
	assert_array(_ended).is_empty()
	assert_int(_mf.status_of(11)).is_equal(MatchFlow.Status.ESCAPED)


func test_all_survivors_in_grace_continue_until_the_last_grace_expires() -> void:
	_start()
	var dc: Array[ServerEvent] = []
	for id in SURVIVORS:
		dc.append(_conn(id, EvPlayerConnectionChanged.DISCONNECTED))
	_tick(dc)
	_step_to(30.0)
	_tick([_conn(11, EvPlayerConnectionChanged.GRACE_EXPIRED), _conn(12, EvPlayerConnectionChanged.GRACE_EXPIRED),
		_conn(13, EvPlayerConnectionChanged.GRACE_EXPIRED)])
	assert_array(_ended).is_empty()
	var t := _tick([_conn(14, EvPlayerConnectionChanged.GRACE_EXPIRED)])
	_assert_monster(MatchFlow.Reason.ALL_ELIMINATED, t)
	assert_int(_mf.status_of(14)).is_equal(MatchFlow.Status.DISCONNECTED)


func test_events_for_players_not_on_the_roster_are_ignored() -> void:
	_start()
	_tick([_elim(99), _conn(SHAPESHIFTER, EvPlayerConnectionChanged.GRACE_EXPIRED)])
	_step_to(30.0)
	assert_array(_ended).is_empty()


# --- AC-3: deadline -----------------------------------------------------------------------------

func test_deadline_at_540s_with_nothing_done_and_activation_from_530s_not_finished() -> void:
	_start()
	_step_to(530.0)
	var act := EvObjectiveProgressChanged.new()
	act.objective = SurvivorObjectives.TERMINAL_ID
	act.state = SurvivorObjectives.TerminalState.ACTIVATING # 15 s hold: would finish at 545
	_tick([act])
	_step_to(DEADLINE_S - 1.0 / HZ)
	assert_array(_ended).is_empty()
	_step_to(DEADLINE_S)
	_assert_monster(MatchFlow.Reason.DEADLINE, roundi(DEADLINE_S * HZ))
	assert_str(MatchFlow.OUTCOME_TEXT[_ended[0].outcome] + " — " + MatchFlow.REASON_TEXT[_ended[0].reason]) \
		.is_equal("Shapeshifter Wins — Evacuation deadline expired")


func test_deadline_tick_with_pending_non_ending_events_is_still_deadline() -> void:
	_start()
	_step_to(DEADLINE_S - 1.0 / HZ)
	var t := _tick([_down(11), _elim(12), _extract(0), _escape(13)])
	_assert_monster(MatchFlow.Reason.DEADLINE, t)


func test_deadline_while_the_shapeshifter_is_in_grace_is_a_monster_win() -> void:
	_start()
	_step_to(500.0)
	_tick([_conn(SHAPESHIFTER, EvPlayerConnectionChanged.DISCONNECTED)])
	_step_to(DEADLINE_S)
	_assert_monster(MatchFlow.Reason.DEADLINE, roundi(DEADLINE_S * HZ))


# --- AC-4: same-tick order ----------------------------------------------------------------------

func test_second_drive_and_last_elimination_same_tick_is_a_survivor_win() -> void:
	_start()
	_tick([_extract(0), _elim(11), _elim(12), _elim(13)])
	var t := _tick([_elim(14), _extract(1)])
	_assert_survivors(MatchFlow.Reason.EVIDENCE_ESCAPED, t)


func test_second_drive_on_the_deadline_tick_is_a_survivor_win() -> void:
	_start()
	_tick([_extract(0)])
	_step_to(DEADLINE_S - 1.0 / HZ)
	var t := _tick([_extract(1)])
	_assert_survivors(MatchFlow.Reason.EVIDENCE_ESCAPED, t)


func test_forfeit_alone_is_a_survivor_win_by_forfeit() -> void:
	var mf := ForfeitingMatchFlow.new()
	_start(mf)
	_tick()
	assert_array(_ended).is_empty()
	mf.forfeit = true
	var t := _tick()
	_assert_survivors(MatchFlow.Reason.FORFEIT, t)


func test_earned_result_beats_forfeit_in_the_same_tick() -> void:
	var mf := ForfeitingMatchFlow.new()
	_start(mf)
	_tick([_elim(11), _elim(12), _elim(13)])
	mf.forfeit = true
	var t := _tick([_elim(14)])
	_assert_monster(MatchFlow.Reason.ALL_ELIMINATED, t)


func test_evidence_escaped_beats_a_same_tick_forfeit() -> void:
	var mf := ForfeitingMatchFlow.new()
	_start(mf)
	_tick([_extract(0)])
	mf.forfeit = true
	var t := _tick([_extract(1)])
	_assert_survivors(MatchFlow.Reason.EVIDENCE_ESCAPED, t)


# --- outcome lock -------------------------------------------------------------------------------

func test_outcome_is_emitted_once_and_never_flips() -> void:
	_start()
	_tick([_extract(0)])
	var t := _tick([_extract(1)])
	_tick([_elim(11), _elim(12), _elim(13), _elim(14)])
	_step_to(DEADLINE_S + 1.0)
	_assert_survivors(MatchFlow.Reason.EVIDENCE_ESCAPED, t)
	assert_bool(_mf.is_ended()).is_true()


func test_one_drive_extracted_twice_is_not_both_drives() -> void:
	_start()
	_tick([_extract(0)])
	_tick([_extract(0)])
	var carried := EvObjectiveProgressChanged.new()
	carried.objective = SurvivorObjectives.DRIVE_ID + 1
	carried.state = SurvivorObjectives.DriveState.CARRIED
	_tick([carried])
	assert_array(_ended).is_empty()


func test_reason_text_matches_rule_23() -> void:
	assert_array(MatchFlow.REASON_TEXT).is_equal(["Evidence escaped", "All survivors eliminated",
		"Evidence lost", "Evacuation deadline expired", "Shapeshifter forfeited"])
	assert_array(MatchFlow.OUTCOME_TEXT).is_equal(["Survivors Win", "Shapeshifter Wins"])


## The new subscriptions still let the module free (house rule: no RefCounted cycle).
func test_module_with_survivors_frees_when_dropped() -> void:
	var bus := EventBus.new(8)
	var mf := MatchFlow.new()
	mf.survivor_ids = SURVIVORS
	mf.setup(null, bus, StateRegistry.new(), Knobs.load_all())
	var probe: WeakRef = weakref(mf)
	mf = null
	assert_object(probe.get_ref()).is_null()


class ForfeitingMatchFlow extends MatchFlow:
	var forfeit := false

	func _forfeit_due() -> bool:
		return forfeit
