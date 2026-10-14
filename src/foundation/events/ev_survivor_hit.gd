## Emitter: Monster Abilities
## A validated Predatory Lunge hit; starts the takedown commit.
## Field types are inferred from the systems-index.md Meaning column; per-peer projection arrives with ADR-0004.
class_name EvSurvivorHit
extends ServerEvent

var survivor: int


func type() -> StringName:
	return &"SurvivorHit"


func project(_peer: int, _handles: HandleTable) -> Dictionary:
	return {"survivor": survivor}
