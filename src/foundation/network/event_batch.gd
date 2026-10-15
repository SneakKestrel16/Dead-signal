class_name EventBatch extends RefCounted
## One tick's events for one viewer (ADR-0004 §5-6): every delivered catalog event projected for that
## viewer (`{}` dropped), plus the positional sounds in its range. Sent reliable on NetChannels.EVENT,
## after that tick's handle messages, so every handle a payload names is already introduced.
## Sounds carry position and sound set only, never a handle or player ID.
## Usage (server, snapshot phase):
##   var bytes := EventBatch.build(tick, viewer, events, sounds, viewer_pos, handles, monster)
##   if not bytes.is_empty(): smp.send_bytes(bytes, peer, RELIABLE, NetChannels.EVENT)
## Client: `if EventBatch.is_message(bytes): var b := EventBatch.decode(bytes)`

## First byte. HandleTable.TAG is 0xF1 and a snapshot starts with SnapshotCodec.VERSION.
const TAG := 0xF2
## Entry type of a positional sound (not a catalog event name).
const SOUND := &"Sound"
## Entry type of a Downed survivor's bleed-out ring (Downing.ring_entries, story downing-and-rescue/007):
## {survivor, remaining_s, rate}. Not a catalog event; its provider sends it to survivor viewers only.
const BLEED_RING := &"BleedRing"
## Entry type of the viewer's own taser cartridges (SurvivorDefense.charge_entries, story
## survivor-defense/012, AD-194): {charges}. Not a catalog event; sent to the owner only, on change.
const CHARGES := &"Charges"
## Entry type of the viewer's own hiding spot (HidingSpots.hiding_entries, AD-194): {spot}, -1 when it
## left or was ejected. Not a catalog event; sent to the occupant only, on change.
const HIDING := &"Hiding"
## Entry type of a barricadable door's state (Barricades.barricade_entries, AD-194): {door, barricaded,
## lockout_end} (lockout_end the tick rule 28's lockout ends, -1 when it never broke). Sent to everyone.
const BARRICADE := &"Barricade"


## A positional sound queued for this tick. `source` is server-only: the emitter's own client plays
## its own sounds locally (prediction), so it is skipped; it never enters a payload.
class Sound extends RefCounted:
	var position: Vector3
	## Sound or voice set; a disguised monster's footsteps use its target's set (Borrowed Face, owner's choice).
	var sound_set: StringName
	var radius_m: float
	var source: int = -1


## The viewer's batch, or empty bytes when nothing reaches it (no empty batch is sent). `extra` holds
## [type, payload] entries already projected for this viewer by their provider (ServerMovement.batch_extras).
static func build(tick: int, viewer: int, events: Array[ServerEvent], sounds: Array[Sound],
		viewer_pos: Vector3, handles: HandleTable, monster: int, extra: Array = []) -> PackedByteArray:
	var entries: Array = []
	for e in events:
		var payload := e.project(viewer, handles, monster)
		if not payload.is_empty():
			entries.append([e.type(), payload])
	entries.append_array(extra)
	for s in sounds:
		if s.source != viewer and viewer_pos.distance_to(s.position) <= s.radius_m:
			entries.append([SOUND, {"pos": s.position, "set": s.sound_set}])
	if entries.is_empty():
		return PackedByteArray()
	var out := PackedByteArray([TAG])
	out.append_array(var_to_bytes([tick, entries]))
	return out


## True when `bytes` is an event batch (by its first byte).
static func is_message(bytes: PackedByteArray) -> bool:
	return bytes.size() > 0 and bytes[0] == TAG


## {tick, entries: Array of [type: StringName, payload: Dictionary]}, or {} when malformed; entries of
## any other shape are dropped. Objects are never decoded.
static func decode(bytes: PackedByteArray) -> Dictionary:
	if not is_message(bytes):
		return {}
	var v: Variant = bytes_to_var(bytes.slice(1))
	if not v is Array:
		return {}
	var a: Array = v
	if a.size() != 2 or not a[0] is int or not a[1] is Array:
		return {}
	var entries: Array = []
	for e: Variant in a[1]: ## the client router can trust each entry's shape
		if e is Array and e.size() == 2 and e[0] is StringName and e[1] is Dictionary:
			entries.append(e)
	return {"tick": a[0], "entries": entries}
