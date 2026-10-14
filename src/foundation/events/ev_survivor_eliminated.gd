## Emitter: Downing, Rescue & Elimination
## Second down completed.
## Field types are inferred from the systems-index.md Meaning column; per-peer projection arrives with ADR-0004.
class_name EvSurvivorEliminated
extends ServerEvent

var survivor: int


func type() -> StringName:
	return &"SurvivorEliminated"


func project(_peer: int, _handles: HandleTable) -> Dictionary:
	return {"survivor": survivor}
