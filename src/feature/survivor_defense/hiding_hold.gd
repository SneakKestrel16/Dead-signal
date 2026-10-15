class_name HidingHold extends Interactable
## Hide (enter or leave) or Search on one hiding spot (design/gdd/survivor-defense.md rules 19, 22, 28a;
## ADR-0008; story survivor-defense/006). Rooting, progress resets on cancel, not fakeable. Hide holds
## the spot's occupant lock, Search its own one-actor lock, so a search can run during an entry.
## Holds HidingSpots weakly (HidingSpots keeps HoldService, HoldService keeps this).
## A top-level script, not an inner class: see docs/engine-reference/godot/gotchas.md.

## Spot index (HidingSpots order).
var spot: int = -1
## True for Search, false for Hide.
var search: bool = false
## The HidingSpots module, as a WeakRef.
var owner: WeakRef = null


func eligible(actor: int) -> bool:
	var h := owner.get_ref() as HidingSpots
	return h != null and (h.can_search(actor) if search else h.can_hide(actor, spot))


## Rule 28a: progress resets on cancel.
func start_progress_s() -> float:
	return 0.0


func on_start(actor: int) -> void:
	var h := owner.get_ref() as HidingSpots
	if h != null and not search:
		h.hide_started(actor, spot)


func on_complete(actor: int) -> void:
	var h := owner.get_ref() as HidingSpots
	if h == null:
		return
	if search:
		h.search_completed(spot)
	else:
		h.hide_completed(actor, spot)


func on_cancel(actor: int, _progress_s: float, _reason: StringName) -> void:
	var h := owner.get_ref() as HidingSpots
	if h != null and not search:
		h.hide_cancelled(actor, spot)
