class_name Doors extends RefCounted
## Door open/closed state (controller story 012; first-person-controller.md rule 18 and the lunge edge
## case; ADR-0007 §5, §8; ADR-0008 §2; systems-index "Door open/closed state", owner Facility Map).
## Every map door is an instant Interactable (duration_s 0, no lock) on the shared HoldService. A
## completed interaction toggles the door on that tick. A close is rejected while any player capsule
## overlaps the door's swing box (MapQueries.capsule_overlaps_swing); an open never is. A dashing
## shapeshifter is one more capsule: it rejects the close only once it is in the swing area, and a door
## closed in front of it stops the dash at the blocker.
## A door Survivor Defense holds shut (set_held_shut: barricaded, story survivor-defense/007) stays closed:
## its open is refused. Not here: barricade state itself (Survivor Defense's Barricades),
## replicating door state to clients (the client applies a received copy with DoorBlockers.apply), and
## a catalog event for a toggle (the catalog has none; readers use the registry view).
## Usage:
##   var doors := Doors.new(holds, map, capsules, can_use)   # before any other interactable registers
##   doors.blockers = DoorBlockers.new(level_root, map)
##   server.start_round({TickOrder.FACILITY_MAP: doors}, knobs)
##   rules = MapQueries.InteractRules.from_knobs(knobs, doors.is_closed)

## Registry view for StateKeys.DOOR_STATE. Holds the module weakly (registry -> view -> module cycle).
class DoorStateView extends RefCounted:
	var _d: WeakRef

	func _init(d: Doors) -> void:
		_d = weakref(d)

	## True while the door with map net id `net_id` is closed.
	func is_closed(net_id: int) -> bool:
		var d := _d.get_ref() as Doors
		return d.is_closed(net_id) if d != null else false


## One door's toggle. Holds the module weakly: HoldService keeps the door and the module keeps
## HoldService (the ObjectivePoint pattern).
class Door extends Interactable:
	var owner: WeakRef
	var index: int

	func eligible(actor: int) -> bool:
		var d := owner.get_ref() as Doors
		return d != null and d.can_use(actor)

	func start_progress_s() -> float:
		return 0.0

	func on_complete(_actor: int) -> void:
		var d := owner.get_ref() as Doors
		if d != null:
			d.toggle(index)

	func on_cancel(_actor: int, _progress_s: float, _reason: StringName) -> void:
		pass


## Blockers this module drives on the server; null = no level geometry (headless rounds).
var blockers: DoorBlockers = null

var _holds: HoldService
var _map: MapData
var _queries: MapQueries
var _capsules: Callable
var _eligible: Callable
## net_id -> bool: true while that door may not open (barricaded); unset = never.
var _held_shut: Callable
var _radius: float
## By map net id (doors come first in MapData.interactables, so a door's net id is its index).
var _closed: Array[bool] = []
var _ids: Array[StringName] = []


## `capsules() -> Array[Vector4]`: every player capsule that takes space (not Out), as
## Vector4(feet x, y, z, capsule height), the PlayerBody.set_low format. `eligible(actor) -> bool` is
## Survivor Defense's door rule (rule 24: anyone; the shock lock says no); absent = anyone.
func _init(holds: HoldService, map: MapData, capsules: Callable, eligible: Callable = Callable()) -> void:
	_holds = holds
	_map = map
	_queries = MapQueries.new(map)
	_capsules = capsules
	_eligible = eligible


## RoundServer entry: registers every door, open (the greybox's start state), and the registry view.
func setup(_tick_runner: Node, _bus: EventBus, registry: StateRegistry, knobs: Knobs) -> void:
	_radius = knobs.controller.player_radius_m
	var rules := MapQueries.InteractRules.from_knobs(knobs)
	_closed = []
	_ids = []
	var targets := _map.interactables()
	for i in targets.size():
		var p := targets[i] as MapPassage
		if p == null:
			break
		var door := Door.new()
		door.owner = weakref(self)
		door.index = i
		door.point = p.position + Vector3.UP * rules.point_height_m ## MapQueries' door point
		door.range_m = rules.door_range_m
		door.duration_s = 0.0
		if _holds.register(door) != i:
			push_error("Doors: door %s got a net id other than its map index %d; register doors first" % [p.id, i])
		_closed.append(false)
		_ids.append(p.id)
	registry.register_view(StateKeys.DOOR_STATE, &"FacilityMap", DoorStateView.new(self))
	_apply()


## Instant interactions only: nothing to advance.
func server_tick(_tick: int) -> void:
	pass


## True while door `net_id` is closed; false for any other id. MapQueries' door_closed callable.
func is_closed(net_id: int) -> bool:
	return net_id >= 0 and net_id < _closed.size() and _closed[net_id]


## Every door's state by net id (true = closed): what the client receives and applies to its blockers.
func closed_states() -> Array[bool]:
	return _closed.duplicate()


## Door rule for `actor` (Survivor Defense); anyone when no rule was injected.
func can_use(actor: int) -> bool:
	return not _eligible.is_valid() or _eligible.call(actor)


## Injects `held_shut(net_id) -> bool` (Survivor Defense rule 26: a barricaded door cannot be opened).
func set_held_shut(source: Callable) -> void:
	_held_shut = source


## Opens a closed door unless it is held shut, or closes an open one unless a capsule overlaps its swing box (rule 18).
## Returns true when the door changed.
func toggle(net_id: int) -> bool:
	if _closed[net_id] and _held_shut.is_valid() and _held_shut.call(net_id):
		return false
	if not _closed[net_id]:
		for c: Vector4 in _capsules.call():
			if _queries.capsule_overlaps_swing(_ids[net_id], Vector3(c.x, c.y + c.w / 2.0, c.z), c.w, _radius):
				return false
	_closed[net_id] = not _closed[net_id]
	_apply()
	return true


func _apply() -> void:
	if blockers != null:
		blockers.apply(_closed)
