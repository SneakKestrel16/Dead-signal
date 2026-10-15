## Emitter: Monster Abilities
## A validated Predatory Lunge hit; starts the takedown commit.
## Field types are inferred from the systems-index.md Meaning column; per-peer projection arrives with ADR-0004.
class_name EvSurvivorHit
extends ServerEvent

var survivor: int


func type() -> StringName:
	return &"SurvivorHit"


## Fails closed: survivor clients never receive it (ADR-0004 §5); roles are not known here yet, so no peer gets it
## until the network-authority projection (NA-9, ADR-0004 §5) lands. SR-1 review 2026-10-14.
func project(_peer: int, _handles: HandleTable) -> Dictionary:
	return {}
