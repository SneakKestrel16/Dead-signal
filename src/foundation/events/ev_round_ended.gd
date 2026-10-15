## Emitter: Match Flow & Win Conditions
## Outcome final; carries outcome, reason and results payload.
## Field types are inferred from the systems-index.md Meaning column.
class_name EvRoundEnded
extends ServerEvent

var outcome: int
var reason: int
var results: Dictionary


func type() -> StringName:
	return &"RoundEnded"


## Full to every peer (ADR-0004 §5 table: public fact).
func project(_peer: int, _handles: HandleTable, _monster: int) -> Dictionary:
	return {"outcome": outcome, "reason": reason, "results": results.duplicate(true)}
