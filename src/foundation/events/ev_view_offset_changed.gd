## Emitter: First-Person Controller & Interaction
## From ADR-0015 (Proposed): fields and projection may change when it is accepted.
## A new flinch record, freeze or re-baseline.
## Field types are inferred from the systems-index.md Meaning column; per-peer projection arrives with ADR-0004.
class_name EvViewOffsetChanged
extends ServerEvent

var player: int
var offset: Vector2


func type() -> StringName:
	return &"ViewOffsetChanged"


func project(_peer: int, _handles: HandleTable) -> Dictionary:
	return {"player": player, "offset": offset}
