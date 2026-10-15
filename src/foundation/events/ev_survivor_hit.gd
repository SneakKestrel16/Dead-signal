## Emitter: Monster Abilities
## A validated Predatory Lunge hit; starts the takedown commit.
## Field types are inferred from the systems-index.md Meaning column.
class_name EvSurvivorHit
extends ServerEvent

var survivor: int


func type() -> StringName:
	return &"SurvivorHit"


## Never sent to any client: the hit shows as body presentation on relevant handles (ADR-0004 §5).
func project(_peer: int, _handles: HandleTable, _monster: int) -> Dictionary:
	return {}
