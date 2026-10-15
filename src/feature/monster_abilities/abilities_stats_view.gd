class_name AbilitiesStatsView extends RefCounted
## Round stats owned by Monster Abilities (StateKeys.STATS_ABILITIES, ADR-0011 §1-2). Getters only.
## This base reads zero everywhere: the contract Monster Abilities' stats story subclasses (holding the
## module weakly), and what MatchFlow reads while no view is registered.


## Lunges that hit a survivor.
func get_lunges_landed() -> int:
	return 0


## Lunges that hit nobody.
func get_lunges_missed() -> int:
	return 0


## Lunges stopped in wind-up or dash (stun or disconnect) before any hit.
func get_lunges_interrupted() -> int:
	return 0


## False Signals used.
func get_false_signals_used() -> int:
	return 0


## Blackouts used.
func get_blackouts_used() -> int:
	return 0
