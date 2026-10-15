class_name FlinchRecord extends RefCounted
## One camera flinch, freeze or re-baseline of a player's view offset (ADR-0015 §1-3; story
## controller-interaction/013). Yaw and pitch in radians. Only ViewOffset writes one; server and owner
## both evaluate it with offset_at, so they agree to the tick.
## Usage: `var o := FlinchRecord.offset_at(record, float(tick))`

## Id the owner stamps on its input frames once it renders with this record (wraps at 256).
var record_id: int = 0
## The view epoch the record belongs to (wraps at 256). A re-baseline starts a new one; the owner stamps
## it on every input frame once it has folded (ADR-0015 §3).
var view_epoch: int = 0
var from: Vector2 = Vector2.ZERO
var target: Vector2 = Vector2.ZERO
var start_tick: int = 0
## 0 for a freeze or re-baseline: the record holds `from` (== target) at once.
var ramp_ticks: int = 0
## True for a reset (round end, Downed, Hidden, Seized, toggle off): the owner folds `fold` into its
## yaw and pitch and then stamps this record and its epoch (ADR-0015 §3).
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
	return {"record_id": record_id, "view_epoch": view_epoch, "from": from, "target": target,
		"start_tick": start_tick, "ramp_ticks": ramp_ticks, "rebaseline": rebaseline, "fold": fold}


## Client: the record from a ViewOffsetChanged payload, or null when any field is missing or mistyped
## (the payload is decoded bytes; a bad one is ignored, never half-applied).
static func from_dict(d: Dictionary) -> FlinchRecord:
	if not (d.get("record_id") is int and d.get("view_epoch") is int and d.get("from") is Vector2
			and d.get("target") is Vector2 and d.get("start_tick") is int and d.get("ramp_ticks") is int
			and d.get("rebaseline") is bool and d.get("fold") is Vector2):
		return null
	var r := FlinchRecord.new()
	r.record_id = d.record_id
	r.view_epoch = d.view_epoch
	r.from = d.from
	r.target = d.target
	r.start_tick = d.start_tick
	r.ramp_ticks = d.ramp_ticks
	r.rebaseline = d.rebaseline
	r.fold = d.fold
	return r
