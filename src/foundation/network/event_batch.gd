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
## Entry type of the viewer's own monitor feed (Surveillance.camera_entries, facility-map story 011):
## {camera}, the camera index 0-3 or -1 when off. Not a catalog event; sent to the viewer only, on change.
const CAMERA := &"Camera"
## Entry type of one lighting volume's record (LightingReplication.entries, story facility-map/010, ADR-0009
## §5): {volume, base, overlays, dark_until} (dark_until the tick its Blackout ends, 0 = not dark). Sent to a
## viewer only for volumes in its visibility set, on change.
const LIGHTING := &"Lighting"
## Entry type of one accepted ping (PingDelivery.entries, story pings-and-callouts/004, rule 7): {kind, point,
## item, type, identity, from, handle}, plus own: true on the sender's copy. Sent to its recipients only.
const PING := &"Ping"
## Entry type of the sender's own rejected ping request, echoed as {kind, at, target} (rule 2). Sent to the
## sender's peer only, in its own batch (PingDelivery), never to a spectator or anyone else.
const PING_REJECTED := &"PingRejected"
## Entry type of the facility scare state (FacilityScareState.entries, story scare-events/006): {state, power}.
## Not a catalog event; sent to every viewer on change and in full on a rejoin.
const FACILITY_SCARE := &"FacilityScare"
## Callout entries (CalloutDelivery, story pings-and-callouts/006): CALLOUT {line, identity, origin, gesture, voice}
## to survivor viewers in range; CALLOUT_AUDIO {line, voice, origin} to the monster in range (audio only, rule 11).
const CALLOUT := &"Callout"
const CALLOUT_AUDIO := &"CalloutAudio"
## Entry type of one world progress bar (WorldProgress.entries, story hud-results/005): {key, at, progress,
## rate, paused}, or {key, end: true}. Sent to survivor viewers only, on change.
const PROGRESS := &"Progress"
## Entry type of the shapeshifter's own HUD state (MonsterHudFeed.entries, story hud-results/006, ADR-0004 §5):
## {ready: {lunge, false_signal, blackout, form}, transform_end, stun_end, immune_end, faces: [[survivor,
## observed_ticks, appearance], ...]}, all times server ticks. Sent to the shapeshifter's peer only, on change.
const MONSTER_HUD := &"MonsterHud"
## Entry type of the round's survivor roster (RosterFeed.entries, story hud-results/011, H4): {survivors: {player
## id: display name}}. Sent to survivor viewers only, once after their map-loaded report and in full on a rejoin.
const ROSTER := &"SurvivorRoster"
## Entry type of the server's reason the viewer's own hold was refused or cancelled (HoldReasonFeed.entries, story
## hud-results/011, H9): {reason: StringName}, one of HoldReasonFeed.TEXT's keys. Sent to the actor's peer only.
const HOLD_END := &"HoldEnd"
## Entry type of a survivor's own life state (SurvivorHudFeed.entries, story hud-results/004, ADR-0004 §5):
## {life: Downing.LifeState, rescue_s: float (tenths)}. Sent to that survivor's stream only (its spectators
## included), on change. The roster has no Seized state, so this is the only carrier of the victim's Seized.
const OWN_LIFE := &"OwnLife"
## Entry type of every door's state and the exit's (Facility Map's door replication, BUG-0018): {closed:
## Array[bool] by door net id, exit: bool, true once Exit Open}. Not a catalog event; a door is a world object,
## so it is sent to everyone, on change and in full on a rejoin. Clients apply it to their own door blockers.
const DOORS := &"DoorStates"
## Entry type of a one-shot body cue (ServerMovement.cue; ADR-0004 §2 amendment 2026-10-16): {handle, cue}, the
## receiving viewer's own handle and one of CUE_*. Never a player ID or role; sent only to viewers holding a
## handle for the body.
const BODY_CUE := &"BodyCue"
## The body left a hiding spot (Hide_Exit).
const CUE_HIDE_EXIT := &"hide_exit"
## The body was eliminated (Death01 collapse).
const CUE_ELIMINATED := &"eliminated"


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
