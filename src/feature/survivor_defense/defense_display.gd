class_name DefenseDisplay extends RefCounted
## Client display state of Survivor Defense (story survivor-defense/012; AD-194; ADR-0004 §5): this
## client's own cartridges and hiding spot, every barricadable door's state, and the shocks and stuns
## it was told of. Client only, and decides nothing: it applies EventBatch.CHARGES / HIDING / BARRICADE
## entries and the projected PlayerShocked / MonsterStunned, routed by ClientEventRouter (which drops
## anything not from the server peer). Not a StateRegistry view: it holds received state and mutates.
## A client that reconnects mid-round shows its own charges, hiding spot and doors only from their next
## change (ServerMovement.catch_up has no batch_extras path yet, as with LifeDisplay's ring).
## Usage (client):
##   var defense := DefenseDisplay.new(router)
##   hud.cartridges(defense.charges()); hud.hidden(defense.hiding_spot() != -1)

## Entries with a bad payload.
var rejected: int = 0

var _charges: int = -1
var _spot: int = -1
## door net id -> [barricaded: bool, lockout_end: int]
var _doors: Dictionary[int, Array] = {}
## [type, tick] of the last shock or stun on this client's own body, [] for none.
var _own: Array = []
## body handle -> [type, tick] of the last shock or stun seen on that body.
var _bodies: Dictionary[int, Array] = {}


## Subscribes to `router`'s defense entries and shock events.
func _init(router: ClientEventRouter) -> void:
	router.subscribe(EventBatch.CHARGES, on_charges)
	router.subscribe(EventBatch.HIDING, on_hiding)
	router.subscribe(EventBatch.BARRICADE, on_barricade)
	router.subscribe(&"PlayerShocked", _on_shock.bind(&"PlayerShocked"))
	router.subscribe(&"MonsterStunned", _on_shock.bind(&"MonsterStunned"))


## This client's own cartridges, -1 until the server sent them (the shapeshifter's client never gets any).
func charges() -> int:
	return _charges


## The hiding spot this client's own survivor is in, -1 when not hidden.
func hiding_spot() -> int:
	return _spot


## Whether door `net_id` shows barricaded.
func is_barricaded(net_id: int) -> bool:
	return _doors.has(net_id) and _doors[net_id][0]


## Tick door `net_id`'s rebarricade lockout ends on, -1 when it never broke.
func lockout_end(net_id: int) -> int:
	return _doors[net_id][1] if _doors.has(net_id) else -1


## [type, tick] of the last shock or stun on this client's own body, [] for none.
func own_shock() -> Array:
	return _own


## [type, tick] of the last shock or stun seen on body `handle`, [] for none.
func body_shock(handle: int) -> Array:
	return _bodies.get(handle, [])


## ClientEventRouter handler for EventBatch.CHARGES.
func on_charges(_tick: int, p: Dictionary) -> void:
	var c: Variant = p.get("charges")
	if not (c is int and c >= 0):
		rejected += 1
		return
	_charges = c


## ClientEventRouter handler for EventBatch.HIDING.
func on_hiding(_tick: int, p: Dictionary) -> void:
	var s: Variant = p.get("spot")
	if not (s is int and s >= -1):
		rejected += 1
		return
	_spot = s


## ClientEventRouter handler for EventBatch.BARRICADE.
func on_barricade(_tick: int, p: Dictionary) -> void:
	var d: Variant = p.get("door")
	var on: Variant = p.get("barricaded")
	var end: Variant = p.get("lockout_end")
	if not (d is int and on is bool and end is int):
		rejected += 1
		return
	_doors[d] = [on, end]


func _on_shock(tick: int, p: Dictionary, type: StringName) -> void:
	if p.get("own") == true:
		_own = [type, tick]
	elif p.get("body") is int:
		_bodies[p["body"]] = [type, tick]
	else:
		rejected += 1
