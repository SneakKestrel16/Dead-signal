class_name ScareRelevance extends RefCounted
## Shared-scare recipients, story scare-events/003 (design/gdd/scare-events.md rule 19; ADR-0004 §5). A
## candidate is relevant when its listener point is within the entry's authored audible_range_m of the origin
## (straight line, inclusive) or has line of sight to the origin through the shared SightTest (facing and
## range ignored: rule 19 names neither). Server only; run it inside TickRunner's physics phases.
## A single-client scare (rule 20) names its one target itself and does not come through here.
## Inference: rule 19's "inside the affected room/zone" is covered by the range test, the GDD's proposed
## relevance being "audible range or line of sight"; a designer call on a zone clause would settle it.
## Usage:
##   var rel := ScareRelevance.new(eye_of, clear_sight)
##   scares.fire(id, origin, rel.recipients(entry, origin, live_players), source, player)

var _point: Callable
var _clear: Callable


## `point(id) -> Vector3` the listener's ear/eye; `line_clear(from, to) -> bool` MapQueries.clear_sight.
func _init(point: Callable, line_clear: Callable) -> void:
	_point = point
	_clear = line_clear


## The members of `candidates` (player ids) relevant to shared `entry` at `origin`, in candidate order.
func recipients(entry: ScareEntry, origin: Vector3, candidates: Array) -> Array[int]:
	var out: Array[int] = []
	var at := PackedVector3Array([origin])
	for id: int in candidates:
		var p: Vector3 = _point.call(id)
		if p.distance_to(origin) <= entry.audible_range_m + SightTest.RANGE_EPS_M \
				or SightTest.sees(p, 0.0, at, INF, INF, _clear):
			out.append(id)
	return out
