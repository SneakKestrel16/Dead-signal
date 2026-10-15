class_name LightingReplication extends RefCounted
## Lighting replication, server side (facility-map story 010; research-facility.md AC 8, 9, 12; ADR-0009 §5,
## following ADR-0004 §4's door rule). A ServerMovement batch_extras provider: per player it remembers the
## last record sent for each volume and, in the send phase, sends [EventBatch.LIGHTING, {volume, base,
## overlays, dark_until}] for each volume in that player's visibility set (its own volume plus the map's
## door-cut `sees` set) whose record differs. Volumes outside the set are not sent, so a Blackout reaches
## only peers that can see it; on re-entry the current record goes out. `full` (a rejoin) re-sends every
## visible volume. One change reaches every viewer in the same tick's reliable batch (AC 8, 12).
## A spectator's stream is projected as its watched survivor, so the change list is kept per player per
## tick and both streams of that tick get it.
## Not here: the extra camera set while viewing the monitor (ADR-0009 §8, surveillance story).
## Usage (composition root; keep a reference, a Callable does not keep this alive):
##   rep = LightingReplication.new(lighting, map, position_of, doors.is_closed, runner.current_tick)
##   sm.batch_extras.append(rep.entries)

## How far below a volume's floor a player still counts as in it, m. Placement tolerance, not a look or a
## rule: parked bodies (not spawned, Out) wait 1000 m below the map, and volume_at reads x and z only.
const BELOW_FLOOR_M := 1.0

var _lighting: FacilityLighting
var _map: MapData
var _queries: MapQueries
var _position: Callable
var _door_closed: Callable
var _tick: Callable
## Passage id -> door net id (doors are the first map interactables; a door's net id is its index).
var _door_ids: Dictionary[StringName, int] = {}
## Player -> {volume: [base, overlays, dark_until]} last sent.
var _sent: Dictionary[int, Dictionary] = {}
## Player -> this tick's entries; cleared when the tick moves on.
var _out: Dictionary[int, Array] = {}
var _out_tick := -1


## `position(player) -> Vector3`: where the player stands (its eye volume decides the set).
## `door_closed(net_id) -> bool`: Doors.is_closed; unset = every door open. `tick() -> int`: the running tick.
func _init(lighting: FacilityLighting, map: MapData, position: Callable, door_closed: Callable, tick: Callable) -> void:
	_lighting = lighting
	_map = map
	_queries = MapQueries.new(map)
	_position = position
	_door_closed = door_closed
	_tick = tick
	var all := map.interactables()
	for i in all.size():
		if all[i] is MapPassage:
			_door_ids[(all[i] as MapPassage).id] = i


## This tick's lighting entries for `player` (see the class doc); `full` re-sends every visible volume.
func entries(player: int, full: bool = false) -> Array:
	var t: int = _tick.call()
	if t != _out_tick:
		_out_tick = t
		_out.clear()
	if _out.has(player) and not full:
		return _out[player]
	var sent: Dictionary = {} if full else _sent.get(player, {})
	var out: Array = []
	for v in _visible(player):
		var rec := [_lighting.base(), _lighting.overlays(v), _lighting.dark_until(v)]
		if sent.get(v) != rec:
			sent[v] = rec
			out.append([EventBatch.LIGHTING, {"volume": v, "base": rec[0], "overlays": rec[1], "dark_until": rec[2]}])
	_sent[player] = sent
	_out[player] = out
	return out


## The player's volume and the volumes it sees through open doors; empty outside every volume, and for a
## body parked below the map (it would otherwise read as the volume above it).
func _visible(player: int) -> PackedStringArray:
	var at: Vector3 = _position.call(player)
	var own := _queries.volume_at(at)
	if own == &"" or at.y < _floor_of(own) - BELOW_FLOOR_M:
		return PackedStringArray()
	var seen := PackedStringArray([own])
	seen.append_array(_queries.visible_set(own, _passage_closed))
	return seen


func _floor_of(volume: StringName) -> float:
	for v in _map.volumes:
		if v.id == volume:
			return v.box.position.y
	return 0.0


func _passage_closed(passage: StringName) -> bool:
	return _door_closed.is_valid() and _door_ids.has(passage) and _door_closed.call(_door_ids[passage])
