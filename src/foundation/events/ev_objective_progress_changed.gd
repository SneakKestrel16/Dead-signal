## Emitter: Survivor Objectives
## Any objective state change.
## Field types are inferred from the systems-index.md Meaning column.
class_name EvObjectiveProgressChanged
extends ServerEvent

var objective: int
var state: int


## False while survivors have not discovered this drive room or fuse spawn. Fails closed: an owner
## that forgets to set it hides the point from survivors, never reveals it.
var discovered: bool = false


func type() -> StringName:
	return &"ObjectiveProgressChanged"


## Shapeshifter: every active point. Survivors: undiscovered drive rooms and fuse spawns omitted
## (ADR-0004 §5).
func project(peer: int, _handles: HandleTable, monster: int) -> Dictionary:
	if peer != monster and not discovered:
		return {}
	return {"objective": objective, "state": state}
