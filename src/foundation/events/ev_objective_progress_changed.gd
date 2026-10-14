## Emitter: Survivor Objectives
## Any objective state change.
## Field types are inferred from the systems-index.md Meaning column; per-peer projection arrives with ADR-0004.
class_name EvObjectiveProgressChanged
extends ServerEvent

var objective: int
var state: int


func type() -> StringName:
	return &"ObjectiveProgressChanged"


func project(_peer: int, _handles: HandleTable) -> Dictionary:
	return {"objective": objective, "state": state}
