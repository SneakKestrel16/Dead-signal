## Emitter: Monster Abilities
## A validated Predatory Lunge hit; starts the takedown commit.
## Field types are inferred from the systems-index.md Meaning column.
class_name EvSurvivorHit
extends ServerEvent

var survivor: int
## The shapeshifter that hit (monster-abilities.md rule 8: monster, survivor, server time, position).
var monster: int = -1
## The survivor's feet position the hit test used (rewound to the attacker's view, ADR-0003 §3).
var position: Vector3 = Vector3.ZERO


func type() -> StringName:
	return &"SurvivorHit"


## Never sent to any client: the hit shows as body presentation on relevant handles (ADR-0004 §5).
func project(_peer: int, _handles: HandleTable, _monster: int) -> Dictionary:
	return {}
