## Emitter: Downing, Rescue & Elimination
## Takedown commit completed; first down.
## Field types are inferred from the systems-index.md Meaning column.
class_name EvSurvivorDowned
extends ServerEvent

var survivor: int


## Remaining bleed-out time, s. Inference: ADR-0004 §5 says "bleed-out state"; Downing owns the real field.
var bleed_out_s: float


func type() -> StringName:
	return &"SurvivorDowned"


## Survivor player ID and life state to all; bleed-out state to survivors only (ADR-0004 §5). Fails
## closed before roles are dealt (monster -1): nobody gets the bleed-out state.
func project(peer: int, _handles: HandleTable, monster: int) -> Dictionary:
	if peer == monster or monster < 0:
		return {"survivor": survivor}
	return {"survivor": survivor, "bleed_out_s": bleed_out_s}
