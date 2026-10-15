class_name DowningRoundStatsView extends DowningStatsView
## Downing's live round stats under StateKeys.STATS_DOWNING (story match-flow/014, ADR-0011 §1-2),
## registered by Downing.setup. Getters only. Holds the module weakly; after it is freed every count reads 0.

var _d: WeakRef


func _init(d: Downing) -> void:
	_d = weakref(d)


func get_downs_taken(player_id: int) -> int:
	var d := _d.get_ref() as Downing
	return d.downs_taken(player_id) if d != null else 0


func get_rescues_performed(player_id: int) -> int:
	var d := _d.get_ref() as Downing
	return d.rescues_performed(player_id) if d != null else 0


func get_fate_cause(player_id: int) -> StringName:
	var d := _d.get_ref() as Downing
	return d.fate_cause(player_id) if d != null else &""


func get_takedowns() -> int:
	var d := _d.get_ref() as Downing
	return d.takedowns() if d != null else 0


func get_eliminations() -> int:
	var d := _d.get_ref() as Downing
	return d.eliminations() if d != null else 0
