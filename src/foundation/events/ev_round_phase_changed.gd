## Emitter: Match Flow & Win Conditions
## Phase moved (Infiltration, Investigation, Evacuation).
## Field types are inferred from the systems-index.md Meaning column.
class_name EvRoundPhaseChanged
extends ServerEvent

var phase: int


func type() -> StringName:
	return &"RoundPhaseChanged"


## Full to every peer (ADR-0004 §5 table: public fact).
func project(_peer: int, _handles: HandleTable, _monster: int) -> Dictionary:
	return {"phase": phase}
