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


## Fails closed: only the owning player's client may receive it; roles are not known here yet, so no peer gets it
## until the network-authority projection (NA-9, ADR-0004 §5) lands. SR-1 review 2026-10-14.
func project(_peer: int, _handles: HandleTable) -> Dictionary:
	return {}
