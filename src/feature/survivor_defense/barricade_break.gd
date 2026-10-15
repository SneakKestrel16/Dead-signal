class_name BarricadeBreak extends Interactable
## Break on one barricaded door (design/gdd/survivor-defense.md rules 15, 27, 28a; ADR-0008; story
## survivor-defense/008). The monster in any form; rooting; a real, visible hold (not fakeable); progress
## kept on every cancel, a stun included, on the door's one exclusive lock (Barricades.lock_key).
## Holds Barricades weakly (Barricades keeps HoldService, HoldService keeps this).
## A top-level script, not an inner class: see docs/engine-reference/godot/gotchas.md.

## Door net id.
var door: int = -1
## The Barricades module, as a WeakRef.
var owner: WeakRef = null


func eligible(actor: int) -> bool:
	var b := owner.get_ref() as Barricades
	return b != null and b.can_break(actor, door)


## Rule 27: the door's stored break time.
func start_progress_s() -> float:
	var b := owner.get_ref() as Barricades
	return b.break_progress_s(door) if b != null else 0.0


func on_complete(_actor: int) -> void:
	var b := owner.get_ref() as Barricades
	if b != null:
		b.break_barricade(door)


## Rules 15, 27: progress persists whatever ended the hold.
func on_cancel(_actor: int, progress_s: float, _reason: StringName) -> void:
	var b := owner.get_ref() as Barricades
	if b != null:
		b.keep_break_progress(door, progress_s)
