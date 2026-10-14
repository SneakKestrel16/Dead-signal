## Emitter: Monster Abilities
## A validated Lunge wind-up, False Signal or Blackout.
## Field types are inferred from the systems-index.md Meaning column; per-peer projection arrives with ADR-0004.
class_name EvAbilityUsed
extends ServerEvent

var ability: int
var position: Vector3
var detail: StringName


func type() -> StringName:
	return &"AbilityUsed"


func project(_peer: int, _handles: HandleTable) -> Dictionary:
	return {"ability": ability, "position": position, "detail": detail}
