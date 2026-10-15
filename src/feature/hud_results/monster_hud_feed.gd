class_name MonsterHudFeed extends RefCounted
## Server side of the shapeshifter HUD (story hud-results/006; design/ux/hud.md S1-S5; ADR-0004 §5 per-peer
## projection). Before it no message carried the ability and form cooldowns, the observation progress, the
## transformation's end or the stun and immunity windows to any client; this ServerMovement.batch_extras
## provider sends them as one EventBatch.MONSTER_HUD entry to the shapeshifter's own peer only, when they
## change. A survivor or spectator viewer gets nothing, so a survivor client never holds the data (ADR-0004 §1).
## Times are absolute server ticks: they change only when a cooldown, transformation or stun starts, so the
## entry is not re-sent every tick (observation progress excepted, while it accumulates).
## Usage (RoundComposer):
##   var feed := MonsterHudFeed.new(monster, survivors, _tick, ma.ready_tick, bf.cooldown_end_tick,
##       bf.transform_end_tick, sd.lock_end_tick, sd.free_tick, bf.observation_s, bf.appearance_of)
##   sm.batch_extras.append(feed.entries)

## Payload keys of `ready`, in MonsterAbilities.Ability order, then the form change.
const ABILITY_KEYS: Array[StringName] = [&"lunge", &"false_signal", &"blackout"]
const FORM_KEY := &"form"

var _monster: int
var _survivors: Array[int]
var _tick: Callable
var _ready_of: Callable
var _form_ready: Callable
var _transform_end: Callable
var _lock_end: Callable
var _free_tick: Callable
var _observation_s: Callable
var _appearance_of: Callable
var _sent: Dictionary = {}


## Sources: tick() -> int; ready_of(MonsterAbilities.Ability) -> tick; form_ready() -> tick;
## transform_end() -> tick or -1; lock_end(player) and free_tick(player) -> tick or -1;
## observation_s(survivor) -> float; appearance_of(player) -> CharacterDef appearance id.
func _init(monster: int, survivors: Array[int], tick: Callable, ready_of: Callable, form_ready: Callable,
		transform_end: Callable, lock_end: Callable, free_tick: Callable, observation_s: Callable,
		appearance_of: Callable) -> void:
	_monster = monster
	_survivors = survivors.duplicate()
	_tick = tick
	_ready_of = ready_of
	_form_ready = form_ready
	_transform_end = transform_end
	_lock_end = lock_end
	_free_tick = free_tick
	_observation_s = observation_s
	_appearance_of = appearance_of


## ServerMovement.batch_extras provider: [[EventBatch.MONSTER_HUD, payload]] for the shapeshifter's viewer
## when the payload changed since the last one sent (or `full`, a rejoin); [] for every other viewer.
func entries(viewer: int, full: bool = false) -> Array:
	if viewer != _monster:
		return []
	var p := payload()
	if p == _sent and not full:
		return []
	_sent = p
	return [[EventBatch.MONSTER_HUD, p]]


## The current state, as sent (see EventBatch.MONSTER_HUD).
func payload() -> Dictionary:
	var ready := {FORM_KEY: _form_ready.call()}
	for i in ABILITY_KEYS.size():
		ready[ABILITY_KEYS[i]] = _ready_of.call(i)
	var faces: Array = []
	for s in _survivors:
		faces.append([s, _observation_s.call(s), _appearance_of.call(s)])
	var immune_end: int = _free_tick.call(_monster)
	return {"ready": ready, "transform_end": _transform_end.call(), "stun_end": _lock_end.call(_monster),
		"immune_end": immune_end, "faces": faces}
