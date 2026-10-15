class_name FlashLimiter extends RefCounted
## One client-side cap on luminance flashes (ADR-0015 §6; scare-events.md rule 25; story
## controller-interaction/013): admits a flash only while fewer than `max_flashes_per_s` were admitted in
## the last second, counting scare flashes and the lighting flicker precompute together (ADR-0009's clamp
## calls it too). A refused flash plays as a dim.
## ponytail: lives with Scare Events; move it to a lower layer when the Facility flicker precompute
## (core) starts calling it.
## Usage: `var l := FlashLimiter.new(knobs.facility.max_flashes_per_s); if l.try_flash(now_s): ...`

var _max: int
## Admitted flash times (seconds), oldest first.
var _times: Array[float] = []


func _init(max_flashes_per_s: int) -> void:
	_max = max_flashes_per_s


## True, and counted, when fewer than the cap were admitted in the second before `now_s` (a flash exactly
## one second old no longer counts).
func try_flash(now_s: float) -> bool:
	while not _times.is_empty() and _times[0] <= now_s - 1.0:
		_times.pop_front()
	if _times.size() >= _max:
		return false
	_times.append(now_s)
	return true
