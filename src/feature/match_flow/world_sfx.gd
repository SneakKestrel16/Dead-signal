class_name WorldSfx extends RefCounted
## Client world sounds from replicated state (audio pass, design/game-brief.md; entity-inventory.md Audio rows
## 9-10, 25, 34): a door opening or closing and the exit opening (EventBatch.DOORS diffs), a barricade built or
## broken (EventBatch.BARRICADE), a drive docked (ObjectiveProgressChanged) and the Evacuation alarm
## (RoundPhaseChanged). Presentation only; plays through `play(sound, at)` (PlaceholderAudio.play_at, which
## takes the SoundBank entry). The first doors snapshot is the baseline: a client joining sees doors as they
## are, silently. Inference: the alarm plays once at the listener (facility-wide, non-directional); the
## looping Evacuation bed with PA countdown stays with the M4 audio pass.
## Usage (client):
##   var w := WorldSfx.new(map, audio.play_at, camera.get_global_position)
##   router.subscribe(EventBatch.DOORS, w.on_doors); router.subscribe(EventBatch.BARRICADE, w.on_barricade)
##   router.subscribe(&"ObjectiveProgressChanged", w.on_objective); router.subscribe(&"RoundPhaseChanged", w.on_phase)

const DOOR_OPEN := &"door_open"
const DOOR_CLOSE := &"door_close"
const BARRICADE_BUILD := &"barricade_build"
const BARRICADE_BREAK := &"barricade_break"
const DOCK := &"objective_dock"
const ALARM := &"objective_alarm"

var _play: Callable
var _listener: Callable
## Door net id -> position (MapData.interactables() order, as DoorBlockers keys them).
var _doors: Array[Vector3] = []
var _exit_at := Vector3.ZERO
var _last: Array = []
var _exit_open := false
var _docked := {}


## `play(sound: StringName, at: Vector3)`; `listener() -> Vector3` where non-positional sounds play.
func _init(map: MapData, play: Callable, listener: Callable) -> void:
	_play = play
	_listener = listener
	for t in map.interactables():
		if t is MapPassage:
			_doors.append((t as MapPassage).position)
	for p in map.passages:
		if p.kind == MapPassage.EXIT:
			_exit_at = p.position


## Doors this map replicates.
func door_count() -> int:
	return _doors.size()


## ClientEventRouter handler for EventBatch.DOORS ({closed: Array of bool per door, exit: bool}).
func on_doors(_tick: int, payload: Dictionary) -> void:
	var closed: Variant = payload.get("closed")
	var exit: Variant = payload.get("exit")
	if not (closed is Array and exit is bool) or (closed as Array).size() != _doors.size():
		return
	for c: Variant in closed:
		if not c is bool:
			return
	if not _last.is_empty():
		for i in _doors.size():
			if closed[i] != _last[i]:
				_play.call(DOOR_CLOSE if closed[i] else DOOR_OPEN, _doors[i])
		if exit and not _exit_open:
			_play.call(DOOR_OPEN, _exit_at)
	_last = (closed as Array).duplicate()
	_exit_open = exit


## ClientEventRouter handler for EventBatch.BARRICADE ({door, barricaded}).
func on_barricade(_tick: int, payload: Dictionary) -> void:
	var door: Variant = payload.get("door")
	var on: Variant = payload.get("barricaded")
	if door is int and on is bool and door >= 0 and door < _doors.size():
		_play.call(BARRICADE_BUILD if on else BARRICADE_BREAK, _doors[door])


## ClientEventRouter handler for ObjectiveProgressChanged: a drive reaching DOCKED, once per drive.
func on_objective(_tick: int, p: Dictionary) -> void:
	var o: Variant = p.get("objective")
	var at: Variant = p.get("at")
	if not (o is int and p.get("state") is int and at is Vector3):
		return
	if o >= SurvivorObjectives.DRIVE_ID and o < SurvivorObjectives.FUSE_ID \
			and p["state"] == SurvivorObjectives.DriveState.DOCKED and not _docked.has(o):
		_docked[o] = true
		_play.call(DOCK, at)


## ClientEventRouter handler for RoundPhaseChanged: the Evacuation alarm.
func on_phase(_tick: int, p: Dictionary) -> void:
	if p.get("phase") == MatchFlow.Phase.EVACUATION:
		_play.call(ALARM, _listener.call())
