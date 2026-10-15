class_name SnapshotCodec extends RefCounted
## Binary snapshot format (ADR-0002 rule 5). Static encode/decode; one datagram.
## Layout, little endian: header = version u8, server_tick u32, count u8 (6 B). Per body (22 B):
## id u32, flags u8 (F_*), gait u8, position 3 x f32, yaw f32. `id` is the receiver's per-peer handle
## for the body (ADR-0004 §3), or the receiver's own player ID on its F_OWN entry. A body with F_OWN
## adds 27 B: last consumed seq s32, velocity 3 x f32, effective modifier scale f32, restore counter u8,
## hold net id s32 (-1 = no hold), hold elapsed ticks u16 (ADR-0008 §8; the receiving player's own entry
## only). 6 bodies with one own entry = 6 + 6*22 + 27 = 165 B (ADR verification 6 measured 144 B with u16
## ids; ADR-0004 guardrail about 200 B per peer).
## Body Dictionary: {id, pos: Vector3, yaw, gait} plus, when own: {own: true, seq, vel: Vector3,
## on_floor, scale, restores, hold_net_id, hold_elapsed_ticks}; the hold pair defaults to -1 and 0 on encode. `restores` counts the server's inside-geometry restores of that player
## (mod 256). Every own entry carries it, so a lost datagram cannot lose a restore (ADR-0002 rule 9).
## Which bodies a snapshot carries is replication scope (ReplicationScope, story 008).
## Usage: `var snap := SnapshotCodec.decode(SnapshotCodec.encode(tick, bodies))`; {} means rejected.

const VERSION := 4
const HEADER_BYTES := 6
const ENTRY_BYTES := 22
const OWN_EXTRA_BYTES := 27
## Upper bound on bodies in one snapshot (protocol limit, well above lobby size).
const MAX_BODIES := 32
const F_OWN := 1
const F_ON_FLOOR := 2
const F_ALL := F_OWN | F_ON_FLOOR


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
		out.encode_u32(o, b.id)
		out.encode_u8(o + 4, flags)
		out.encode_u8(o + 5, b.gait)
		_put_vec(out, o + 6, b.pos)
		out.encode_float(o + 18, b.yaw)
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
			"pos": _get_vec(bytes, o + 6), "yaw": bytes.decode_float(o + 18)}
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
		elif flags != 0:
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
