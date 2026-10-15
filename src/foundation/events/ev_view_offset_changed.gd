## Emitter: First-Person Controller & Interaction
## From ADR-0015 (Proposed): fields and projection may change when it is accepted.
## A new flinch record, freeze or re-baseline.
## Field types are inferred from the systems-index.md Meaning column.
class_name EvViewOffsetChanged
extends ServerEvent

var player: int
var offset: Vector2


func type() -> StringName:
	return &"ViewOffsetChanged"


## The owning player's client only (ADR-0015 Proposed: may change when it is accepted).
func project(peer: int, _handles: HandleTable, _monster: int) -> Dictionary:
	if peer != player:
		return {}
	return {"offset": offset}
