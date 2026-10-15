class_name HoldReasonFeed extends RefCounted
## Server side of the H8/H9 cause label (story hud-results/011; design/ux/hud.md H8, H9; interaction-patterns P3,
## P10; ADR-0004 §5). HoldService.on_end reports every cancel and the refusals it can name; this
## ServerMovement.batch_extras provider sends the newest one of the tick as EventBatch.HOLD_END {reason} to the
## actor's own peer only. An event entry rather than a reason byte in the own snapshot entry: no SnapshotCodec
## version bump, and the reliable channel cannot lose it (the client pairs it with the bar's end, either order).
## Only TEXT's reasons are sent. Not sent: released and replaced (the client knows), ineligible (it can stand for
## a state the actor may not know the cause of; P10 never reveals hidden state), round end, disconnects.
## "In use" reveals nothing new: a real Start on a fake hold's object is accepted (rule 25), so refusal vs
## acceptance already told the actor the holder is real.
## Usage (RoundComposer):
##   hold_reasons = HoldReasonFeed.new(_tick); holds.on_end = hold_reasons.note
##   sm.batch_extras.append(hold_reasons.entries)

## Reason -> label (P3's cancel causes, P10's refusal texts). Inference: "Found" for a Hide hold ended by a
## search, which P3 does not list; a ux-designer ruling would settle it. Hit has no code here: a hit Downs the
## actor, which ends the hold as ineligible.
const TEXT := {
	&"range": "Moved away",
	&"sight": "Lost sight",
	&"shocked": "Shocked",
	&"ejected": "Found",
	&"too_far": "Too far",
	&"no_sight": "Can't see it",
	&"in_use": "In use",
}

var _tick: Callable
var _pending: Dictionary[int, Array] = {} ## actor -> [tick, reason]


## `tick() -> int`: the current server tick.
func _init(tick: Callable) -> void:
	_tick = tick


## HoldService.on_end: keeps `reason` for `actor`'s stream this tick when it is one of TEXT's.
func note(actor: int, reason: StringName) -> void:
	if TEXT.has(reason):
		_pending[actor] = [_tick.call(), reason]


## ServerMovement.batch_extras provider: this tick's reason for `viewer`'s own hold, once; [] otherwise. A
## rejoin gets nothing (a past hold's cause is stale).
func entries(viewer: int, _full: bool = false) -> Array:
	if not _pending.has(viewer):
		return []
	var p: Array = _pending[viewer]
	_pending.erase(viewer)
	if p[0] != _tick.call():
		return []
	return [[EventBatch.HOLD_END, {"reason": p[1]}]]
