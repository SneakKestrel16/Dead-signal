class_name Barricades extends RefCounted
## Barricade state on barricadable doors (design/gdd/survivor-defense.md rules 24-26, 28a and the
## "barricade completes while the monster is in the doorway" edge case; story survivor-defense/007;
## ADR-0008 holds and locks; systems-index "Barricade state", owner Survivor Defense). Server only.
## Each barricadable door gets two BarricadeHolds on the shared HoldService, Barricade and Remove,
## on the door's one exclusive lock_key (Break, story 008, takes the same key). The barricade extends
## the door's state, it is not a second one: only a closed door can be barricaded, and while barricaded
## Doors refuses to open it (Doors.set_held_shut), so its blocker and every door_closed reader already
## treat it as closed. A completed hold is the only way in: no client message completes a barricade.
## Not here: break, lockout, BarricadeBroken (story 008); the shock lock gate (story 003, through
## `healthy`); which input selects Barricade over the door toggle (the aim callable must resolve to
## build_id / remove_id; unwired, see the story's deviations).
## Usage:
##   var bars := Barricades.new(holds, doors, map, healthy_survivor, monster_capsules)
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


## `healthy(actor) -> bool`: a Healthy survivor (rule 25; Downing.action_locked and the shock lock
## fold in here). `monster_capsules() -> Array[Vector4]`: the monster's capsule as Doors' capsule format,
## empty when it takes no space.
func _init(holds: HoldService, doors: Doors, map: MapData, healthy: Callable, monster_capsules: Callable) -> void:
	_holds = holds
	_doors = doors
	_map = map
	_queries = MapQueries.new(map)
	_healthy = healthy
	_monster_capsules = monster_capsules


## RoundServer entry: registers Barricade and Remove on every barricadable door, unbarricaded, and the
## registry view; makes Doors refuse to open a barricaded door.
func setup(_tick_runner: Node, _bus: EventBus, registry: StateRegistry, knobs: Knobs) -> void:
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


## True while door `net_id` is barricaded.
func is_barricaded(net_id: int) -> bool:
	return _barricaded.has(net_id)


## Rule 25: a Healthy survivor on a closed, unbarricaded barricadable door.
func can_build(actor: int, net_id: int) -> bool:
	return _build.has(net_id) and not is_barricaded(net_id) and _doors.is_closed(net_id) and _healthy.call(actor)


## Rule 26: a survivor on a barricaded door. Inference: "Survivor" in rule 28a, read as the same
## Healthy gate (a Downed or Seized survivor interacts with nothing); a designer ruling settles it.
func can_remove(actor: int, net_id: int) -> bool:
	return is_barricaded(net_id) and _healthy.call(actor)


## A hold completed (HoldService only). Build fails while the monster is in the doorway (edge case:
## "No trapping the monster"); progress is not kept. Returns true when the state changed.
func complete(net_id: int, remove: bool) -> bool:
	if remove:
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
