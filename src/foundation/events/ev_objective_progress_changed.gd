## Emitter: Survivor Objectives
## Any objective state change.
## Field types are inferred from the systems-index.md Meaning column.
class_name EvObjectiveProgressChanged
extends ServerEvent

var objective: int
var state: int


## False while survivors have not discovered this drive room or fuse spawn. Fails closed: an owner
## that forgets to set it hides the point from survivors, never reveals it.
var discovered: bool = false
## Player ID carrying it (drive or fuse CARRIED), -1 otherwise. Survivors' carriers are shown to every
## survivor by name (rule 10); the shapeshifter never carries, so this names a survivor only.
var carrier: int = -1
## Where a Dropped drive or fuse lies (rules 12, 20); not finite (unset) for every other state.
var at: Vector3 = Vector3.INF


func type() -> StringName:
	return &"ObjectiveProgressChanged"


## Install alert (survivor-objectives.md rule 16), set only on a fuse box's INSTALLING event: the
## marked circle's centre, radius and lifetime. alert_radius_m > 0 makes the event an alert.
var alert_centre: Vector3
var alert_radius_m: float = 0.0
var alert_duration_s: float = 0.0


## Shapeshifter: every active point. Survivors: undiscovered drive rooms and fuse spawns omitted
## (ADR-0004 §5). An install alert reaches the shapeshifter alone and names no box: the offset
## circle is all it learns (rule 16, "never pinpoints the box"). The carrier is a survivor's player ID,
## a public fact like survivors' life states (ADR-0004 §5); a dropped item's position names no body.
func project(peer: int, _handles: HandleTable, monster: int) -> Dictionary:
	if alert_radius_m > 0.0:
		if peer != monster:
			return {}
		return {"centre": alert_centre, "radius_m": alert_radius_m, "duration_s": alert_duration_s}
	if peer != monster and not discovered:
		return {}
	var d := {"objective": objective, "state": state, "carrier": carrier}
	if at.is_finite():
		d["at"] = at
	return d
