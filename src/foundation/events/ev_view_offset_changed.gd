## Emitter: First-Person Controller & Interaction
## A new flinch record, freeze or re-baseline (ADR-0015 §2; story controller-interaction/013).
class_name EvViewOffsetChanged
extends ServerEvent

var player: int
var record: FlinchRecord


func type() -> StringName:
	return &"ViewOffsetChanged"


## The owning player's client only. ADR-0015 §2 also sends it to that player's spectators; the
## projection has no spectator input yet, so they are not reached.
func project(peer: int, _handles: HandleTable, _monster: int) -> Dictionary:
	if peer != player:
		return {}
	return record.to_dict()
