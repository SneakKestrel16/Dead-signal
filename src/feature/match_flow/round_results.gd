class_name RoundResults extends RefCounted
## Results payload (design/gdd/match-flow.md rules 23-26; story match-flow/008; ADR-0011 §3-4). Built
## once by MatchFlow on the outcome tick from the owners' *StatsViews; only `to_dict()` goes on the wire
## (EvRoundEnded.results, Full to every peer). Match Flow tallies nothing here: every number comes from
## a view. A stats key with no registered view (owner not written yet) reads as zero and is listed in
## `missing`, so the screen never shows an invented value as real.
## Usage: `ev.results = RoundResults.read(registry, survivor_ids, shapeshifter_id, outcome, reason, hz).to_dict()`

## Objective lines in display order (rule 25); each one's total is LINE_TOTALS.
const LINES: Array[StringName] = [&"drives_recovered", &"drives_docked", &"fuses_installed",
	&"evacuation_activated", &"drives_extracted"]
const LINE_TOTALS: Array[int] = [SurvivorObjectives.ACTIVE_DRIVES, SurvivorObjectives.ACTIVE_DRIVES,
	SurvivorObjectives.FUSES_REQUIRED, 1, SurvivorObjectives.ACTIVE_DRIVES]
## Monster stats keys (rule 26).
const MONSTER_STATS: Array[StringName] = [&"takedowns", &"eliminations", &"lunges_landed",
	&"lunges_missed", &"lunges_interrupted", &"times_stunned", &"form_changes", &"false_signals", &"blackouts"]

var outcome: int = -1 ## MatchFlow.Outcome
var reason: int = -1 ## MatchFlow.Reason
var duration_s: float = 0.0
var shapeshifter_player_id: int = -1
var shapeshifter_name: String = ""
## {player_id, name, fate (MatchFlow.Status), cause, drives_carried, downs, rescues, stuns_landed}
var survivors: Array[Dictionary] = []
## {line, count, of, completed_s (round time; -1.0 not completed)}, in LINES order.
var objectives: Array[Dictionary] = []
var monster: Dictionary[StringName, int] = {}
## StateKeys with no registered view when read: their numbers are zeroes, not counts.
var missing: Array[StringName] = []


## Reads every stats view once and builds the payload. `hz` converts ticks to seconds (the only
## conversion, ADR-0011 guideline). Names come from StateKeys.PLAYER_ROSTER when registered.
static func read(registry: StateRegistry, survivor_ids: Array[int], shapeshifter_id: int, outcome_: int,
		reason_: int, hz: int) -> RoundResults:
	var r := RoundResults.new()
	r.outcome = outcome_
	r.reason = reason_
	var m := registry.view(StateKeys.STATS_MATCH, MatchStatsView) as MatchStatsView
	var down := r._view(registry, StateKeys.STATS_DOWNING, DowningStatsView) as DowningStatsView
	var abil := r._view(registry, StateKeys.STATS_ABILITIES, AbilitiesStatsView) as AbilitiesStatsView
	var def := r._view(registry, StateKeys.STATS_DEFENSE, DefenseStatsView) as DefenseStatsView
	var face := r._view(registry, StateKeys.STATS_BORROWED_FACE, BorrowedFaceStatsView) as BorrowedFaceStatsView
	var obj := r._view(registry, StateKeys.STATS_OBJECTIVES, ObjectivesStatsView) as ObjectivesStatsView
	var roster: RosterView = null
	if registry.has_view(StateKeys.PLAYER_ROSTER):
		roster = registry.view(StateKeys.PLAYER_ROSTER, RosterView) as RosterView
	else:
		r.missing.append(StateKeys.PLAYER_ROSTER)
	var start := m.get_start_tick()
	r.duration_s = float(m.get_end_tick() - start) / hz
	r.shapeshifter_player_id = shapeshifter_id
	r.shapeshifter_name = roster.get_display_name(shapeshifter_id) if roster != null else ""
	for id in survivor_ids:
		r.survivors.append({"player_id": id,
			"name": roster.get_display_name(id) if roster != null else "",
			"fate": m.get_fate(id), "cause": String(down.get_fate_cause(id)),
			"drives_carried": obj.get_drives_carried_at_escape(id), "downs": down.get_downs_taken(id),
			"rescues": down.get_rescues_performed(id), "stuns_landed": def.get_stuns_landed(id)})
	for i in LINES.size():
		var done := obj.get_line_completed_tick(LINES[i])
		r.objectives.append({"line": String(LINES[i]), "count": obj.get_line_count(LINES[i]),
			"of": LINE_TOTALS[i], "completed_s": float(done - start) / hz if done >= 0 else -1.0})
	r.monster = {&"takedowns": down.get_takedowns(), &"eliminations": down.get_eliminations(),
		&"lunges_landed": abil.get_lunges_landed(), &"lunges_missed": abil.get_lunges_missed(),
		&"lunges_interrupted": abil.get_lunges_interrupted(),
		&"times_stunned": def.get_times_monster_stunned(), &"form_changes": face.get_form_changes(),
		&"false_signals": abil.get_false_signals_used(), &"blackouts": abil.get_blackouts_used()}
	return r


## The wire form: fresh untyped containers built field by field (ADR-0011 guideline; `duplicate()` and
## `Array(typed)` keep the element type).
func to_dict() -> Dictionary:
	var surv: Array = []
	for s in survivors:
		var d := {}
		d.merge(s)
		surv.append(d)
	var objs: Array = []
	for o in objectives:
		var d := {}
		d.merge(o)
		objs.append(d)
	var mon := {}
	mon.merge(monster)
	var miss: Array = []
	miss.assign(missing)
	return {"outcome": outcome, "reason": reason, "duration_s": duration_s,
		"shapeshifter_player_id": shapeshifter_player_id, "shapeshifter_name": shapeshifter_name,
		"survivors": surv, "objectives": objs, "monster": mon, "missing": miss}


## `key`'s view, or a zero-reading `base` instance listed in `missing` when no owner registered one.
func _view(registry: StateRegistry, key: StringName, base: Script) -> Object:
	if registry.has_view(key):
		return registry.view(key, base)
	missing.append(key)
	return base.new()
