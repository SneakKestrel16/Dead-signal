## Emitter: Borrowed Face
## Shapeshifter form changed.
## Field types are inferred from the systems-index.md Meaning column; per-peer projection arrives with ADR-0004.
class_name EvFormChanged
extends ServerEvent

var player: int
var form: int


func type() -> StringName:
	return &"FormChanged"


## Fails closed: survivor clients never receive it, and roles are not known here yet,
## so no peer gets it until the network-authority projection (ADR-0004) lands.
func project(_peer: int, _handles: HandleTable) -> Dictionary:
	return {}
