## Emitter: Scare Events
## From ADR-0015 (Proposed): fields and projection may change when it is accepted.
## A Major scare asks for a camera flinch on one player.
## Field types are inferred from the systems-index.md Meaning column.
class_name EvFlinchRequested
extends ServerEvent

var player: int
## Requested yaw/pitch offset in radians; the Controller caps it at flinch_max_angle_deg (ADR-0015 §1).
var target: Vector2


func type() -> StringName:
	return &"FlinchRequested"


## The flinching player's own client only (ADR-0015 Proposed: may change when it is accepted).
func project(peer: int, _handles: HandleTable, _monster: int) -> Dictionary:
	if peer != player:
		return {}
	return {"flinch": true}
