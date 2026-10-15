## Emitter: Match Flow & Win Conditions
## A player disconnected, reconnected or ran out of reconnect grace.
## Field types are inferred from the systems-index.md Meaning column.
class_name EvPlayerConnectionChanged
extends ServerEvent

## Values of `status` (inference: the systems-index Meaning column names the three cases, not their codes).
const DISCONNECTED := 0
const RECONNECTED := 1
const GRACE_EXPIRED := 2

var player: int
var status: int


func type() -> StringName:
	return &"PlayerConnectionChanged"


## Full to every peer (ADR-0004 §5 table: public fact).
func project(_peer: int, _handles: HandleTable, _monster: int) -> Dictionary:
	return {"player": player, "status": status}
