## Emitter: Monster Abilities
## A validated Lunge wind-up, False Signal or Blackout.
## Field types are inferred from the systems-index.md Meaning column.
class_name EvAbilityUsed
extends ServerEvent

var ability: int
var position: Vector3
## The aim point (Lunge: the request's aim) or the targeted zone's point (story monster-abilities/005).
var target: Vector3
## False Signal's signal type (MonsterAbilities.SIGNAL_DETAILS); &"" for the others (story monster-abilities/009).
var detail: StringName
## A False Signal callout's impersonated survivor (or the footstep set's survivor); -1 otherwise (story 009).
var survivor: int = -1
## A False Signal callout's line id (PingsCallouts.CALLOUT_LINES; the request's sound field); &"" otherwise
## (story pings-and-callouts/003, rule 26: the fake uses the same authored line).
var line: StringName = &""


func type() -> StringName:
	return &"AbilityUsed"


## Never sent to any client: effects show as body presentation and positional cues (ADR-0004 §5).
func project(_peer: int, _handles: HandleTable, _monster: int) -> Dictionary:
	return {}
