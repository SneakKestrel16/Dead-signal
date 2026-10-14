## Emitter: Scare Events
## From ADR-0015 (Proposed): fields and projection may change when it is accepted.
## A Major scare asks for a camera flinch on one player.
## Field types are inferred from the systems-index.md Meaning column; per-peer projection arrives with ADR-0004.
class_name EvFlinchRequested
extends ServerEvent

var player: int


func type() -> StringName:
	return &"FlinchRequested"


func project(_peer: int, _handles: HandleTable) -> Dictionary:
	return {"player": player}
