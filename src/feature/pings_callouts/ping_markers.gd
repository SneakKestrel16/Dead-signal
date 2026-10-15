class_name PingMarkers extends RefCounted
## Client marker list (story pings-and-callouts/005; design/gdd/pings-and-callouts.md rules 5, 8; ADR-0014:
## the HUD reads only this projected list, fed only by server messages). One marker per delivered
## EventBatch.PING entry, keyed by the server's opaque sender `handle` (PingDelivery.handle_of), never by
## `from`, so two bodies wearing one name stay two markers. A marker is static (the payload point, never
## followed), keeps the identity it was sent under, and expires `ping.ping_lifetime_s` of server ticks after
## the batch tick that delivered it (the accepting tick, PingDelivery). Each handle keeps only its newest
## `ping.ping_max_active` markers. A sender's disconnect sends nothing, so its markers expire normally.
## Usage (client; keep a reference):
##   markers = PingMarkers.new(router, knobs)
##   for m in markers.active(server_tick): draw(m["point"], m["from"])

## Markers oldest first: the delivered payload plus "expires" (the server tick it disappears at).
var _list: Array[Dictionary] = []
var _lifetime: int
var _max_active: int


func _init(router: ClientEventRouter, knobs: Knobs) -> void:
	_lifetime = knobs.ticks(knobs.ping.ping_lifetime_s)
	_max_active = knobs.ping.ping_max_active
	router.subscribe(EventBatch.PING, on_ping)


## ClientEventRouter handler for EventBatch.PING. Untrusted bytes: a payload without an int handle, int
## from and Vector3 point is ignored.
func on_ping(tick: int, payload: Dictionary) -> void:
	if not (payload.get("handle") is int and payload.get("from") is int and payload.get("point") is Vector3):
		return
	var m := payload.duplicate()
	m["expires"] = tick + _lifetime
	_list.append(m)
	var count := 0
	for i in range(_list.size() - 1, -1, -1):
		if _list[i]["handle"] == m["handle"]:
			count += 1
			if count > _max_active:
				_list.remove_at(i)


## The live markers at server tick `now`, oldest first; drops the expired ones. Do not mutate them.
func active(now: int) -> Array[Dictionary]:
	_list = _list.filter(func(m: Dictionary) -> bool: return m["expires"] > now)
	return _list
