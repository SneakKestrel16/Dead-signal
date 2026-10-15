class_name InputFrame extends RefCounted
## One tick of player intent (ADR-0002 §3, ADR-0008 §3). Intent only: there is no position,
## velocity, speed or progress field, by design (manifest: client_sent_position).
## Units: yaw and pitch are RADIANS; move is a Vector2 of length <= 1 (x strafe, y forward).

const FLAG_SPRINT := 1
const FLAG_CROUCH := 2
const FLAG_INTERACT := 4
const FLAG_TARGET_IS_BODY := 8
## Story survivor-defense/014 (AD-219): the secondary interact; set with `interact`, it picks a door's
## Barricade, Remove or Break over the door toggle.
const FLAG_INTERACT_ALT := 16

var seq: int = 0
var move: Vector2 = Vector2.ZERO
var sprint: bool = false
var crouch: bool = false
var interact: bool = false
var target_is_body: bool = false
## The secondary interact is held (`interact` is then held too). Read with `interact`'s rising edge.
var interact_alt: bool = false
## Read only on the frame where `interact` rises (ADR-0008 §3).
var interact_target: int = 0
var yaw: float = 0.0
var pitch: float = 0.0
## ADR-0003 §2: the server tick (fractional) the client was rendering remote players at; 0 when the
## packet carries none. Not validated by InputQueue: LagCompensation rejects a non-finite or future one.
## ponytail: float32 on the wire, 1/128-tick resolution up to tick 131072 (36 min at 60 Hz), 1/64 to 73 min;
## send an offset from ack_snapshot_tick if rounds outgrow that.
var view_tick: float = 0.0
## ADR-0003 §2: the newest snapshot tick the client had received; the server's RTT bound comes from it.
var ack_snapshot_tick: int = 0
## ADR-0015 §2: the FlinchRecord id the client rendered with (a byte) and its estimated server tick when
## it sampled. Untrusted: the server only looks the id up among its own records and clamps the tick.
## ponytail: offset_tick is a full int32, not the ADR's low 16 bits; pack it if bandwidth matters.
var record_id: int = 0
var offset_tick: int = 0
## ADR-0015 §3: the view epoch the client's yaw and pitch are in (a byte; it changes when the client folds
## a re-baseline). Untrusted: the server looks it up among its own last epochs.
var view_epoch: int = 0


## Packs the five booleans into the flags byte, whole. Example: sprint+crouch -> 3.
static func pack_flags(sprint_: bool, crouch_: bool, interact_: bool, target_is_body_: bool,
		interact_alt_: bool = false) -> int:
	return (FLAG_SPRINT if sprint_ else 0) | (FLAG_CROUCH if crouch_ else 0) \
		| (FLAG_INTERACT if interact_ else 0) | (FLAG_TARGET_IS_BODY if target_is_body_ else 0) \
		| (FLAG_INTERACT_ALT if interact_alt_ else 0)


## This frame's flags byte.
func flags() -> int:
	return pack_flags(sprint, crouch, interact, target_is_body, interact_alt)


## Builds the packed-array packet for up to the last 3 frames (client side helper and test fixture).
## The flags array is built whole from an Array of ints and then converted, never written per element.
static func build_packet(frames: Array[InputFrame]) -> Dictionary:
	var seqs := PackedInt32Array()
	var moves := PackedVector2Array()
	var flag_bytes: Array[int] = []
	var yaws := PackedFloat32Array()
	var pitches := PackedFloat32Array()
	var targets := PackedInt32Array()
	var views := PackedFloat32Array()
	var acks := PackedInt32Array()
	var records: Array[int] = []
	var offset_ticks := PackedInt32Array()
	var epochs: Array[int] = []
	for f in frames:
		seqs.append(f.seq)
		moves.append(f.move)
		flag_bytes.append(f.flags())
		yaws.append(f.yaw)
		pitches.append(f.pitch)
		targets.append(f.interact_target)
		views.append(f.view_tick)
		acks.append(f.ack_snapshot_tick)
		records.append(f.record_id)
		offset_ticks.append(f.offset_tick)
		epochs.append(f.view_epoch)
	return {
		"seq": seqs, "move": moves, "flags": PackedByteArray(flag_bytes),
		"yaw": yaws, "pitch": pitches, "interact_target": targets, "view_tick": views,
		"ack_snapshot_tick": acks, "record_id": PackedByteArray(records), "offset_tick": offset_ticks,
		"view_epoch": PackedByteArray(epochs),
	}
