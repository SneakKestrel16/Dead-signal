## Emitter: Match Flow & Win Conditions
## A Healthy survivor entered the exit after evacuation activated.
## Field types are inferred from the systems-index.md Meaning column.
class_name EvSurvivorEscaped
extends ServerEvent

var survivor: int


func type() -> StringName:
	return &"SurvivorEscaped"


## Full to every peer (ADR-0004 §5 table: public fact).
func project(_peer: int, _handles: HandleTable, _monster: int) -> Dictionary:
	return {"survivor": survivor}
