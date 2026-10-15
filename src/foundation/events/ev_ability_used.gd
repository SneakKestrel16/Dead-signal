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


## Fails closed: survivor clients never receive it (ADR-0004 §5); roles are not known here yet, so no peer gets it
## until the network-authority projection (NA-9, ADR-0004 §5) lands. SR-1 review 2026-10-14.
func project(_peer: int, _handles: HandleTable) -> Dictionary:
	return {}
