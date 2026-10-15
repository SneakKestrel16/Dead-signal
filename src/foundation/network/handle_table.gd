class_name HandleTable extends RefCounted
## Per-viewer opaque body handles (ADR-0004 §3). Each viewer sees each relevant body under a random
## 32-bit handle (0 reserved) issued for that viewer only, and never issued to it twice in a round, so
## a body that leaves and returns arrives as a stranger. Issuing queues an INTRODUCE and retiring a
## RETIRE; the sender flushes take() reliably on NetChannels.EVENT before the snapshot that uses the
## handle. Keyed by viewer player ID: peer IDs stay inside NetAuthority (control manifest).
## Usage:
##   var h := handles.handle_for(viewer, body)   # issues and queues INTRODUCE when new
##   smp.send_bytes(HandleTable.encode(handles.take(viewer)), peer, RELIABLE, NetChannels.EVENT)

const INTRODUCE := 1
const RETIRE := 2
## Discard every handle (handle 0): a spectator switch (ADR-0004 §8). Sorted first by take(), so it
## reaches the client, in order on the reliable channel, before the switch's INTRODUCEs.
const RESET := 3
## First byte of a handle message. A snapshot starts with SnapshotCodec.VERSION, so a client tells
## the two apart from that byte alone (peer_packet does not report the channel).
const TAG := 0xF1
const HEADER_BYTES := 3
const MSG_BYTES := 5
## Upper bound on messages in one packet (protocol limit; a tick introduces at most a lobby's bodies).
const MAX_MESSAGES := 256

## Callable() -> int: the next random u32 candidate. Defaults to the RNG's randi(); tests replace it
## to force a 0 or a repeat.
var source: Callable
var _rng: RandomNumberGenerator
## viewer -> {body player ID: handle}
var _live: Dictionary = {}
## viewer -> {handle: true}: every handle ever issued to that viewer this round.
var _issued: Dictionary = {}
## viewer -> PackedInt64Array of (kind, handle) pairs not yet sent.
var _outbox: Dictionary = {}


## `rng`: pass a seeded one in tests; the default is randomized.
func _init(rng: RandomNumberGenerator = null) -> void:
	_rng = rng
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	source = _rng.randi


## The viewer's handle for `body`, issuing a new one (and queueing INTRODUCE) when it has none.
func handle_for(viewer: int, body: int) -> int:
	var live: Dictionary = _live.get_or_add(viewer, {})
	if live.has(body):
		return live[body]
	var issued: Dictionary = _issued.get_or_add(viewer, {})
	var h := 0
	while h == 0 or issued.has(h):
		h = source.call()
	issued[h] = true
	live[body] = h
	_queue(viewer, INTRODUCE, h)
	return h


## True while the viewer holds a live handle for `body`.
func has(viewer: int, body: int) -> bool:
	return _live.has(viewer) and _live[viewer].has(body)


## Ends the viewer's handle for `body` (queues RETIRE). No-op without one.
func retire(viewer: int, body: int) -> void:
	if has(viewer, body):
		_queue(viewer, RETIRE, _live[viewer][body])
		_live[viewer].erase(body)


## Bodies the viewer holds a live handle for.
func bodies_of(viewer: int) -> Array[int]:
	var out: Array[int] = []
	if _live.has(viewer):
		out.assign(_live[viewer].keys())
	return out


## Forgets the viewer's live handles and unsent messages without retiring them: its client discarded
## its puppet map (reconnect, spectator switch; ADR-0004 §8-9). Issued handles stay unusable for it.
func reset_viewer(viewer: int) -> void:
	_live.erase(viewer)
	_outbox.erase(viewer)


## Queues a RESET for the viewer (after reset_viewer): its client discards its puppet map in stream
## order, so an INTRODUCE sent before the switch cannot outlive it.
func queue_reset(viewer: int) -> void:
	_queue(viewer, RESET, 0)


## Removes and returns the viewer's queued (kind, handle) pairs, ordered by handle: the order bodies
## were queued in would let a client link a re-introduced body to its old place (code review
## 2026-10-14). A handle is never issued twice to a viewer, so the order cannot reverse a pair.
func take(viewer: int) -> PackedInt64Array:
	var box: PackedInt64Array = _outbox.get(viewer, PackedInt64Array())
	_outbox.erase(viewer)
	var order: Array[int] = []
	for i in range(0, box.size(), 2):
		order.append(i)
	order.sort_custom(func(x: int, y: int) -> bool: return box[x + 1] < box[y + 1])
	var out := PackedInt64Array()
	for i in order:
		out.append(box[i])
		out.append(box[i + 1])
	return out


func _queue(viewer: int, kind: int, h: int) -> void:
	var box: PackedInt64Array = _outbox.get(viewer, PackedInt64Array())
	box.append(kind)
	box.append(h)
	_outbox[viewer] = box


## Layout, little endian: TAG u8, count u16, then per message kind u8, handle u32.
static func encode(msgs: PackedInt64Array) -> PackedByteArray:
	var count := msgs.size() / 2
	var out := PackedByteArray()
	out.resize(HEADER_BYTES + count * MSG_BYTES)
	out.encode_u8(0, TAG)
	out.encode_u16(1, count)
	for i in count:
		out.encode_u8(HEADER_BYTES + i * MSG_BYTES, msgs[i * 2])
		out.encode_u32(HEADER_BYTES + i * MSG_BYTES + 1, msgs[i * 2 + 1])
	return out


## True when `bytes` is a handle message (by its first byte); decode() still validates it.
static func is_message(bytes: PackedByteArray) -> bool:
	return bytes.size() > 0 and bytes[0] == TAG


## (kind, handle) pairs, or an empty array when the length, count, a kind or a handle is bad (0 only
## with RESET).
static func decode(bytes: PackedByteArray) -> PackedInt64Array:
	var out := PackedInt64Array()
	if bytes.size() < HEADER_BYTES or bytes[0] != TAG:
		return out
	var count := bytes.decode_u16(1)
	if count > MAX_MESSAGES or bytes.size() != HEADER_BYTES + count * MSG_BYTES:
		return out
	for i in count:
		var kind := bytes.decode_u8(HEADER_BYTES + i * MSG_BYTES)
		var h := bytes.decode_u32(HEADER_BYTES + i * MSG_BYTES + 1)
		if not kind in [INTRODUCE, RETIRE, RESET] or (h == 0) != (kind == RESET):
			return PackedInt64Array()
		out.append(kind)
		out.append(h)
	return out
