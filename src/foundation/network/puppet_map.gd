class_name PuppetMap extends RefCounted
## Client side of per-peer handles (ADR-0004 §2-3): the remote bodies this client may show, keyed by
## the handles the server introduced. A snapshot entry under a handle not introduced (or already
## retired) is ignored and counted. The own entry is OwnerPredictor's and is skipped here. Puppet
## nodes (named by a client-local counter, never by handle) are built from state_of() by the
## presentation layer; this class holds data only.
## Usage: `var puppets := PuppetMap.new(smp)`; then `for h in puppets.handles(): puppets.state_of(h)`

const SERVER_PEER := 1

## Snapshot entries dropped because their handle was not introduced.
var ignored_entries: int = 0
## Packets that failed to decode.
var bad_packets: int = 0

var _smp: SceneMultiplayer
## handle -> latest snapshot entry ({} until the first snapshot after its introduce)
var _bodies: Dictionary = {}
var _last_tick: int = -1


## `smp`: listen on its peer_packet; null = call receive() by hand (tests).
func _init(smp: SceneMultiplayer = null) -> void:
	_smp = smp
	if _smp != null:
		_smp.peer_packet.connect(_on_packet)


## Stops listening. Safe to call twice.
func close() -> void:
	if _smp != null and _smp.peer_packet.is_connected(_on_packet):
		_smp.peer_packet.disconnect(_on_packet)


## Applies a handle message or a snapshot from the server.
func receive(bytes: PackedByteArray) -> void:
	if HandleTable.is_message(bytes):
		var msgs := HandleTable.decode(bytes)
		if msgs.is_empty():
			bad_packets += 1
		for i in range(0, msgs.size(), 2):
			if msgs[i] == HandleTable.INTRODUCE:
				_bodies[msgs[i + 1]] = {}
			else:
				_bodies.erase(msgs[i + 1])
		return
	var snap := SnapshotCodec.decode(bytes)
	if snap.is_empty():
		bad_packets += 1
		return
	if snap.tick <= _last_tick:
		return
	_last_tick = snap.tick
	for b: Dictionary in snap.bodies:
		if b.get("own", false):
			continue
		if _bodies.has(b.id):
			_bodies[b.id] = b
		else:
			ignored_entries += 1


## Introduced handles, live now.
func handles() -> Array:
	return _bodies.keys()


## True while `handle` is introduced and not retired.
func has(handle: int) -> bool:
	return _bodies.has(handle)


## The latest snapshot entry for `handle` ({} before its first snapshot).
func state_of(handle: int) -> Dictionary:
	return _bodies.get(handle, {})


## Discards every handle (reconnect, spectator switch; ADR-0004 §8-9).
func reset() -> void:
	_bodies.clear()
	_last_tick = -1


func _on_packet(peer_id: int, bytes: PackedByteArray) -> void:
	if peer_id == SERVER_PEER:
		receive(bytes)
