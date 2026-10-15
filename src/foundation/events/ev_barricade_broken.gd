## Emitter: Survivor Defense
## A barricade was destroyed.
## Field types are inferred from the systems-index.md Meaning column.
class_name EvBarricadeBroken
extends ServerEvent

var barricade: int


func type() -> StringName:
	return &"BarricadeBroken"


## Not sent as an event: the door's state reaches peers through the PVS-replicated door and the break
## as a positional sound (ADR-0004 §5 table; inference: the row lists no event payload).
func project(_peer: int, _handles: HandleTable, _monster: int) -> Dictionary:
	return {}
