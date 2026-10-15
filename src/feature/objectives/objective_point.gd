@abstract
class_name ObjectivePoint extends Interactable
## One active objective point of SurvivorObjectives (drive console, fuse spawn, fuse box). Progress is
## not kept: a cancelled hold resets (start_progress_s 0). Holds its module weakly: HoldService keeps the
## point, and the module keeps HoldService, so a strong back-reference would be a RefCounted cycle that
## outlives the round.
## A top-level script, not an inner class: in Godot 4.7.2 an inner class extending a sibling inner class
## leaked the whole script graph at exit; see docs/engine-reference/godot/gotchas.md.

## The SurvivorObjectives module, as a WeakRef.
var owner: WeakRef = null
## Index of this point within its kind.
var index: int = 0


## Reset rule: every hold starts from 0.
func start_progress_s() -> float:
	return 0.0


func on_cancel(_actor: int, _progress_s: float, _reason: StringName) -> void:
	pass
