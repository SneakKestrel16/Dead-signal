# Story match-flow/008: results payload (design/gdd/match-flow.md rules 23-26; ADR-0011). MatchFlow reads
# every owner's *StatsView once on the outcome tick into a RoundResults that rides on RoundEnded.
extends GdUnitTestSuite

const HZ := 60
const SURVIVORS: Array[int] = [11, 12, 13, 14]
const SHAPESHIFTER := 15
const OWNER_KEYS: Array[StringName] = [StateKeys.STATS_DOWNING, StateKeys.STATS_ABILITIES,
	StateKeys.STATS_DEFENSE, StateKeys.STATS_BORROWED_FACE, StateKeys.STATS_OBJECTIVES]
## Payload budget: one reliable fragmented send per peer (ADR-0011 verification 1).
const MAX_BYTES := 4096


## Fake Downing view: 12 took 2 downs, 13 rescued once; counts how often it is read.
class FakeDowning extends DowningStatsView:
	var _reads: int = 0

	func get_downs_taken(player_id: int) -> int:
		return 2 if player_id == 12 else 0

	func get_rescues_performed(player_id: int) -> int:
		return 1 if player_id == 13 else 0

	func get_fate_cause(player_id: int) -> StringName:
		return &"bled_out" if player_id == 12 else &""

	func get_takedowns() -> int:
		_reads += 1
		return 3

	func get_eliminations() -> int:
		return 4


class FakeAbilities extends AbilitiesStatsView:
	func get_lunges_landed() -> int:
		return 5

	func get_false_signals_used() -> int:
		return 6


## Fake Objectives view: one drive recovered at tick 30 after the round start.
class FakeObjectives extends ObjectivesStatsView:
	var _at: int

	func _init(at: int) -> void:
		_at = at

	func get_line_count(line: StringName) -> int:
		return 1 if line == &"drives_recovered" else 0

	func get_line_completed_tick(line: StringName) -> int:
		return _at if line == &"drives_recovered" else -1


var _server: RoundServer
var _mf: MatchFlow
var _ended: Array[EvRoundEnded]


func _start() -> void:
	_server = auto_free(RoundServer.new())
	add_child(_server)
	_mf = MatchFlow.new()
	_mf.survivor_ids = SURVIVORS
	_mf.shapeshifter_id = SHAPESHIFTER
	_ended = []
	var errs := _server.start_round({TickOrder.MATCH_FLOW_BEGIN: _mf,
		TickOrder.MATCH_FLOW_RESOLVE: _mf.resolve_step()}, Knobs.load_all())
	assert_array(errs).is_empty()
	_server.bus.subscribe(&"RoundEnded", _on_ended)


func _on_ended(e: ServerEvent) -> void:
	_ended.append(e as EvRoundEnded)


func after_test() -> void:
	if _server != null:
		_server.end_round()


## Eliminates every survivor in one tick: the round ends on it (rule 16).
func _end_all_eliminated() -> int:
	for id in SURVIVORS:
		var e := EvSurvivorEliminated.new()
		e.survivor = id
		_server.bus.emit(e)
	_server.tick_runner.step()
	return _server.tick_runner.current_tick()


func test_missing_owner_views_read_as_zero_and_are_named() -> void:
	_start()
	for i in 9:
		_server.tick_runner.step()
	var end_tick := _end_all_eliminated()
	assert_int(_ended.size()).is_equal(1)
	var r: Dictionary = _ended[0].results
	assert_int(r["outcome"]).is_equal(MatchFlow.Outcome.SHAPESHIFTER_WINS)
	assert_int(r["reason"]).is_equal(MatchFlow.Reason.ALL_ELIMINATED)
	assert_float(r["duration_s"]).is_equal_approx(float(end_tick) / HZ, 1e-6)
	assert_int(r["shapeshifter_player_id"]).is_equal(SHAPESHIFTER)
	var missing: Array = r["missing"]
	for k in OWNER_KEYS:
		assert_bool(missing.has(k)).override_failure_message("missing %s" % k).is_true()
	assert_bool(missing.has(StateKeys.STATS_MATCH)).is_false()
	var ids: Array = []
	for s: Dictionary in r["survivors"]:
		ids.append(s["player_id"])
		assert_int(s["fate"]).is_equal(MatchFlow.Status.ELIMINATED)
		assert_int(s["downs"]).is_equal(0)
		assert_int(s["stuns_landed"]).is_equal(0)
	assert_array(ids).contains_exactly(SURVIVORS)
	for v: int in (r["monster"] as Dictionary).values():
		assert_int(v).is_equal(0)
	assert_int((r["objectives"] as Array).size()).is_equal(RoundResults.LINES.size())
	for o: Dictionary in r["objectives"]:
		assert_int(o["count"]).is_equal(0)
		assert_float(o["completed_s"]).is_equal(-1.0)
	assert_array(_server.registry.violations).is_empty()


func test_owner_views_flow_into_payload_read_once_on_outcome_tick() -> void:
	_start()
	var downing := FakeDowning.new()
	_server.registry.register_view(StateKeys.STATS_DOWNING, &"Downing", downing)
	_server.registry.register_view(StateKeys.STATS_ABILITIES, &"MonsterAbilities", FakeAbilities.new())
	# Round starts at tick 0 (first BEGIN tick is 1): completion at tick 90 is 1.5 s into the round.
	_server.registry.register_view(StateKeys.STATS_OBJECTIVES, &"SurvivorObjectives", FakeObjectives.new(90))
	_server.tick_runner.step()
	assert_int(downing._reads).is_equal(0)
	_end_all_eliminated()
	for i in 5:
		_server.tick_runner.step()
	assert_int(downing._reads).is_equal(1)
	var r: Dictionary = _ended[0].results
	var by_id := {}
	for s: Dictionary in r["survivors"]:
		by_id[s["player_id"]] = s
	assert_int(by_id[12]["downs"]).is_equal(2)
	assert_str(by_id[12]["cause"]).is_equal("bled_out")
	assert_int(by_id[13]["rescues"]).is_equal(1)
	var m: Dictionary = r["monster"]
	assert_int(m[&"takedowns"]).is_equal(3)
	assert_int(m[&"eliminations"]).is_equal(4)
	assert_int(m[&"lunges_landed"]).is_equal(5)
	assert_int(m[&"false_signals"]).is_equal(6)
	assert_int(m[&"lunges_missed"]).is_equal(0)
	var rec: Dictionary = (r["objectives"] as Array)[0]
	assert_str(rec["line"]).is_equal("drives_recovered")
	assert_int(rec["count"]).is_equal(1)
	assert_int(rec["of"]).is_equal(SurvivorObjectives.ACTIVE_DRIVES)
	assert_float(rec["completed_s"]).is_equal_approx(1.5, 1e-6)
	var missing: Array = r["missing"]
	assert_bool(missing.has(StateKeys.STATS_DOWNING)).is_false()
	assert_bool(missing.has(StateKeys.STATS_DEFENSE)).is_true()


func test_every_peer_gets_the_same_payload() -> void:
	_start()
	_end_all_eliminated()
	var a := _ended[0].project(1, null, SHAPESHIFTER)
	var b := _ended[0].project(SHAPESHIFTER, null, SHAPESHIFTER)
	assert_bool(var_to_bytes(a) == var_to_bytes(b)).is_true()
	assert_dict(a["results"]).is_equal(_ended[0].results)


## Largest payload: 5 survivors + shapeshifter, longest names in 3-byte UTF-8, every counter maxed.
func test_largest_payload_fits_budget_and_holds_no_typed_containers() -> void:
	var r := RoundResults.new()
	var long_name := "あ".repeat(16)
	r.outcome = MatchFlow.Outcome.SURVIVORS_WIN
	r.reason = MatchFlow.Reason.EVIDENCE_ESCAPED
	r.duration_s = 540.0
	r.shapeshifter_player_id = 2147483647
	r.shapeshifter_name = long_name
	for i in 5:
		r.survivors.append({"player_id": 2147483600 + i, "name": long_name, "fate": MatchFlow.Status.ESCAPED,
			"cause": "bled_out", "drives_carried": 2, "downs": 2147483647, "rescues": 2147483647,
			"stuns_landed": 2147483647})
	for line in RoundResults.LINES:
		r.objectives.append({"line": String(line), "count": 2, "of": 2, "completed_s": 539.98})
	for k in RoundResults.MONSTER_STATS:
		r.monster[k] = 2147483647
	r.missing.assign(OWNER_KEYS)
	r.missing.append(StateKeys.PLAYER_ROSTER)
	var d := r.to_dict()
	var size := var_to_bytes(d).size()
	assert_int(size).override_failure_message("payload %d bytes" % size).is_less(MAX_BYTES)
	assert_array(_typed_containers(d, "results")).is_empty()


## Paths of every typed Array or Dictionary in `v`, recursively.
func _typed_containers(v: Variant, path: String) -> Array[String]:
	var out: Array[String] = []
	if v is Array:
		if (v as Array).is_typed():
			out.append(path)
		for i in (v as Array).size():
			out.append_array(_typed_containers(v[i], "%s[%d]" % [path, i]))
	elif v is Dictionary:
		if (v as Dictionary).is_typed():
			out.append(path)
		for k: Variant in v:
			out.append_array(_typed_containers(v[k], "%s.%s" % [path, k]))
	return out
