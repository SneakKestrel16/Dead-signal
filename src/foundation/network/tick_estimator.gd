class_name TickEstimator extends RefCounted
## Client estimate of the server tick (ADR-0002 rule 7), from snapshot stamps only; no clock-sync protocol.
## Each snapshot gives sample = local_tick - server_tick (clock offset plus that packet's one-way delay).
## The smoothed offset falls fast toward a lower sample (a faster packet is closer to the true path)
## and rises slowly on a higher one, so bursty arrival from a slow host does not jerk it.
## Both clocks advance 1 tick per physics tick, so the offset is constant apart from delay.
## The result is the newest server tick the client could know of on the lowest-delay path.
## Usage: `var e := TickEstimator.new(rise, fall); e.observe(snap_tick, my_tick); e.estimated_server_tick(my_tick)`

var _rise: float
var _fall: float
var _offset: float = 0.0
var _has: bool = false


## `rise_alpha` and `fall_alpha` in (0, 1] come from NetKnobs (tick_estimate_*_alpha).
func _init(rise_alpha: float, fall_alpha: float) -> void:
	_rise = rise_alpha
	_fall = fall_alpha


## Feeds one snapshot's stamp and the local tick it arrived on (fractional ticks allowed).
func observe(server_tick: int, local_tick: float) -> void:
	var sample := local_tick - float(server_tick)
	if not _has:
		_offset = sample
		_has = true
		return
	_offset += (sample - _offset) * (_fall if sample < _offset else _rise)


## False until the first observe().
func has_estimate() -> bool:
	return _has


## Smoothed local-minus-server tick offset.
func offset_ticks() -> float:
	return _offset


## Estimated server tick at `local_tick`. Only meaningful when has_estimate().
func estimated_server_tick(local_tick: float) -> float:
	return local_tick - _offset
