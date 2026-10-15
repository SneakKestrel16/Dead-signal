class_name AbilitiesRoundStatsView extends AbilitiesStatsView
## Monster Abilities' live round stats under StateKeys.STATS_ABILITIES (story monster-abilities/008,
## ADR-0011 §1-2), registered by MonsterAbilities.setup. Getters only. Holds the module weakly; after it
## is freed every count reads 0.

var _ma: WeakRef


func _init(ma: MonsterAbilities) -> void:
	_ma = weakref(ma)


func get_lunges_landed() -> int:
	var ma := _ma.get_ref() as MonsterAbilities
	return ma.lunges_landed() if ma != null else 0


func get_lunges_missed() -> int:
	var ma := _ma.get_ref() as MonsterAbilities
	return ma.lunges_missed() if ma != null else 0


func get_lunges_interrupted() -> int:
	var ma := _ma.get_ref() as MonsterAbilities
	return ma.lunges_interrupted() if ma != null else 0


func get_blackouts_used() -> int:
	var ma := _ma.get_ref() as MonsterAbilities
	return ma.blackouts_used() if ma != null else 0


func get_false_signals_used() -> int:
	var ma := _ma.get_ref() as MonsterAbilities
	return ma.falsesignals_used() if ma != null else 0
