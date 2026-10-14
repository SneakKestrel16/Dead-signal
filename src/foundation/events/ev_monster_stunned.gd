## Emitter: Survivor Defense
## Stun applied; cancels lunge, takedown commit or transformation.
## Field types are inferred from the systems-index.md Meaning column; per-peer projection arrives with ADR-0004.
class_name EvMonsterStunned
extends ServerEvent

var monster: int


func type() -> StringName:
	return &"MonsterStunned"


## Fails closed: survivors get it only by per-peer handle while in true form (ADR-0004),
## which needs handles not built yet, so no peer gets it until that projection lands.
func project(_peer: int, _handles: HandleTable) -> Dictionary:
	return {}
