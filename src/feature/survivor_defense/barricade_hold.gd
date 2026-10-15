class_name BarricadeHold extends Interactable
## Barricade or Remove barricade on one barricadable door (design/gdd/survivor-defense.md rules 25, 26,
## 28a; ADR-0008; story survivor-defense/007). Not rooting, progress resets on cancel, not fakeable; on
## the door's one exclusive lock (Barricades.lock_key), shared with Break (story 008).
## Holds Barricades weakly (Barricades keeps HoldService, HoldService keeps this).
## A top-level script, not an inner class: see docs/engine-reference/godot/gotchas.md.

## Door net id.
var door: int = -1
## True for Remove barricade, false for Barricade.
var remove: bool = false
## The Barricades module, as a WeakRef.
var owner: WeakRef = null


func eligible(actor: int) -> bool:
	var b := owner.get_ref() as Barricades
	return b != null and (b.can_remove(actor, door) if remove else b.can_build(actor, door))


## Rule 28a: progress resets on cancel.
func start_progress_s() -> float:
	return 0.0


func on_complete(_actor: int) -> void:
	var b := owner.get_ref() as Barricades
	if b != null:
		b.complete(door, remove)


func on_cancel(_actor: int, _progress_s: float, _reason: StringName) -> void:
	pass
