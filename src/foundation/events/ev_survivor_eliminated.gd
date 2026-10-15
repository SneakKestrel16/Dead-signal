## Emitter: Downing, Rescue & Elimination
## Second down completed, or a Downed survivor bled out (design/gdd/downing-and-rescue.md rule 6).
## Field types are inferred from the systems-index.md Meaning column.
class_name EvSurvivorEliminated
extends ServerEvent

## Values of `reason`; display text in REASON_TEXT. "Bled out" is the GDD's (rule 6). "Taken down" is
## inference: the GDD names no text for a second-down elimination; the designer settles it.
const TAKEN_DOWN := 0
const BLED_OUT := 1
const REASON_TEXT: Array[String] = ["Taken down", "Bled out"]

var survivor: int
var reason: int = TAKEN_DOWN


func type() -> StringName:
	return &"SurvivorEliminated"


## Full to every peer (ADR-0004 §5 table: public fact).
func project(_peer: int, _handles: HandleTable, _monster: int) -> Dictionary:
	return {"survivor": survivor, "reason": reason}
