class_name Relevance extends RefCounted
## Which bodies a viewer's client may receive (ADR-0004 §4), computed in the TickRunner send phase.
## A body qualifies when it is in a volume of the viewer's volume's visible set (the Facility Map's
## authored table, already cut by closed doors), shares the viewer's volume, or is within
## relevance_near_m. It stays relevant for relevance_linger_s after it stops qualifying ("lingering").
## A body hidden from the viewer (Survivor Defense: hidden survivors and the monster) never qualifies
## and does not linger. Without a map (volume_at unset) only the near rule applies: fail closed.
## Usage:
##   var rel := Relevance.new(knobs)
##   rel.volume_at = queries.volume_at
##   rel.visible_volumes = func(v: StringName) -> PackedStringArray: return queries.visible_set(v, doors.closed)
##   var bodies := rel.update(tick, viewer, positions)

## Callable(point: Vector3) -> StringName: the volume containing the point, &"" outside every one.
var volume_at: Callable
## Callable(volume_id: StringName) -> PackedStringArray: the door-cut visible set of a volume.
var visible_volumes: Callable
## Callable(viewer: int, body: int) -> bool: true while `body` must not reach `viewer` at all.
var hidden_from: Callable

var _near_sq: float
var _linger_ticks: int
## viewer -> {body: last tick it qualified}
var _last: Dictionary = {}
## viewer -> {body: true} for bodies that qualified on the latest update.
var _now: Dictionary = {}


func _init(knobs: Knobs) -> void:
	_near_sq = knobs.net.relevance_near_m * knobs.net.relevance_near_m
	_linger_ticks = knobs.ticks(knobs.net.relevance_linger_s)


## The bodies relevant to `viewer` at `tick` (qualifying or lingering), in `positions` order.
## `positions` maps player ID -> Vector3 and includes the viewer; the viewer is never in the result.
func update(tick: int, viewer: int, positions: Dictionary) -> Array[int]:
	var last: Dictionary = _last.get_or_add(viewer, {})
	var now := {}
	var out: Array[int] = []
	var eye: Vector3 = positions[viewer]
	var seen := _seen_volumes(eye)
	for body: int in positions:
		if body == viewer:
			continue
		if hidden_from.is_valid() and hidden_from.call(viewer, body):
			last.erase(body)
			continue
		var p: Vector3 = positions[body]
		if eye.distance_squared_to(p) <= _near_sq or (volume_at.is_valid() and seen.has(String(volume_at.call(p)))):
			last[body] = tick
			now[body] = true
		if last.has(body) and tick - int(last[body]) <= _linger_ticks:
			out.append(body)
		else:
			last.erase(body)
	_now[viewer] = now
	return out


## True when `body` was relevant to `viewer` on the latest update only through linger.
func is_lingering(viewer: int, body: int) -> bool:
	var now: Dictionary = _now.get(viewer, {})
	return _last.has(viewer) and (_last[viewer] as Dictionary).has(body) and not now.has(body)


## Ends `body`'s linger for `viewer` at once (a form change during linger, ADR-0004 §3).
func end_linger(viewer: int, body: int) -> void:
	if is_lingering(viewer, body):
		_last[viewer].erase(body)


## Viewers that have had an update.
func viewers() -> Array:
	return _last.keys()


## Forgets the viewer (it left, or its client discarded its puppet map).
func reset_viewer(viewer: int) -> void:
	_last.erase(viewer)
	_now.erase(viewer)


## Forgets `body` for every viewer (it left the round), so a returning ID does not linger.
func forget_body(body: int) -> void:
	for last: Dictionary in _last.values():
		last.erase(body)
	for now: Dictionary in _now.values():
		now.erase(body)


func _seen_volumes(eye: Vector3) -> PackedStringArray:
	if not volume_at.is_valid():
		return PackedStringArray()
	var own: StringName = volume_at.call(eye)
	if own == &"":
		return PackedStringArray()
	var seen := PackedStringArray([own])
	if visible_volumes.is_valid():
		seen.append_array(visible_volumes.call(own))
	return seen
