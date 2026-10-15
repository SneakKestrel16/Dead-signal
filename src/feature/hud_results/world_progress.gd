class_name WorldProgress extends RefCounted
## Server side of H13 world progress bars (design/ux/hud.md H13; interaction-patterns P4; survivor-objectives.md
## rules 19, 25-27; story hud-results/005). A ServerMovement.batch_extras provider: every real hold in progress
## and the activation countdown, as [EventBatch.PROGRESS, {key, at, progress 0-1, rate per second, paused}],
## sent on change only (start, pause, resume) like the bleed-out ring; the client runs the bar at `rate`
## between changes. An ended bar goes out once as {key, end: true}. `key` is the hold's net id, or
## ACTIVATION_KEY for the countdown, which shows "Paused" (rate 0) while nobody holds the zone.
## Not sent: fake holds (no progress, rule 25: the bar a survivor checks never moves for a fake), hiding
## (it would reveal the spot), the shapeshifter's backup switch, and instant interactions. Survivors only;
## the shapeshifter gets nothing (P4). ponytail: every survivor gets every bar (depth-tested in the world, so
## walls hide it); restrict by the viewer's relevance set (ADR-0004) if bars leak through open sightlines.
## Usage (round composer):
##   var wp := WorldProgress.new(knobs, survivors, roster.player_ids, holds.hold_of, holds.item,
##       objectives.activation, _tick)
##   sm.batch_extras.append(wp.entries)

## The key of the activation countdown (hold keys are net ids, 0 or more).
const ACTIVATION_KEY := -2

var _hz: float
var _evac_s: float
var _survivors: Array[int]
var _players: Callable
var _hold_of: Callable
var _item_of: Callable
var _activation: Callable
var _tick: Callable
var _at_tick := -1
## key -> payload of the bar as it stands this tick.
var _live: Dictionary[int, Dictionary] = {}
## key -> [rate, paused] last sent.
var _sent: Dictionary[int, Array] = {}
var _out: Array = []


## `players() -> Array` every player id; `hold_of(actor)` HoldService.hold_of; `item_of(net_id) ->
## Interactable` HoldService.item; `activation() -> Dictionary` SurvivorObjectives.activation; `tick() -> int`.
func _init(knobs: Knobs, survivors: Array[int], players: Callable, hold_of: Callable, item_of: Callable,
		activation: Callable, tick: Callable) -> void:
	_hz = float(knobs.net.sim_tick_hz)
	_evac_s = knobs.objectives.evac_activation_s
	_survivors = survivors.duplicate()
	_players = players
	_hold_of = hold_of
	_item_of = item_of
	_activation = activation
	_tick = tick


## ServerMovement.batch_extras provider: this tick's bar changes for `viewer`; `full` (a rejoin): every
## running bar as it stands.
func entries(viewer: int, full: bool = false) -> Array:
	if not _survivors.has(viewer):
		return []
	_refresh()
	if not full:
		return _out
	var out: Array = []
	for k: int in _live:
		out.append([EventBatch.PROGRESS, _live[k]])
	return out


func _refresh() -> void:
	var t: int = _tick.call()
	if t == _at_tick:
		return
	_at_tick = t
	var live: Dictionary[int, Dictionary] = {}
	for actor: int in _players.call():
		var h: Dictionary = _hold_of.call(actor)
		if h.is_empty() or h.get("fake", false):
			continue
		var item: Interactable = _item_of.call(h.net_id)
		if item == null or item.duration_s <= 0.0 or item is HidingHold or item is BackupSwitch:
			continue
		live[item.net_id] = {"key": item.net_id, "at": item.point,
			"progress": h.elapsed_ticks / (item.duration_s * _hz), "rate": 1.0 / item.duration_s, "paused": false}
	var a: Dictionary = _activation.call()
	if not a.is_empty():
		live[ACTIVATION_KEY] = {"key": ACTIVATION_KEY, "at": a.at, "progress": a.ticks / (_evac_s * _hz),
			"rate": 1.0 / _evac_s if a.held else 0.0, "paused": not a.held}
	_out = []
	for k: int in live:
		var sig := [live[k].rate, live[k].paused]
		if _sent.get(k, []) != sig:
			_sent[k] = sig
			_out.append([EventBatch.PROGRESS, live[k]])
	for k: int in _sent.keys():
		if not live.has(k):
			_sent.erase(k)
			_out.append([EventBatch.PROGRESS, {"key": k, "end": true}])
	_live = live
