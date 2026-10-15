# Story match-flow/006: shapeshifter disconnect and forfeit (design/gdd/match-flow.md rules 14, 16, 20).
# A RoundLifecycle runs on a RoundServer kept out of the tree, so only step() advances it. Network
# Authority's ConnectionRouter is stood in for by emitting PlayerConnectionChanged between steps (the
# router side over real ENet is covered by tests/integration/match-flow/survivor_disconnect_grace_test.gd,
# and the grace timer it checks is the same role-agnostic one).
extends GdUnitTestSuite

const SEED := 6006
const SESSION := "s-6"
const TOKENS: Array[String] = ["t1", "t2", "t3", "t4", "t5"]

var _knobs: Knobs
var _server: RoundServer
var _lc: RoundLifecycle
var _roster: Roster
var _spawns: Dictionary[int, Vector3] = {}
var _body_at: Dictionary[int, Vector3] = {}
var _ended: Array[EvRoundEnded] = []


func before_test() -> void:
	_knobs = Knobs.load_all()
	_server = auto_free(RoundServer.new())
	_spawns = {}
	_body_at = {}
	_ended = []


func after_test() -> void:
	_server.end_round()
	_lc = null


func _info(token: String) -> Dictionary:
	var n := token.trim_prefix("t").to_int()
	return {"player_id": n, "name": "P%d" % n}


func _on_spawn(id: int, pos: Vector3) -> void:
	_spawns[id] = pos


func _on_remove(id: int) -> Vector3:
	return _body_at.get(id, Vector3.ZERO)


func _on_ended(e: ServerEvent) -> void:
	_ended.append(e as EvRoundEnded)


## A five-player round past its loading barrier (Running).
func _start() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_roster = Roster.lock(PackedStringArray(TOKENS), _info, SESSION, 1, _knobs, RotationQueue.new(), rng)
	_lc = RoundLifecycle.new(_roster, MapData.load_map(), rng)
	_lc.spawn = _on_spawn
	_lc.remove = _on_remove
	assert_array(_server.start_round({TickOrder.MATCH_FLOW_BEGIN: _lc,
		TickOrder.MATCH_FLOW_RESOLVE: _lc.resolve_step()}, _knobs)).is_empty()
	_server.bus.subscribe(&"RoundEnded", _on_ended)
	for id in _roster.player_ids():
		_lc.report_loaded(id)
	_step()
	assert_int(_lc.state()).is_equal(RoundLifecycle.State.RUNNING)
	_spawns = {}


func _monster() -> int:
	for id in _roster.player_ids():
		if _roster.entry(id).role == Roster.SHAPESHIFTER:
			return id
	return -1


func _step() -> int:
	_server.tick_runner.step()
	return _server.tick_runner.current_tick()


func _now() -> int:
	return _server.tick_runner.current_tick()


func _tick(events: Array[ServerEvent] = []) -> int:
	for e in events:
		_server.bus.emit(e)
	return _step()


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


func _grace_ticks() -> int:
	return _knobs.ticks(_knobs.match_flow.reconnect_grace_s)


func _step_until(tick: int) -> void:
	while _now() < tick and _ended.is_empty():
		_step()


# --- AC-1: forfeit after grace; reconnect inside grace respawns at the disconnect spot --------------

func test_shapeshifter_away_past_grace_ends_round_as_survivor_win_by_forfeit() -> void:
	_start()
	var m := _monster()
	var dropped_at := _now()
	_tick([_conn(m, EvPlayerConnectionChanged.DISCONNECTED)])
	_step_until(dropped_at + _grace_ticks() - 1)
	assert_array(_ended).is_empty() # in grace the round keeps running
	var t := _step()
	assert_int(t).is_equal(dropped_at + _grace_ticks())
	assert_int(_ended.size()).is_equal(1)
	assert_int(_ended[0].outcome).is_equal(MatchFlow.Outcome.SURVIVORS_WIN)
	assert_int(_ended[0].reason).is_equal(MatchFlow.Reason.FORFEIT)
	assert_str(MatchFlow.REASON_TEXT[_ended[0].reason]).is_equal("Shapeshifter forfeited")
	assert_int(_ended[0].tick).is_equal(t)


func test_shapeshifter_reconnecting_in_grace_respawns_where_it_stood_and_never_forfeits() -> void:
	_start()
	var m := _monster()
	_body_at[m] = Vector3(-3.0, 0.0, 12.5)
	var dropped_at := _now()
	_tick([_conn(m, EvPlayerConnectionChanged.DISCONNECTED)])
	_step_until(dropped_at + _grace_ticks() - 2)
	_tick([_conn(m, EvPlayerConnectionChanged.RECONNECTED)])
	assert_vector(_spawns[m]).is_equal(Vector3(-3.0, 0.0, 12.5))
	_step_until(dropped_at + 2 * _grace_ticks())
	assert_array(_ended).is_empty()


func test_survivor_grace_expiry_is_not_a_forfeit() -> void:
	_start()
	var s := _lc.match_flow().survivor_ids[0]
	var dropped_at := _now()
	_tick([_conn(s, EvPlayerConnectionChanged.DISCONNECTED)])
	_step_until(dropped_at + _grace_ticks() + 1)
	assert_array(_ended).is_empty()


# --- AC-2: the deadline comes before the forfeit -----------------------------------------------------

func test_shapeshifter_drop_at_8_30_ends_at_9_00_by_deadline_not_forfeit() -> void:
	_start()
	var hz := _knobs.net.sim_tick_hz
	var start := _now() - _lc.match_flow().elapsed_s() * hz # tick at which the round clock was 0
	_step_until(int(start) + 510 * hz)
	assert_array(_ended).is_empty()
	_tick([_conn(_monster(), EvPlayerConnectionChanged.DISCONNECTED)])
	_step_until(int(start) + 600 * hz)
	assert_int(_ended.size()).is_equal(1)
	assert_int(_ended[0].outcome).is_equal(MatchFlow.Outcome.SHAPESHIFTER_WINS)
	assert_int(_ended[0].reason).is_equal(MatchFlow.Reason.DEADLINE)
	assert_float(_lc.match_flow().elapsed_s()).is_equal(_knobs.match_flow.round_duration_s)


# --- AC-3: evidence escaping on the grace-expiry tick beats the forfeit ------------------------------

func test_evidence_escaping_on_the_grace_expiry_tick_wins_by_evidence_not_forfeit() -> void:
	_start()
	var dropped_at := _now()
	_tick([_conn(_monster(), EvPlayerConnectionChanged.DISCONNECTED)])
	_step_until(dropped_at + _grace_ticks() - 1)
	assert_array(_ended).is_empty()
	var drives: Array[ServerEvent] = []
	for i in SurvivorObjectives.ACTIVE_DRIVES:
		drives.append(_extract(i))
	var t := _tick(drives)
	assert_int(t).is_equal(dropped_at + _grace_ticks())
	assert_bool(_lc.match_flow().is_locked()).is_true()
	assert_array(_ended).is_empty() # survivors still inside: the lock waits for rule 15, no forfeit
	_step_until(t + _knobs.ticks(_knobs.match_flow.post_escape_window_s) + 1)
	assert_int(_ended.size()).is_equal(1)
	assert_int(_ended[0].outcome).is_equal(MatchFlow.Outcome.SURVIVORS_WIN)
	assert_int(_ended[0].reason).is_equal(MatchFlow.Reason.EVIDENCE_ESCAPED)
