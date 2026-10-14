## Emitter: Match Flow & Win Conditions
## Outcome final; carries outcome, reason and results payload.
## Field types are inferred from the systems-index.md Meaning column; per-peer projection arrives with ADR-0004.
class_name EvRoundEnded
extends ServerEvent

var outcome: int
var reason: int
var results: Dictionary


func type() -> StringName:
	return &"RoundEnded"


func project(_peer: int, _handles: HandleTable) -> Dictionary:
	return {"outcome": outcome, "reason": reason, "results": results}
