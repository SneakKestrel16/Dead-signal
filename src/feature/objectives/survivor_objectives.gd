class_name SurvivorObjectives extends RefCounted
## Survivor Objectives module, story 001 slice (design/gdd/survivor-objectives.md rules 1-3, 8-10;
## ADR-0008). Owns drive state and carriers (player ids, never nodes). Each active drive console is an
## Interactable on the shared HoldService; its on_complete gives the drive to the extracting survivor and
## emits ObjectiveProgressChanged. HoldService emits nothing. Clients send no completion message: the
## only way to change drive state is the server's own hold timer.
## Not yet here: dropping and pickup (story 002), docking (003), fake holds (007), the registry view of
## drive state (no StateKeys row exists yet).
## Usage:
##   var obj := SurvivorObjectives.new(holds, MapData.load_map(), func(p: int) -> bool: return true)
##   server.start_round({TickOrder.SURVIVOR_OBJECTIVES: obj}, knobs)

enum DriveState { SECURED, CARRIED, DROPPED, DOCKED, EXTRACTED }

## Active drive rooms for now: the first two authored drive markers. Placeholder until story 008
## (random active point selection, ADR-0012, Proposed) replaces it.
const ACTIVE_DRIVES := 2

## `ObjectiveProgressChanged.objective` id ranges, so one int names one point across kinds: drives
## DRIVE_ID + index; later stories take FUSE_ID (fuses), FUSE_BOX_ID (boxes) and TERMINAL_ID.
const DRIVE_ID := 0
const FUSE_ID := 10
const FUSE_BOX_ID := 20
const TERMINAL_ID := 30

var _holds: HoldService
var _map: MapData
var _is_healthy: Callable
var _bus: EventBus
var _knobs: Knobs
## Active drive index -> state / carrier player id (-1 = none). Index is the event's `objective`.
var _states: Array[DriveState] = []
var _carriers: Array[int] = []
var _marker_ids: Array[StringName] = []


## `is_healthy(actor: int) -> bool` is the life-state source (Downing's view once it exists); pass an
## invalid Callable to treat everyone as Healthy.
func _init(holds: HoldService, map: MapData, is_healthy: Callable = Callable()) -> void:
	_holds = holds
	_map = map
	_is_healthy = is_healthy


## RoundServer entry: builds the active drives and registers their consoles.
func setup(_tick_runner: Node, bus: EventBus, _registry: StateRegistry, knobs: Knobs) -> void:
	_bus = bus
	_knobs = knobs
	_states = []
	_carriers = []
	_marker_ids = []
	for m: MapMarker in _map.markers:
		if m.type != &"drive" or _marker_ids.size() >= ACTIVE_DRIVES:
			continue
		var c := DriveConsole.new()
		c.owner = weakref(self)
		c.index = _marker_ids.size()
		c.point = m.position
		c.range_m = knobs.objectives.interact_range_m
		c.duration_s = knobs.objectives.drive_extract_s
		c.lock_key = StringName("drive_%s" % m.id)
		_marker_ids.append(m.id)
		_states.append(DriveState.SECURED)
		_carriers.append(-1)
		_holds.register(c)
	if _states.size() < ACTIVE_DRIVES:
		push_error("SurvivorObjectives: map has %d drive markers, needs %d" % [_states.size(), ACTIVE_DRIVES])


## Holds are timed in the Holds step; nothing to do per tick yet.
func server_tick(_tick: int) -> void:
	pass


## Number of active drives.
func drive_count() -> int:
	return _states.size()


## State of active drive `index`.
func state_of(index: int) -> DriveState:
	return _states[index]


## Player id carrying drive `index`, -1 if nobody.
func carrier_of(index: int) -> int:
	return _carriers[index]


## How many drives `actor` carries.
func carried_by(actor: int) -> int:
	return _carriers.count(actor)


func _can_extract(index: int, actor: int) -> bool:
	if _states[index] != DriveState.SECURED:
		return false
	if _is_healthy.is_valid():
		var healthy: bool = _is_healthy.call(actor)
		if not healthy:
			return false
	return carried_by(actor) < _knobs.objectives.max_drives_carried


func _complete(index: int, actor: int) -> void:
	if not _can_extract(index, actor):
		return
	_states[index] = DriveState.CARRIED
	_carriers[index] = actor
	var e := EvObjectiveProgressChanged.new()
	e.objective = DRIVE_ID + index
	e.state = DriveState.CARRIED
	e.discovered = true ## the extractor was in the room; a carried drive is shown to every survivor (rule 10)
	_bus.emit(e)


## The drive console (GDD rule 8). Progress is not kept: a cancelled hold resets (start_progress_s 0).
## Holds its module weakly: HoldService keeps the console, and the module keeps HoldService, so a strong
## back-reference would be a RefCounted cycle that outlives the round.
class DriveConsole extends Interactable:
	var owner: WeakRef = null
	var index: int = 0

	## Healthy, drive still Secured, carrier under the cap.
	func eligible(actor: int) -> bool:
		var m: SurvivorObjectives = owner.get_ref()
		return m != null and m._can_extract(index, actor)

	## Reset rule: every hold starts from 0.
	func start_progress_s() -> float:
		return 0.0

	## Gives the drive to `actor`.
	func on_complete(actor: int) -> void:
		var m: SurvivorObjectives = owner.get_ref()
		if m != null:
			m._complete(index, actor)

	func on_cancel(_actor: int, _progress_s: float, _reason: StringName) -> void:
		pass
