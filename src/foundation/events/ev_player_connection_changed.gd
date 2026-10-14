## Emitter: Match Flow & Win Conditions
## A player disconnected, reconnected or ran out of reconnect grace.
## Field types are inferred from the systems-index.md Meaning column; per-peer projection arrives with ADR-0004.
class_name EvPlayerConnectionChanged
extends ServerEvent

var player: int
var status: int


func type() -> StringName:
	return &"PlayerConnectionChanged"


func project(_peer: int, _handles: HandleTable) -> Dictionary:
	return {"player": player, "status": status}
