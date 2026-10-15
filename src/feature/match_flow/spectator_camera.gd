class_name SpectatorCamera extends RefCounted
## The spectator view (BUG-0005; match-flow.md rule 10, ADR-0004 §8, ADR-0002 interpolation): while the own
## snapshot entry is another player's (the watched survivor's stream), the camera head sits on that body's
## pose, interpolated like a remote body (RoundClient.sample, interp_delay_ms behind), at eye height and
## the body's yaw. The snapshot carries no pitch, so the view is level (inference: a pitch field on the
## own entry would settle a spectator looking up or down). A switch of the watched survivor drops the
## buffer, so the camera cuts instead of sweeping across the map.
## Usage: `cam.on_own(entry, now_ms)` per own snapshot entry; `cam.place(head, eye_m, at_ms, max_extra_ms)`
## every frame after the head's own rotation is set.

## Entries kept, as RoundClient keeps per remote body.
const BUFFER := 8

var _own_id: int
var _watched := -1
## [local_ms, pos, yaw], oldest first.
var _buf: Array = []


## `own_id`: this client's player id.
func _init(own_id: int) -> void:
	_own_id = own_id


## Records one own snapshot entry received at `now_ms` (local clock).
func on_own(entry: Dictionary, now_ms: float) -> void:
	var id: Variant = entry.get("id")
	if not id is int or id == _own_id:
		_watched = -1
		_buf.clear()
		return
	if id != _watched:
		_watched = id
		_buf.clear()
	_buf.append([now_ms, entry.pos, entry.yaw])
	if _buf.size() > BUFFER:
		_buf.remove_at(0)


## The watched survivor's player id, or -1 when not spectating.
func watched() -> int:
	return _watched


## Puts `head` on the watched body's pose at `at_ms` and returns true; when not spectating, puts it back at
## `eye_m` over its parent and returns false.
func place(head: Node3D, eye_m: float, at_ms: float, max_extra_ms: float) -> bool:
	if _watched < 0 or _buf.is_empty():
		head.position = Vector3(0.0, eye_m, 0.0)
		return false
	var pose := RoundClient.sample(_buf, at_ms, max_extra_ms)
	head.global_position = (pose[0] as Vector3) + Vector3.UP * eye_m
	head.global_rotation = Vector3(0.0, pose[1], 0.0)
	return true
