class_name Surveillance extends Interactable
## The C1 monitor's camera feeds, server side (facility-map story 011; research-facility.md Surveillance;
## ADR-0009 §8). This module is also the monitor station's Interactable (ADR-0008, `duration_s` 0): each
## press cycles the presser's feed camera 1 -> 4 -> off. Any player may view, the shapeshifter included
## (scare-events.md rule 2a), unless `can_view` refuses it (shock lock, Seized, Downed). Leaving the
## monitor's range, starting another hold or losing `can_view` turns the feed off on the next tick.
## While a player views camera N, extra_volumes() adds camera N's volume and its door-cut visibility set
## to that player's relevance, so the bodies on the feed are real and sent with their server appearance:
## a disguised shapeshifter is sent, and drawn, as its disguise. camera_entries() tells only the viewer
## which camera it watches (EventBatch.CAMERA, on change). Not here: lighting records for the camera's
## volumes (story 010's send phase reads extra_volumes) and the impossible-image scare (Scare Events).
## Usage:
##   var cams := Surveillance.new(map, knobs, can_view, centre_of, holds.hold_of, doors.is_closed)
##   holds.register(cams); relevance.extra_volumes = cams.extra_volumes
##   sm.batch_extras.append(cams.camera_entries)
##   server.start_round({TickOrder.SURVEILLANCE: cams}, knobs)

## viewed_camera() when not viewing.
const OFF := -1

var _queries: MapQueries
## Camera markers in map order: index 0 is c1.
var _cameras: Array[MapMarker] = []
var _can_view: Callable
var _centre_of: Callable
var _hold_of: Callable
var _door_closed: Callable
var _off_range_m: float
## player -> camera index, viewers only.
var _viewing: Dictionary[int, int] = {}
## player -> camera index last sent to it (OFF when never sent).
var _sent: Dictionary[int, int] = {}


## `can_view(actor) -> bool`: free to interact (composer: not shock-locked, Seized or Downed).
## `centre_of(actor) -> Vector3`: capsule centre. `hold_of(actor) -> Dictionary`: HoldService.hold_of.
## `door_closed(door: StringName) -> bool`: cuts a camera's visibility set like the viewer's own.
func _init(map: MapData, knobs: Knobs, can_view: Callable, centre_of: Callable, hold_of: Callable,
		door_closed: Callable = Callable()) -> void:
	_queries = MapQueries.new(map)
	_can_view = can_view
	_centre_of = centre_of
	_hold_of = hold_of
	_door_closed = door_closed
	var rules := MapQueries.InteractRules.from_knobs(knobs)
	for m in map.markers:
		if m.type == &"camera":
			_cameras.append(m)
		elif m.type == &"monitor":
			point = m.position + Vector3.UP * rules.point_height_m
	range_m = rules.range_by_type[&"monitor"]
	# Inference: "leaving the monitor's range" uses the hold continuation range (ADR-0008, range_m +
	# hold_range_tolerance_m) so standing at the edge does not flicker the feed; ADR-0009 §8 names no number.
	_off_range_m = range_m + knobs.controller.hold_range_tolerance_m
	duration_s = 0.0
	roots_actor = false
	fakeable = false


## RoundServer entry: round start clears every viewer; RoundEnded clears them again.
func setup(_tick_runner: Node, bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
	_viewing.clear()
	bus.subscribe(&"RoundEnded", _on_round_ended)


## Turns off every feed whose viewer left range, holds something or may no longer view.
func server_tick(_tick: int) -> void:
	for actor: int in _viewing.keys():
		if not _can_view.call(actor) or not (_hold_of.call(actor) as Dictionary).is_empty() \
				or (_centre_of.call(actor) as Vector3).distance_to(point) > _off_range_m:
			_viewing.erase(actor)


## Camera marker ids in feed order (c1..c4).
func camera_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for m in _cameras:
		out.append(m.id)
	return out


## The camera index `actor` views, or OFF.
func viewed_camera(actor: int) -> int:
	return _viewing.get(actor, OFF)


## Relevance.extra_volumes: the viewed camera's volume and its door-cut visibility set, [] when not viewing.
## Inference: a camera's "authored visibility set" (ADR-0009 §8) is its volume's set; the map has no
## per-camera table. A per-camera `sees` in the map file would settle it.
func extra_volumes(actor: int) -> PackedStringArray:
	var n := viewed_camera(actor)
	if n == OFF:
		return PackedStringArray()
	var v := _cameras[n].volume
	var out := _queries.visible_set(v, _door_closed)
	out.append(v)
	return out


## ServerMovement batch provider: [[EventBatch.CAMERA, {camera}]] for `viewer` when its camera changed
## since the last send, or always when `full` (catch-up after a rejoin).
func camera_entries(viewer: int, full: bool = false) -> Array:
	var now := viewed_camera(viewer)
	if not full and _sent.get(viewer, OFF) == now:
		return []
	_sent[viewer] = now
	return [[EventBatch.CAMERA, {"camera": now}]]


func eligible(actor: int) -> bool:
	return _can_view.is_valid() and _can_view.call(actor)


func start_progress_s() -> float:
	return 0.0


## One press: next camera, off after the last.
func on_complete(actor: int) -> void:
	var n := viewed_camera(actor) + 1
	if n >= _cameras.size():
		_viewing.erase(actor)
	else:
		_viewing[actor] = n


func on_cancel(_actor: int, _progress_s: float, _reason: StringName) -> void:
	pass


func _on_round_ended(_e: ServerEvent) -> void:
	_viewing.clear()
