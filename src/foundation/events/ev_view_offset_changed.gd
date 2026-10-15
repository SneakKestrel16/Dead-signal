## Emitter: First-Person Controller & Interaction
## A new flinch record, freeze or re-baseline (ADR-0015 §2; story controller-interaction/013).
class_name EvViewOffsetChanged
extends ServerEvent

var player: int
var record: FlinchRecord


func type() -> StringName:
	return &"ViewOffsetChanged"


## The owning player's client, and that player's spectators: ServerMovement builds a spectator's event
## batch projected as the watched survivor (ADR-0004 §8), so `peer` is the survivor for them too. A
## spectator that switches mid-hold gets the record again through ViewOffset.resend().
func project(peer: int, _handles: HandleTable, _monster: int) -> Dictionary:
	if peer != player:
		return {}
	return record.to_dict()
