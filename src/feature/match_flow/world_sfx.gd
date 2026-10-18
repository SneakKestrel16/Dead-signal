class_name WorldSfx extends RefCounted
## Client world sounds from replicated state (audio pass, design/game-brief.md; entity-inventory.md Audio rows
## 9-10, 25, 34): a door opening or closing and the exit opening (EventBatch.DOORS diffs), a barricade built or
## broken (EventBatch.BARRICADE), a drive docked (ObjectiveProgressChanged) and the Evacuation alarm
## (RoundPhaseChanged). Second audio pass (rows 5, 6, 9, 18, 19, 29): a drive dropped (clatter) or ejected at the
## terminal (clunk), the shapeshifter's install alert cue, the backup relay clacking when a room's Blackout lifts
## (EventBatch.LIGHTING, at the room's switch), the own rescue's relief and an elimination's sting.
## Presentation only; plays through `play(sound, at)` (PlaceholderAudio.play_at, which
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
const CLATTER := &"drive_clatter"
const EJECT := &"drive_eject"
const ALERT := &"install_alert"
const RELAY := &"relay_clack"
const RELIEF := &"rescue_relief"
const ELIMINATED := &"eliminated_sting"

## The local player (SurvivorRescued names the survivor only: the relief is theirs).
var own_id := -1
## `() -> Vector3`: the active terminal (ObjectiveProps.terminal_at), where a docked drive sounds; unset or
## Vector3.INF = at the listener.
var terminal_at: Callable

var _play: Callable
var _listener: Callable
## Door net id -> position (MapData.interactables() order, as DoorBlockers keys them).
var _doors: Array[Vector3] = []
var _exit_at := Vector3.ZERO
var _last: Array = []
var _exit_open := false
var _docked := {}
## Drive objective id -> its last state.
var _drive_state := {}
## Volume id -> its backup switch's position (map `switch` markers).
var _switch_at := {}
## Volume id -> whether its Blackout ran at the last lighting record.
var _dark := {}


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
	for m in map.markers:
		if m.type == &"switch":
			_switch_at[m.volume] = m.position


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


## ClientEventRouter handler for ObjectiveProgressChanged: a drive reaching DOCKED, once per drive; a drive
## dropped by its carrier (clatter) or ejected from the terminal (clunk) where it lands; the install alert
## (shapeshifter only: its payload is the alert circle) at the listener.
func on_objective(_tick: int, p: Dictionary) -> void:
	if p.get("radius_m") is float and p.get("objective") == null:
		_play.call(ALERT, _listener.call())
		return
	var o: Variant = p.get("objective")
	var st: Variant = p.get("state")
	if not (o is int and st is int) or o < SurvivorObjectives.DRIVE_ID or o >= SurvivorObjectives.FUSE_ID:
		return
	## only a Dropped item carries `at` (EvObjectiveProgressChanged); a docked drive sits in the terminal
	var at: Vector3 = p["at"] if p.get("at") is Vector3 else Vector3.INF
	var was: int = _drive_state.get(o, -1)
	_drive_state[o] = st
	if st == SurvivorObjectives.DriveState.DROPPED and at.is_finite():
		if was == SurvivorObjectives.DriveState.CARRIED:
			_play.call(CLATTER, at)
		elif was == SurvivorObjectives.DriveState.DOCKED:
			_play.call(EJECT, at)
	elif st == SurvivorObjectives.DriveState.DOCKED and not _docked.has(o):
		_docked[o] = true
		var t: Vector3 = terminal_at.call() if terminal_at.is_valid() else Vector3.INF
		_play.call(DOCK, at if at.is_finite() else (t if t.is_finite() else _listener.call()))


## ClientEventRouter handler for RoundPhaseChanged: the Evacuation alarm.
func on_phase(_tick: int, p: Dictionary) -> void:
	if p.get("phase") == MatchFlow.Phase.EVACUATION:
		_play.call(ALARM, _listener.call())


## ClientEventRouter handler for EventBatch.LIGHTING ({volume, base, overlays, dark_until}): the relay clack at
## the room's backup switch when its Blackout lifts (by the switch or its timer; inference: the relays switch
## back either way).
func on_lighting(_tick: int, p: Dictionary) -> void:
	var v: Variant = p.get("volume")
	if not (v is StringName or v is String) or not p.get("dark_until") is int:
		return
	var dark: bool = p["dark_until"] != 0
	if _dark.get(StringName(v), false) and not dark and _switch_at.has(StringName(v)):
		_play.call(RELAY, _switch_at[StringName(v)])
	_dark[StringName(v)] = dark


## ClientEventRouter handler for SurvivorRescued ({survivor}): the relief cue, for the rescued player.
func on_rescued(_tick: int, p: Dictionary) -> void:
	if own_id >= 0 and p.get("survivor") == own_id:
		_play.call(RELIEF, _listener.call())


## ClientEventRouter handler for SurvivorEliminated ({survivor, reason}): the elimination sting, for everyone.
func on_eliminated(_tick: int, p: Dictionary) -> void:
	if p.get("survivor") is int:
		_play.call(ELIMINATED, _listener.call())
