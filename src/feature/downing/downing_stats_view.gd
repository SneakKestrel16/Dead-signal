class_name DowningStatsView extends RefCounted
## Round stats owned by Downing, Rescue & Elimination (StateKeys.STATS_DOWNING, ADR-0011 §1-2): downs
## taken, rescues performed and fate cause per survivor; takedowns and eliminations for the round.
## Getters only. This base reads zero everywhere: the contract Downing's stats story subclasses (holding
## the module weakly, like MatchFlow.ClockView), and what MatchFlow reads while no view is registered.
## An unknown player_id reads 0 / &"" (ADR-0011 guideline).


## Times `player_id` was downed this round.
func get_downs_taken(_player_id: int) -> int:
	return 0


## Rescues `player_id` completed this round.
func get_rescues_performed(_player_id: int) -> int:
	return 0


## Why an eliminated survivor died: &"bled_out", &"takedown", or &"" (not eliminated).
func get_fate_cause(_player_id: int) -> StringName:
	return &""


## Takedowns the monster performed.
func get_takedowns() -> int:
	return 0


## Survivors eliminated.
func get_eliminations() -> int:
	return 0
