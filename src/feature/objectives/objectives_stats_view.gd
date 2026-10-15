class_name ObjectivesStatsView extends RefCounted
## Round stats owned by Survivor Objectives (StateKeys.STATS_OBJECTIVES, ADR-0011 §1-2): per objective
## line (RoundResults.LINES) the count and the server tick it completed; drives carried out per survivor.
## Getters only; ticks, never seconds (RoundResults converts). This base reads zero / -1: the contract
## Survivor Objectives' stats story subclasses (holding the module weakly), and what MatchFlow reads
## while no view is registered. Unknown line or player_id reads 0 / -1.


## How many of `line` are done: drives recovered, docked, fuses installed, extracted (0-2);
## evacuation activated (0-1).
func get_line_count(_line: StringName) -> int:
	return 0


## Server tick `line` completed (its last unit), -1 while incomplete.
func get_line_completed_tick(_line: StringName) -> int:
	return -1


## Drives `player_id` carried when they escaped.
func get_drives_carried_at_escape(_player_id: int) -> int:
	return 0
