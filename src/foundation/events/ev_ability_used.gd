## Emitter: Monster Abilities
## A validated Lunge wind-up, False Signal or Blackout.
## Field types are inferred from the systems-index.md Meaning column.
class_name EvAbilityUsed
extends ServerEvent

var ability: int
var position: Vector3
var detail: StringName


func type() -> StringName:
	return &"AbilityUsed"


## Never sent to any client: effects show as body presentation and positional cues (ADR-0004 §5).
func project(_peer: int, _handles: HandleTable, _monster: int) -> Dictionary:
	return {}
