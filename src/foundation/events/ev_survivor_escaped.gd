## Emitter: Match Flow & Win Conditions
## A Healthy survivor entered the exit after evacuation activated.
## Field types are inferred from the systems-index.md Meaning column; per-peer projection arrives with ADR-0004.
class_name EvSurvivorEscaped
extends ServerEvent

var survivor: int


func type() -> StringName:
	return &"SurvivorEscaped"


func project(_peer: int, _handles: HandleTable) -> Dictionary:
	return {"survivor": survivor}
