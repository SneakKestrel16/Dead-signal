class_name SurvivorHudFeed extends RefCounted
## Server side of the survivor's own-state HUD (story hud-results/004; design/ux/hud.md H15, H16; ADR-0004 §5
## per-peer projection). Before it no message told a Seized survivor it was Seized (the roster has no Seized
## state, LifeDisplay) and none carried the rescue progress on a Downed survivor (Downing.rescue_progress_s,
## server only). This ServerMovement.batch_extras provider sends each survivor one EventBatch.OWN_LIFE entry
## {life, rescue_s} when either changes; rescue_s is in tenths of a second, so a running rescue sends at most
## 10 entries a second. The monster and any other id get nothing. Diffed once per tick, like
## HidingSpots.hiding_entries, so a spectator's stream (projected as the watched survivor) gets the same entry.
## Usage (RoundComposer):
##   survivor_hud = SurvivorHudFeed.new(survivors, _tick, downing.life_state, downing.rescue_progress_s)
##   sm.batch_extras.append(survivor_hud.entries)

const _HEALTHY := {"life": Downing.LifeState.HEALTHY, "rescue_s": 0.0}

var _survivors: Array[int]
var _tick: Callable
var _life_of: Callable
var _rescue_s_of: Callable
var _sent: Dictionary[int, Dictionary] = {} ## survivor -> last payload sent (absent = Healthy, no rescue)
var _out: Dictionary[int, Dictionary] = {} ## survivor -> this tick's changed payload
var _out_tick := -1


## Sources: tick() -> int; life_of(player) -> Downing.LifeState; rescue_s_of(player) -> float.
func _init(survivors: Array[int], tick: Callable, life_of: Callable, rescue_s_of: Callable) -> void:
	_survivors = survivors.duplicate()
	_tick = tick
	_life_of = life_of
	_rescue_s_of = rescue_s_of


## ServerMovement.batch_extras provider: [[EventBatch.OWN_LIFE, {life, rescue_s}]] for survivor `viewer`
## when it changed this tick, or its current state when `full` (a rejoin); [] for anyone else.
func entries(viewer: int, full: bool = false) -> Array:
	if not _survivors.has(viewer):
		return []
	if full:
		return [[EventBatch.OWN_LIFE, payload(viewer)]]
	var now: int = _tick.call()
	if _out_tick != now:
		_out_tick = now
		_out = {}
		for s in _survivors:
			var p := payload(s)
			if p != _sent.get(s, _HEALTHY):
				_sent[s] = p
				_out[s] = p
	return [[EventBatch.OWN_LIFE, _out[viewer]]] if _out.has(viewer) else []


## Survivor `player`'s current payload: {life: Downing.LifeState, rescue_s: float, tenths}.
func payload(player: int) -> Dictionary:
	return {"life": int(_life_of.call(player)), "rescue_s": snappedf(_rescue_s_of.call(player), 0.1)}

