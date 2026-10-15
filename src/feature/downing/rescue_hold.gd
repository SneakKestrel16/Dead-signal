class_name RescueHold extends Interactable
## The Rescue interaction on one Downed survivor (design/gdd/downing-and-rescue.md rule 7, Formulas
## "Rescue progress"; ADR-0008 stored progress; story downing-and-rescue/004). Exclusive per survivor,
## so a second rescuer's Start is refused while one holds. Progress lives here, on the Downed survivor,
## not in HoldService: a cancelled hold stores it and Downing decays it each tick nobody holds.
## Holds Downing weakly (Downing keeps HoldService, HoldService keeps this).
## A top-level script, not an inner class: in Godot 4.7.2 an inner class extending a sibling inner class
## leaked the whole script graph at exit; see docs/engine-reference/godot/gotchas.md.

## The Downed survivor.
var survivor: int = -1
## Stored progress, s: what a new hold starts from.
var progress_s: float = 0.0
## The active rescuer, -1 when nobody holds.
var rescuer: int = -1
## The Downing module, as a WeakRef.
var owner: WeakRef = null


func eligible(actor: int) -> bool:
	var d := owner.get_ref() as Downing
	return d != null and d.can_rescue(actor, survivor)


func start_progress_s() -> float:
	return progress_s


func on_start(actor: int) -> void:
	rescuer = actor
	var d := owner.get_ref() as Downing
	if d != null:
		d.set_rescuing(survivor, true)


func on_complete(actor: int) -> void:
	rescuer = -1
	var d := owner.get_ref() as Downing
	if d != null:
		d.rescue_completed(survivor, actor)


## Every interruption keeps the progress; Downing decays it from the next tick (rule 7).
func on_cancel(_actor: int, p_progress_s: float, _reason: StringName) -> void:
	rescuer = -1
	progress_s = p_progress_s
	var d := owner.get_ref() as Downing
	if d != null:
		d.set_rescuing(survivor, false)


## Formulas "Rescue progress", one idle step: `max(0, progress - rescue_decay_rate * dt)`.
func decay(rate: float, dt: float) -> void:
	progress_s = maxf(0.0, progress_s - rate * dt)
