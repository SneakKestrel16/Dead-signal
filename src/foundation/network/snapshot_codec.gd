class_name SnapshotCodec extends RefCounted
## Binary snapshot format (ADR-0002 rule 5). Static encode/decode; one datagram.
## Layout, little endian: header = version u8, server_tick u32, count u8 (6 B). Per body (23 B):
## id u32, flags u8 (F_*; F_TRANSFORMING and F_FLASHLIGHT on any entry, the rest own only), gait u8, position 3 x f32, yaw f32, appearance u8 (CharacterDef appearance id:
## the body's character, or the true form for the shapeshifter's; NO_APPEARANCE when unknown; ADR-0004 §4). `id` is the receiver's per-peer handle
## for the body (ADR-0004 §3), or the receiver's own player ID on its F_OWN entry. A body with F_OWN
## adds 27 B: last consumed seq s32, velocity 3 x f32, effective modifier scale f32, restore counter u8,
## hold net id s32 (-1 = no hold), hold elapsed ticks u16 (ADR-0008 §8; the receiving player's own entry
## only). 6 bodies with one own entry = 6 + 6*23 + 27 = 171 B (ADR verification 6 measured 144 B with u16
## ids; ADR-0004 guardrail about 200 B per peer).
## Body Dictionary: {id, pos: Vector3, yaw, gait, appearance (default NO_APPEARANCE), transforming: bool
## (default false; borrowed-face story 005), flashlight: bool (default false; survivor-defense story 009)} plus, when own: {own: true, seq, vel: Vector3,
## on_floor, scale, restores, hold_net_id, hold_elapsed_ticks}; the hold pair defaults to -1 and 0 on encode. `restores` counts the server's inside-geometry restores of that player
## (mod 256). Every own entry carries it, so a lost datagram cannot lose a restore (ADR-0002 rule 9).
## Which bodies a snapshot carries is replication scope (ReplicationScope, story 008).
## Usage: `var snap := SnapshotCodec.decode(SnapshotCodec.encode(tick, bodies))`; {} means rejected.

const VERSION := 7
const HEADER_BYTES := 6
const ENTRY_BYTES := 23
const OWN_EXTRA_BYTES := 27
## Upper bound on bodies in one snapshot (protocol limit, well above lobby size).
const MAX_BODIES := 32
## `appearance` of a body whose appearance nobody supplied (ServerMovement.appearance_of unset).
const NO_APPEARANCE := 255
const F_OWN := 1
const F_ON_FLOOR := 2
## The body is mid-transformation (borrowed-face.md rule 8: client distortion audio and warp read it).
## Only the flag travels, never the target form or start time (inference: the cue needs no more, and the
## target would show the next disguise before it completes; settle with game-designer if the warp needs
## the remaining time).
const F_TRANSFORMING := 4
## The body's flashlight is on (survivor-defense.md rule 3: every client sees the cone).
const F_FLASHLIGHT := 8
const F_ALL := F_OWN | F_ON_FLOOR | F_TRANSFORMING | F_FLASHLIGHT


## Encodes `bodies` (see class doc) stamped with `tick`.
static func encode(tick: int, bodies: Array[Dictionary]) -> PackedByteArray:
	var size := HEADER_BYTES
	for b in bodies:
		size += ENTRY_BYTES + (OWN_EXTRA_BYTES if b.get("own", false) else 0)
	var out := PackedByteArray()
	out.resize(size)
	out.encode_u8(0, VERSION)
	out.encode_u32(1, tick)
	out.encode_u8(5, bodies.size())
	var o := HEADER_BYTES
	for b in bodies:
		var own: bool = b.get("own", false)
		var flags := (F_OWN if own else 0) | (F_ON_FLOOR if own and b.on_floor else 0)
		if b.get("transforming", false):
			flags |= F_TRANSFORMING
		if b.get("flashlight", false):
			flags |= F_FLASHLIGHT
		out.encode_u32(o, b.id)
		out.encode_u8(o + 4, flags)
		out.encode_u8(o + 5, b.gait)
		_put_vec(out, o + 6, b.pos)
		out.encode_float(o + 18, b.yaw)
		out.encode_u8(o + 22, b.get("appearance", NO_APPEARANCE))
		o += ENTRY_BYTES
		if own:
			out.encode_s32(o, b.seq)
			_put_vec(out, o + 4, b.vel)
			out.encode_float(o + 16, b.scale)
			out.encode_u8(o + 20, b.restores)
			out.encode_s32(o + 21, b.get("hold_net_id", -1))
			out.encode_u16(o + 25, clampi(b.get("hold_elapsed_ticks", 0), 0, 0xFFFF))
			o += OWN_EXTRA_BYTES
	return out


## Decodes and validates. Returns {tick, bodies: Array[Dictionary]} or {} when the version, length,
## flag bits or any float is bad (the caller drops the snapshot). Never reads past the buffer.
static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < HEADER_BYTES or bytes.decode_u8(0) != VERSION:
		return {}
	var count := bytes.decode_u8(5)
	if count > MAX_BODIES:
		return {}
	var bodies: Array[Dictionary] = []
	var o := HEADER_BYTES
	var own_seen := 0
	for i in count:
		if o + ENTRY_BYTES > bytes.size():
			return {}
		var flags := bytes.decode_u8(o + 4)
		if flags & ~F_ALL != 0:
			return {}
		var b := {"id": bytes.decode_u32(o), "gait": bytes.decode_u8(o + 5),
			"pos": _get_vec(bytes, o + 6), "yaw": bytes.decode_float(o + 18),
			"appearance": bytes.decode_u8(o + 22), "transforming": flags & F_TRANSFORMING != 0,
			"flashlight": flags & F_FLASHLIGHT != 0}
		if not (_finite(b.pos) and is_finite(b.yaw)):
			return {}
		o += ENTRY_BYTES
		if flags & F_OWN != 0:
			own_seen += 1
			if o + OWN_EXTRA_BYTES > bytes.size():
				return {}
			b["own"] = true
			b["on_floor"] = flags & F_ON_FLOOR != 0
			b["seq"] = bytes.decode_s32(o)
			b["vel"] = _get_vec(bytes, o + 4)
			b["scale"] = bytes.decode_float(o + 16)
			b["restores"] = bytes.decode_u8(o + 20)
			b["hold_net_id"] = bytes.decode_s32(o + 21)
			b["hold_elapsed_ticks"] = bytes.decode_u16(o + 25)
			if not (_finite(b.vel) and is_finite(b.scale)) or b.hold_net_id < -1:
				return {}
			o += OWN_EXTRA_BYTES
		elif flags & ~(F_TRANSFORMING | F_FLASHLIGHT) != 0:
			return {}
		bodies.append(b)
	if o != bytes.size() or own_seen > 1:
		return {}
	return {"tick": bytes.decode_u32(1), "bodies": bodies}


static func _put_vec(out: PackedByteArray, o: int, v: Vector3) -> void:
	out.encode_float(o, v.x)
	out.encode_float(o + 4, v.y)
	out.encode_float(o + 8, v.z)


static func _get_vec(bytes: PackedByteArray, o: int) -> Vector3:
	return Vector3(bytes.decode_float(o), bytes.decode_float(o + 4), bytes.decode_float(o + 8))


static func _finite(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)
