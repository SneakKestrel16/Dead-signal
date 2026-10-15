class_name SightTest extends RefCounted
## The one server sight test (ADR-0012 §1): range, horizontal cone, then line of sight, in that order.
## Objective discovery uses it (survivor-objectives story 009). Server only; the caller runs it inside
## TickRunner's physics phases. Rays and doors are `line_clear`'s, MapQueries.clear_sight on the server.
## Usage: `SightTest.sees(eye, view.yaw_of(id), points, range_m, fov_deg, sight)`

## Float tolerance so a point exactly on `range_m` counts.
const RANGE_EPS_M := 1e-6


## True when any of `targets` is within `range_m` of `eye`, inside the horizontal cone of `fov_deg`
## centred on `yaw` (radians, 0 faces -Z; no vertical limit, a point straight above or below counts) and
## `line_clear(eye, point) -> bool` passes. Distance first, cone second, the ray last; stops at the first.
static func sees(eye: Vector3, yaw: float, targets: PackedVector3Array, range_m: float, fov_deg: float,
		line_clear: Callable) -> bool:
	var look := ViewState.direction(yaw, 0.0)
	var half := deg_to_rad(fov_deg / 2.0)
	for p in targets:
		if eye.distance_to(p) > range_m + RANGE_EPS_M:
			continue
		var flat := Vector3(p.x - eye.x, 0.0, p.z - eye.z)
		if not flat.is_zero_approx() and look.angle_to(flat) > half:
			continue
		if line_clear.call(eye, p):
			return true
	return false
