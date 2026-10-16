class_name BodyActions extends RefCounted
## The body action every snapshot entry carries (SnapshotCodec.Action; ADR-0004 §2 as amended 2026-10-16):
## what an observer sees the body do, derived on the server from module state. Priority: Seized (the
## takedown victim) > PIN (the committing monster, true form only: downing-and-rescue.md rule 4.3) > a recent
## real Call for Help (rule 6, the "need_rescue" callout) > the running hold's interactable kind. The hold
## kind is read from the interactable, never the actor, so a shapeshifter's fake hold (ADR-0008 §6) reads
## exactly as a survivor's real hold on the same object. Decides nothing; ServerMovement.action_of reads it.
## Usage (composition root):
##   var acts := BodyActions.new(knobs, holds.hold_of, holds.item, downing.life_state, _committing_monster,
##       bf.appearance_of, sd.is_hidden, pings.callouts, _tick)
##   sm.action_of = acts.action_of

## How long a Call for Help keeps CALL_HELP on the body (s). Inference: about the Call_Help clip's length
## (tools/art/build_anims.py); the clip's measured length or a designer call would settle it. Presentation
## only, so not a gameplay knob.
const CALL_HELP_S := 1.5

var _help_ticks: int
var _hold_of: Callable
var _item_of: Callable
var _life_of: Callable
var _committing: Callable
var _appearance_of: Callable
var _hidden: Callable
var _callouts: Callable
var _tick: Callable
## sender -> last tick its body shows CALL_HELP
var _help_until: Dictionary[int, int] = {}


## `hold_of(actor) -> Dictionary` HoldService.hold_of; `item_of(net_id) -> Interactable` HoldService.item;
## `life_of(player) -> Downing.LifeState`; `committing(player) -> bool` the player is the monster in a takedown
## commit; `appearance_of(player) -> int`; `hidden(player) -> bool`; `callouts() -> Array[CalloutRecord]` the
## latest tick's accepted callouts (PingsCallouts.callouts); `tick() -> int` the current server tick.
func _init(knobs: Knobs, hold_of: Callable, item_of: Callable, life_of: Callable, committing: Callable,
		appearance_of: Callable, hidden: Callable, callouts: Callable, tick: Callable) -> void:
	_help_ticks = ceili(CALL_HELP_S * knobs.net.sim_tick_hz)
	_hold_of = hold_of
	_item_of = item_of
	_life_of = life_of
	_committing = committing
	_appearance_of = appearance_of
	_hidden = hidden
	_callouts = callouts
	_tick = tick


## `player`'s SnapshotCodec.Action now.
func action_of(player: int) -> int:
	if _life_of.call(player) == Downing.LifeState.SEIZED:
		return SnapshotCodec.Action.SEIZED
	if _committing.call(player) and _appearance_of.call(player) == CharacterDef.TRUE_FORM_APPEARANCE_ID:
		return SnapshotCodec.Action.PIN
	for rec: PingsCallouts.CalloutRecord in _callouts.call():
		if rec.line == PingsCallouts.NEED_RESCUE and not rec.fake: ## a fake plays at a point, not on a body
			_help_until[rec.sender] = maxi(_help_until.get(rec.sender, -1), rec.tick + _help_ticks)
	var hold: Dictionary = _hold_of.call(player)
	if hold.is_empty():
		return SnapshotCodec.Action.CALL_HELP if _tick.call() <= _help_until.get(player, -1) \
				else SnapshotCodec.Action.NONE
	return kind_of(_item_of.call(hold.get("net_id", -1)), _hidden.call(player))


## The action of a hold on `item` (null: INTERACT). `hidden`: the actor is inside a hiding spot, so a Hide
## hold there is a leave (NONE: the body is in the spot; the exit plays as a BODY_CUE).
static func kind_of(item: Interactable, hidden: bool) -> int:
	if item is RescueHold:
		return SnapshotCodec.Action.KNEEL
	if item is BarricadeHold or item is BarricadeBreak:
		return SnapshotCodec.Action.BARRICADE
	if item is HidingHold and not (item as HidingHold).search:
		return SnapshotCodec.Action.NONE if hidden else SnapshotCodec.Action.HIDE
	return SnapshotCodec.Action.INTERACT
