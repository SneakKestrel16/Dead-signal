## Emitter: Borrowed Face
## Shapeshifter form changed.
## Field types are inferred from the systems-index.md Meaning column; per-peer projection arrives with ADR-0004.
class_name EvFormChanged
extends ServerEvent

var player: int
var form: int


func type() -> StringName:
	return &"FormChanged"


func project(_peer: int, _handles: HandleTable) -> Dictionary:
	return {"player": player, "form": form}
