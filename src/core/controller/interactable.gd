@abstract
class_name Interactable extends RefCounted
## One interaction an owner defines (ADR-0008 §2; first-person-controller.md rule 11). Values come
## from the owner's data. HoldService times every hold; the owner only answers eligible() and
## start_progress_s() and receives the callbacks, then emits its own catalog event.
## Usage: `class DriveSlot extends Interactable: ...`, then `holds.register(slot)`.

## Set by HoldService.register.
var net_id: int = -1
## Interaction point, world space.
var point: Vector3
var range_m: float
## 0 = instant: completes on the Start tick and takes no lock.
var duration_s: float
var roots_actor: bool
## &"" = no lock. Interactables sharing a key exclude each other (a door's barricade and break).
var lock_key: StringName = &""
## The shapeshifter's Start becomes a fake hold, unseen by the owner (ADR-0008 §6); false: the owner's
## eligible() refuses the shapeshifter as for any other actor it refuses.
var fakeable: bool


## Per the owner: shock lock, hidden, Downed, role.
@abstract func eligible(actor: int) -> bool
## The owner's stored progress a new hold starts from (0 for reset rules).
@abstract func start_progress_s() -> float


func on_start(_actor: int) -> void:
	pass


@abstract func on_complete(actor: int) -> void
## `reason` names why: &"released", &"replaced", &"unregistered", &"left", &"ineligible", &"range",
## &"sight", &"round_ended", &"disconnected" (ControllerAuthority), or the owner's own (holds.cancel). The owner maps it to reset, keep or decay.
@abstract func on_cancel(actor: int, progress_s: float, reason: StringName) -> void
