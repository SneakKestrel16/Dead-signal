## Emitter: Match Flow & Win Conditions
## Phase moved (Infiltration, Investigation, Evacuation).
## Field types are inferred from the systems-index.md Meaning column; per-peer projection arrives with ADR-0004.
class_name EvRoundPhaseChanged
extends ServerEvent

var phase: int


func type() -> StringName:
	return &"RoundPhaseChanged"


func project(_peer: int, _handles: HandleTable) -> Dictionary:
	return {"phase": phase}
