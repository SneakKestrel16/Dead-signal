extends RefCounted
## RoundEnded results payloads for the Results screen (story hud-results/008): built through RoundResults and
## to_dict(), so their shape is the producer's. Shared by results_screen_test.gd and the manual capture scene
## tests/manual/results_view.gd. Numbers follow the design/ux/results.md wireframe (Ana, Ben, Cy, Dee; 8:12).

const S := MatchFlow.Status


## The wireframe round: evidence escaped at 8:12.
static func survivors_win() -> Dictionary:
	var r := _base(MatchFlow.Outcome.SURVIVORS_WIN, MatchFlow.Reason.EVIDENCE_ESCAPED, 492.0)
	r.survivors = [_row(1, "Ana", S.ESCAPED, "", 2, 1, 2, 1), _row(2, "Ben", S.ELIMINATED, "bled_out", 0, 2, 0, 0),
		_row(3, "Cy", S.DID_NOT_ESCAPE, "", 0, 0, 1, 1), _row(4, "Dee", S.DISCONNECTED, "", 0, 1, 0, 0)]
	r.objectives = _lines([2, 2, 2, 1, 2], [220.0, 355.0, 390.0, 464.0, 492.0])
	return r.to_dict()


## The deadline expired with one drive docked and the rest never done.
static func shapeshifter_win() -> Dictionary:
	var r := _base(MatchFlow.Outcome.SHAPESHIFTER_WINS, MatchFlow.Reason.DEADLINE, 540.0)
	r.survivors = [_row(1, "Ana", S.DID_NOT_ESCAPE, "", 0, 2, 1, 0),
		_row(2, "Ben", S.ELIMINATED, "takedown", 0, 1, 0, 1), _row(3, "Cy", S.ELIMINATED, "bled_out", 0, 2, 1, 0),
		_row(4, "Dee", S.DID_NOT_ESCAPE, "", 0, 0, 2, 1)]
	r.objectives = _lines([1, 1, 0, 0, 0], [301.5, 466.0, -1.0, -1.0, -1.0])
	return r.to_dict()


## The wireframe round with Survivor Defense unregistered: its figures read zero and its key is in `missing`.
static func defense_missing() -> Dictionary:
	var p := survivors_win()
	for s: Dictionary in p.survivors:
		s.stuns_landed = 0
	p.monster[&"times_stunned"] = 0
	p.missing = [StateKeys.STATS_DEFENSE]
	return p


static func _base(outcome: int, reason: int, duration_s: float) -> RoundResults:
	var r := RoundResults.new()
	r.outcome = outcome
	r.reason = reason
	r.duration_s = duration_s
	r.shapeshifter_player_id = 5
	r.shapeshifter_name = "Eli"
	r.monster = {&"takedowns": 3, &"eliminations": 1, &"lunges_landed": 4, &"lunges_missed": 3,
		&"lunges_interrupted": 1, &"times_stunned": 2, &"form_changes": 5, &"false_signals": 3, &"blackouts": 1}
	return r


static func _row(id: int, name: String, fate: int, cause: String, drives: int, downs: int, rescues: int,
		stuns: int) -> Dictionary:
	return {"player_id": id, "name": name, "fate": fate, "cause": cause, "drives_carried": drives,
		"downs": downs, "rescues": rescues, "stuns_landed": stuns}


static func _lines(counts: Array, times: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in RoundResults.LINES.size():
		out.append({"line": String(RoundResults.LINES[i]), "count": counts[i], "of": RoundResults.LINE_TOTALS[i],
			"completed_s": times[i]})
	return out
