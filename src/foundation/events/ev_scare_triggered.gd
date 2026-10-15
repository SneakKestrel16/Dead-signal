## Emitter: Scare Events
## A scare; carries scope (shared or single-client).
## Field types are inferred from the systems-index.md Meaning column.
class_name EvScareTriggered
extends ServerEvent

var scope: int
var recipient: int


func type() -> StringName:
	return &"ScareTriggered"


## A shared scare emits one event per recipient. Recipients only; `source` and player identity stripped (ADR-0004 §5).
func project(peer: int, _handles: HandleTable, _monster: int) -> Dictionary:
	if peer != recipient:
		return {}
	return {"scope": scope}
