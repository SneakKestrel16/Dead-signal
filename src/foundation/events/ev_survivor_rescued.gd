## Emitter: Downing, Rescue & Elimination
## Rescue completed.
## Field types are inferred from the systems-index.md Meaning column.
class_name EvSurvivorRescued
extends ServerEvent

var survivor: int
var rescuer: int


func type() -> StringName:
	return &"SurvivorRescued"


## Full to every peer (ADR-0004 §5 table: public fact).
func project(_peer: int, _handles: HandleTable, _monster: int) -> Dictionary:
	return {"survivor": survivor} ## the table row allows the survivor and life state only, not the rescuer
