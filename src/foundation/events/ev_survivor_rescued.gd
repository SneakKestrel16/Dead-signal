## Emitter: Downing, Rescue & Elimination
## Rescue completed.
## Field types are inferred from the systems-index.md Meaning column; per-peer projection arrives with ADR-0004.
class_name EvSurvivorRescued
extends ServerEvent

var survivor: int
var rescuer: int


func type() -> StringName:
	return &"SurvivorRescued"


func project(_peer: int, _handles: HandleTable) -> Dictionary:
	return {"survivor": survivor, "rescuer": rescuer}
