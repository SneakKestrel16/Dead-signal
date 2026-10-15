class_name DefenseRoundStatsView extends DefenseStatsView
## Survivor Defense's live round stats under StateKeys.STATS_DEFENSE (story match-flow/014, ADR-0011 §1-2),
## registered by SurvivorDefense.setup. Getters only. Holds the module weakly; after it is freed every count
## reads 0.

var _sd: WeakRef


func _init(sd: SurvivorDefense) -> void:
	_sd = weakref(sd)


func get_times_monster_stunned() -> int:
	var sd := _sd.get_ref() as SurvivorDefense
	return sd.monster_stuns() if sd != null else 0


func get_stuns_landed(player_id: int) -> int:
	var sd := _sd.get_ref() as SurvivorDefense
	return sd.stuns_landed(player_id) if sd != null else 0


func get_resists_caused(player_id: int) -> int:
	var sd := _sd.get_ref() as SurvivorDefense
	return sd.resists_caused(player_id) if sd != null else 0
