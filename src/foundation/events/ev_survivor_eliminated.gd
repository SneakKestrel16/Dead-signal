## Emitter: Downing, Rescue & Elimination
## Second down completed.
## Field types are inferred from the systems-index.md Meaning column.
class_name EvSurvivorEliminated
extends ServerEvent

var survivor: int


func type() -> StringName:
	return &"SurvivorEliminated"


## Full to every peer (ADR-0004 §5 table: public fact).
func project(_peer: int, _handles: HandleTable, _monster: int) -> Dictionary:
	return {"survivor": survivor}
