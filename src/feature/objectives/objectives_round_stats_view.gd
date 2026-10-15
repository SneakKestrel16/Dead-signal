class_name ObjectivesRoundStatsView extends ObjectivesStatsView
## Survivor Objectives' live round stats under StateKeys.STATS_OBJECTIVES (story match-flow/014, ADR-0011
## §1-2), registered by SurvivorObjectives.setup. Getters only; ticks, never seconds. Holds the module weakly;
## after it is freed every line reads 0 / -1.

var _o: WeakRef


func _init(o: SurvivorObjectives) -> void:
	_o = weakref(o)


func get_line_count(line: StringName) -> int:
	var o := _o.get_ref() as SurvivorObjectives
	return o.line_count(line) if o != null else 0


func get_line_completed_tick(line: StringName) -> int:
	var o := _o.get_ref() as SurvivorObjectives
	return o.line_completed_tick(line) if o != null else -1


func get_drives_carried_at_escape(player_id: int) -> int:
	var o := _o.get_ref() as SurvivorObjectives
	return o.drives_carried_at_escape(player_id) if o != null else 0
