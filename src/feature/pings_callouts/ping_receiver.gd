class_name PingReceiver extends RefCounted
## Client side of ping delivery (story pings-and-callouts/004; design/gdd/pings-and-callouts.md rules 2, 7):
## sends this client's ping requests, keeps them as pending until the server answers, and records every
## delivered ping. Decides nothing: the marker list, lifetime and display are stories 005 and 008.
## A rejection (EventBatch.PING_REJECTED, the request echoed) removes that pending request; the server's
## own copy of an accepted ping (own: true) removes the oldest pending request of its kind.
## Usage (client, on the fixed-name round root; keep a reference):
##   pings = PingReceiver.new(router, multiplayer as SceneMultiplayer)
##   pings.request(PingsCallouts.LOCATION, point)

## Delivered ping payloads ({kind, point, item, type, identity, from[, own]}), in arrival order.
var received: Array[Dictionary] = []
## This client's requests not yet answered, as {kind, at, target}, oldest first.
var pending: Array[Dictionary] = []
## Rejection notices received.
var rejections: int = 0

var _smp: SceneMultiplayer


## `smp`: sends requests to the server; null = no sending (tests feed on_ping / on_rejected by hand).
func _init(router: ClientEventRouter, smp: SceneMultiplayer = null) -> void:
	_smp = smp
	router.subscribe(EventBatch.PING, on_ping)
	router.subscribe(EventBatch.PING_REJECTED, on_rejected)


## Sends a ping request and shows it as pending (rule 2).
func request(kind: int, at: Vector3 = Vector3.ZERO, target: int = -1) -> void:
	pending.append({"kind": kind, "at": at, "target": target})
	if _smp != null:
		_smp.send_bytes(PingsCallouts.ping_packet(kind, at, target), 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE)


## ClientEventRouter handler for EventBatch.PING.
func on_ping(_tick: int, payload: Dictionary) -> void:
	received.append(payload)
	if payload.get("own", false):
		for i in pending.size():
			if pending[i]["kind"] == payload.get("kind"):
				pending.remove_at(i)
				break


## ClientEventRouter handler for EventBatch.PING_REJECTED: drops the matching pending request.
func on_rejected(_tick: int, payload: Dictionary) -> void:
	rejections += 1
	pending.erase(payload)
