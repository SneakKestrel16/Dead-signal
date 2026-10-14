## Emitter: Downing, Rescue & Elimination
## Takedown commit completed; first down.
## Field types are inferred from the systems-index.md Meaning column; per-peer projection arrives with ADR-0004.
class_name EvSurvivorDowned
extends ServerEvent

var survivor: int


func type() -> StringName:
	return &"SurvivorDowned"


func project(_peer: int, _handles: HandleTable) -> Dictionary:
	return {"survivor": survivor}
