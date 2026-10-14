class_name MovementModifiers extends RefCounted
## The effective movement modifier handed to the shared movement step (ADR-0002 rule 5 and `apply_move`).
## Seam only: controller story 002 owns the arbitration (lock, root, slow) that fills it. The server
## computes it; the owning client takes it from the latest own-body snapshot entry.

## 1.0 = no slow. Applies to walking speed.
var speed_scale: float = 1.0
## No movement input is applied while rooted.
var rooted: bool = false
## No movement or look input is applied while locked.
var locked: bool = false


## The single scale a snapshot carries: 0.0 when rooted or locked, else speed_scale.
func effective_scale() -> float:
	return 0.0 if rooted or locked else speed_scale


## Rebuilds from a snapshot scale. 0.0 reads as rooted (a snapshot cannot tell root from lock).
func set_from_scale(scale: float) -> void:
	rooted = scale <= 0.0
	locked = false
	speed_scale = 1.0 if rooted else scale
