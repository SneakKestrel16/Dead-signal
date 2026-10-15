class_name DefenseStatsView extends RefCounted
## Round stats owned by Survivor Defense (StateKeys.STATS_DEFENSE, ADR-0011 §1-2). Getters only.
## This base reads zero everywhere: the contract Survivor Defense's stats story subclasses (holding the
## module weakly), and what MatchFlow reads while no view is registered. Unknown player_id reads 0.


## Times the monster was stunned.
func get_times_monster_stunned() -> int:
	return 0


## Stuns `player_id` landed on the monster.
func get_stuns_landed(_player_id: int) -> int:
	return 0


## Resists `player_id` caused.
func get_resists_caused(_player_id: int) -> int:
	return 0
