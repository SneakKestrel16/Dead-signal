## Emitter: Survivor Defense
## A barricade was destroyed.
## Field types are inferred from the systems-index.md Meaning column; per-peer projection arrives with ADR-0004.
class_name EvBarricadeBroken
extends ServerEvent

var barricade: int


func type() -> StringName:
	return &"BarricadeBroken"


func project(_peer: int, _handles: HandleTable) -> Dictionary:
	return {"barricade": barricade}
