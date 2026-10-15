class_name FlinchRecord extends RefCounted
## One camera flinch, freeze or re-baseline of a player's view offset (ADR-0015 §1-3; story
## controller-interaction/013). Yaw and pitch in radians. Only ViewOffset writes one; server and owner
## both evaluate it with offset_at, so they agree to the tick.
## Usage: `var o := FlinchRecord.offset_at(record, float(tick))`

## Id the owner stamps on its input frames once it renders with this record (wraps at 256).
var record_id: int = 0
var from: Vector2 = Vector2.ZERO
var target: Vector2 = Vector2.ZERO
var start_tick: int = 0
## 0 for a freeze or re-baseline: the record holds `from` (== target) at once.
var ramp_ticks: int = 0
## True for a reset (round end, Downed, Hidden, Seized, toggle off): the owner folds `fold` into its
## yaw and pitch and then stamps this record (ADR-0015 §3).
var rebaseline: bool = false
## Re-baseline only: the offset held on the server at the reset tick.
var fold: Vector2 = Vector2.ZERO


## The applied offset at `tick` (whole ticks on the server, render-time ticks on the client). The float
## division matters: int division would jump the ramp from 0 to 1 (ADR-0015 §1).
static func offset_at(r: FlinchRecord, tick: float) -> Vector2:
	var w := clampf((tick - r.start_tick) / float(maxi(r.ramp_ticks, 1)), 0.0, 1.0)
	return r.from.lerp(r.target, smoothstep(0.0, 1.0, w))


## The record as the ViewOffsetChanged payload.
func to_dict() -> Dictionary:
	return {"record_id": record_id, "from": from, "target": target, "start_tick": start_tick,
		"ramp_ticks": ramp_ticks, "rebaseline": rebaseline, "fold": fold}
