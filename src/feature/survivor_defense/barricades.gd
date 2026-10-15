class_name Barricades extends RefCounted
## Barricade state on barricadable doors (design/gdd/survivor-defense.md rules 24-26, 28a and the
## "barricade completes while the monster is in the doorway" edge case; story survivor-defense/007;
## ADR-0008 holds and locks; systems-index "Barricade state", owner Survivor Defense). Server only.
## Each barricadable door gets two BarricadeHolds on the shared HoldService, Barricade and Remove,
## on the door's one exclusive lock_key, plus a BarricadeBreak (story 008) on the same key. The barricade extends
## the door's state, it is not a second one: only a closed door can be barricaded, and while barricaded
## Doors refuses to open it (Doors.set_held_shut), so its blocker and every door_closed reader already
## treat it as closed. A completed hold is the only way in: no client message completes a barricade.
## Story 008: break time accumulates per door across holds (kept on any cancel, a stun included) and
## clears on removal or break; a break emits BarricadeBroken and locks the door out of Barricade for
## rebarricade_lockout_s, read against the TickRunner's current tick.
## Not here: the shock lock gate (story 003, through `healthy` and `monster`); which input selects Barricade over the door toggle (the aim callable must resolve to
## build_id / remove_id; unwired, see the story's deviations).
## Usage:
##   var bars := Barricades.new(holds, doors, map, healthy_survivor, monster_capsules, monster)
##   bars.setup(tick_runner, bus, registry, knobs)   # after Doors.setup (doors take the first net ids)

## Getter-only registry view for StateKeys.BARRICADE_STATE. Holds the module weakly.
class BarricadeView extends RefCounted:
	var _b: WeakRef

	func _init(b: Barricades) -> void:
		_b = weakref(b)

	## True while door `net_id` is barricaded.
	func is_barricaded(net_id: int) -> bool:
		var b := _b.get_ref() as Barricades
		return b.is_barricaded(net_id) if b != null else false


var _holds: HoldService
var _doors: Doors
var _map: MapData
var _queries: MapQueries
var _healthy: Callable
var _monster_capsules: Callable
var _radius: float
## door net id -> true while barricaded.
var _barricaded: Dictionary[int, bool] = {}
## door net id -> Barricade / Remove interactable net id.
var _build: Dictionary[int, int] = {}
var _remove: Dictionary[int, int] = {}
## door net id -> Break interactable net id.
var _break: Dictionary[int, int] = {}
var _monster: Callable
var _bus: EventBus
var _runner: TickRunner
var _lockout_ticks: int
## door net id -> stored break time, s (rule 27).
var _break_s: Dictionary[int, float] = {}
## door net id -> tick the barricade broke on (rule 28 lockout).
var _broken_at: Dictionary[int, int] = {}
## AD-194 barricade replication: door -> [barricaded, lockout_end] last sent; this tick's entries; tick diffed.
var _sent: Dictionary[int, Array] = {}
var _out: Array = []
var _out_tick: int = -1


## `healthy(actor) -> bool`: a Healthy survivor (rule 25; Downing.action_locked and the shock lock
## fold in here). `monster_capsules() -> Array[Vector4]`: the monster's capsule as Doors' capsule format,
## empty when it takes no space. `monster(actor) -> bool`: the monster, any form, free to act (the stun
## lock folds in here); unset = nobody breaks.
func _init(holds: HoldService, doors: Doors, map: MapData, healthy: Callable, monster_capsules: Callable,
		monster: Callable = Callable()) -> void:
	_holds = holds
	_doors = doors
	_map = map
	_queries = MapQueries.new(map)
	_healthy = healthy
	_monster_capsules = monster_capsules
	_monster = monster


## RoundServer entry: registers Barricade and Remove on every barricadable door, unbarricaded, and the
## registry view; makes Doors refuse to open a barricaded door.
func setup(tick_runner: TickRunner, bus: EventBus, registry: StateRegistry, knobs: Knobs) -> void:
	_runner = tick_runner
	_bus = bus
	_lockout_ticks = knobs.ticks(knobs.defense.rebarricade_lockout_s)
	_break = {}
	_break_s = {}
	_broken_at = {}
	_sent = {}
	_out = []
	_out_tick = -1
	_radius = knobs.controller.player_radius_m
	var rules := MapQueries.InteractRules.from_knobs(knobs)
	_barricaded = {}
	_build = {}
	_remove = {}
	var targets := _map.interactables()
	for i in targets.size():
		var p := targets[i] as MapPassage
		if p == null or p.kind != MapPassage.BARRICADABLE:
			continue
		for remove: bool in [false, true]:
			var h := BarricadeHold.new()
			h.owner = weakref(self)
			h.door = i
			h.remove = remove
			h.point = p.position + Vector3.UP * rules.point_height_m ## the door's own point
			h.range_m = rules.door_range_m
			h.duration_s = knobs.defense.barricade_remove_s if remove else knobs.defense.barricade_duration_s
			h.lock_key = lock_key(i)
			(_remove if remove else _build)[i] = _holds.register(h)
		var brk := BarricadeBreak.new()
		brk.owner = weakref(self)
		brk.door = i
		brk.point = p.position + Vector3.UP * rules.point_height_m
		brk.range_m = rules.door_range_m
		brk.duration_s = knobs.defense.barricade_break_s
		brk.roots_actor = true
		brk.lock_key = lock_key(i)
		_break[i] = _holds.register(brk)
	_doors.set_held_shut(is_barricaded)
	registry.register_view(StateKeys.BARRICADE_STATE, &"SurvivorDefense", BarricadeView.new(self))


## Timed by HoldService: nothing to advance.
func server_tick(_tick: int) -> void:
	pass


## Rule 28a: the one exclusive lock of door `net_id`, shared by Barricade, Remove and Break.
static func lock_key(net_id: int) -> StringName:
	return StringName("door_%d" % net_id)


## Net id of door `net_id`'s Barricade interactable, -1 when it is not barricadable.
func build_id(net_id: int) -> int:
	return _build.get(net_id, -1)


## Net id of door `net_id`'s Remove barricade interactable, -1 when it is not barricadable.
func remove_id(net_id: int) -> int:
	return _remove.get(net_id, -1)


## Net id of door `net_id`'s Break interactable, -1 when it is not barricadable.
func break_id(net_id: int) -> int:
	return _break.get(net_id, -1)


## True while door `net_id` is barricaded.
func is_barricaded(net_id: int) -> bool:
	return _barricaded.has(net_id)


## Rule 25: a Healthy survivor on a closed, unbarricaded barricadable door; rule 28: not until
## rebarricade_lockout_s after a break (allowed on the tick it runs out).
func can_build(actor: int, net_id: int) -> bool:
	return _build.has(net_id) and not is_barricaded(net_id) and _doors.is_closed(net_id) 		and _now() >= _broken_at.get(net_id, -_lockout_ticks) + _lockout_ticks and _healthy.call(actor)


## Rule 27: the monster, in any form, on a barricaded door. Survivors never.
func can_break(actor: int, net_id: int) -> bool:
	return is_barricaded(net_id) and _monster.is_valid() and _monster.call(actor)


## Rule 28: the tick door `net_id`'s rebarricade lockout ends on, -1 when it never broke.
func lockout_end(net_id: int) -> int:
	return _broken_at[net_id] + _lockout_ticks if _broken_at.has(net_id) else -1


## ServerMovement.batch_extras provider (story 012, AD-194: a barricade is a world object, so everyone):
## [EventBatch.BARRICADE, {door, barricaded, lockout_end}] for every door whose state changed (built,
## removed, broken) since the last batch. Diffed once per tick; the same entries for every viewer.
## `full` (a rejoin, story match-flow/012): every door's current state, leaving the diff untouched.
func barricade_entries(_viewer: int, full: bool = false) -> Array:
	if _runner == null:
		return []
	if full:
		var all: Array = []
		for d: int in _build:
			all.append([EventBatch.BARRICADE, {"door": d, "barricaded": is_barricaded(d), "lockout_end": lockout_end(d)}])
		return all
	if _out_tick != _runner.current_tick():
		_out_tick = _runner.current_tick()
		_out = []
		for d: int in _build:
			var now := [is_barricaded(d), lockout_end(d)]
			if _sent.get(d, [false, -1]) != now:
				_sent[d] = now
				_out.append([EventBatch.BARRICADE, {"door": d, "barricaded": now[0], "lockout_end": now[1]}])
	return _out


## Rule 27: break time door `net_id` has taken so far, s.
func break_progress_s(net_id: int) -> float:
	return _break_s.get(net_id, 0.0)


## A Break hold ended early (HoldService only): its progress persists while the barricade stands.
func keep_break_progress(net_id: int, progress_s: float) -> void:
	if is_barricaded(net_id):
		_break_s[net_id] = progress_s


## A Break hold completed (HoldService only): the barricade is gone, the door stays closed, the
## lockout starts and BarricadeBroken is emitted (ADR-0005).
func break_barricade(net_id: int) -> void:
	if not _barricaded.erase(net_id):
		return
	_break_s.erase(net_id)
	_broken_at[net_id] = _now()
	if _bus != null:
		var e := EvBarricadeBroken.new()
		e.barricade = net_id
		_bus.emit(e)


## Rule 26: a survivor on a barricaded door. Inference: "Survivor" in rule 28a, read as the same
## Healthy gate (a Downed or Seized survivor interacts with nothing); a designer ruling settles it.
func can_remove(actor: int, net_id: int) -> bool:
	return is_barricaded(net_id) and _healthy.call(actor)


## A hold completed (HoldService only). Build fails while the monster is in the doorway (edge case:
## "No trapping the monster"); progress is not kept. Returns true when the state changed.
func complete(net_id: int, remove: bool) -> bool:
	if remove:
		_break_s.erase(net_id)
		return _barricaded.erase(net_id)
	if not _doors.is_closed(net_id) or _monster_in_doorway(net_id):
		return false
	_barricaded[net_id] = true
	return true


## Inference: "the doorway" read as the door's swing box (the area a close already checks); the map
## file naming a doorway volume would settle it.
func _monster_in_doorway(net_id: int) -> bool:
	var id := (_map.interactables()[net_id] as MapPassage).id
	for c: Vector4 in _monster_capsules.call():
		if _queries.capsule_overlaps_swing(id, Vector3(c.x, c.y + c.w / 2.0, c.z), c.w, _radius):
			return true
	return false


func _now() -> int:
	return _runner.current_tick() if _runner != null else 0
