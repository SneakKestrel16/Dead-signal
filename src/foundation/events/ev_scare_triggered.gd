## Emitter: Scare Events
## A scare; carries scope (shared or single-client).
## Field types are inferred from the systems-index.md Meaning column; per-peer projection arrives with ADR-0004.
class_name EvScareTriggered
extends ServerEvent

var scope: int
var recipient: int


func type() -> StringName:
	return &"ScareTriggered"


## Recipient clients only (systems-index); shared-scope fan-out arrives with ADR-0004.
func project(peer: int, _handles: HandleTable) -> Dictionary:
	if peer != recipient:
		return {}
	return {"scope": scope, "recipient": recipient}
