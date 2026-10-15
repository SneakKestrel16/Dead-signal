class_name FacilityScareDisplay extends RefCounted
## Client facility scare state, story scare-events/006 (design/gdd/scare-events.md rule 22). Stores the
## server's EventBatch.FACILITY_SCARE record; decides nothing. Presentation (flicker, beds, strobe and
## beacons) is story 009, which reads state() and power_restored().
## Usage (client): `var fsd := FacilityScareDisplay.new(router)`

## Entries with a bad payload.
var rejected: int = 0

var _state: int = FacilityScareState.State.LOW
var _power := false
var _tick := -1


## Subscribes to `router`'s facility scare entries.
func _init(router: ClientEventRouter) -> void:
	router.subscribe(EventBatch.FACILITY_SCARE, on_facility_scare)


## FacilityScareState.State value; LOW until the server said otherwise.
func state() -> int:
	return _state


func power_restored() -> bool:
	return _power


## Server tick of the batch that carried the current record, -1 before any.
func tick() -> int:
	return _tick


## ClientEventRouter handler: {state: int, power: bool}. Server bytes, still validated.
func on_facility_scare(tick_: int, p: Dictionary) -> void:
	var s: Variant = p.get("state")
	var pw: Variant = p.get("power")
	if not s is int or not pw is bool or s < 0 or s >= FacilityScareState.State.size():
		rejected += 1
		return
	_state = s
	_power = pw
	_tick = tick_
