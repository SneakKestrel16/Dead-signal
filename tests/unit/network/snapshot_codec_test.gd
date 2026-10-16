# Story network-authority/006: snapshot binary format.
extends GdUnitTestSuite

const SIX_BODY_BYTES := 171 ## 6 + 6 * 23 + 27 (u32 handles, story 008; hold pair, controller-interaction 016; appearance, borrowed-face 007); ADR verification 6 measured 144 B with u16 ids
const SINGLE_DATAGRAM_BYTES := 1000


func _bodies(n: int, own_index: int = 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in n:
		var b := {"id": 10 + i, "gait": i % 4, "pos": Vector3(i, 0.5 * i, -2.0 * i), "yaw": 0.25 * i, "appearance": i,
			"flashlight": i % 2 == 0, "drive": i == 2, "fuse": i % 2 == 1}
		if i == own_index:
			b["own"] = true
			b["seq"] = 1234
			b["vel"] = Vector3(1.5, -2.0, 0.25)
			b["on_floor"] = true
			b["scale"] = 0.5
			b["restores"] = 0
		out.append(b)
	return out


func test_round_trip_keeps_every_field() -> void:
	var bodies := _bodies(3, 1)
	bodies[1]["restores"] = 255
	var snap := SnapshotCodec.decode(SnapshotCodec.encode(70000, bodies))
	assert_int(snap.tick).is_equal(70000)
	assert_int(snap.bodies.size()).is_equal(3)
	for i in 3:
		assert_int(snap.bodies[i].id).is_equal(bodies[i].id)
		assert_int(snap.bodies[i].gait).is_equal(bodies[i].gait)
		assert_vector(snap.bodies[i].pos).is_equal(bodies[i].pos)
		assert_float(snap.bodies[i].yaw).is_equal(bodies[i].yaw)
		assert_int(snap.bodies[i].appearance).is_equal(bodies[i].appearance)
		assert_bool(snap.bodies[i].flashlight).is_equal(bodies[i].flashlight) ## survivor-defense 009, any entry
		assert_bool(snap.bodies[i].drive).is_equal(bodies[i].drive) ## carried objectives, any entry
		assert_bool(snap.bodies[i].fuse).is_equal(bodies[i].fuse)
		assert_bool(snap.bodies[i].has("own")).is_equal(i == 1)
	var own: Dictionary = snap.bodies[1]
	assert_int(own.seq).is_equal(1234)
	assert_vector(own.vel).is_equal(Vector3(1.5, -2.0, 0.25))
	assert_bool(own.on_floor).is_true()
	assert_int(own.restores).is_equal(255)
	assert_float(own.scale).is_equal(0.5)
	assert_int(own.hold_net_id).is_equal(-1) ## encode default: no hold
	assert_int(own.hold_elapsed_ticks).is_equal(0)


func test_six_bodies_fit_one_datagram_near_adr_measure() -> void:
	var bytes := SnapshotCodec.encode(1, _bodies(6))
	assert_int(bytes.size()).is_equal(SIX_BODY_BYTES)
	assert_int(bytes.size()).is_less(SINGLE_DATAGRAM_BYTES)


func test_bad_length_is_rejected() -> void:
	var good := SnapshotCodec.encode(1, _bodies(4))
	assert_dict(SnapshotCodec.decode(PackedByteArray())).is_empty()
	assert_dict(SnapshotCodec.decode(good.slice(0, SnapshotCodec.HEADER_BYTES - 1))).is_empty()
	assert_dict(SnapshotCodec.decode(good.slice(0, good.size() - 1))).is_empty()
	var longer := good.duplicate()
	longer.append(0)
	assert_dict(SnapshotCodec.decode(longer)).is_empty()
	var lying := good.duplicate()
	lying.encode_u8(5, 200) ## count above the limit
	assert_dict(SnapshotCodec.decode(lying)).is_empty()


func test_nan_and_inf_are_rejected() -> void:
	for bad in [NAN, INF]:
		var pos_bad := _bodies(2)
		pos_bad[1]["pos"] = Vector3(0, bad, 0)
		assert_dict(SnapshotCodec.decode(SnapshotCodec.encode(1, pos_bad))).is_empty()
		var yaw_bad := _bodies(2)
		yaw_bad[1]["yaw"] = bad
		assert_dict(SnapshotCodec.decode(SnapshotCodec.encode(1, yaw_bad))).is_empty()
		var vel_bad := _bodies(2)
		vel_bad[0]["vel"] = Vector3(bad, 0, 0)
		assert_dict(SnapshotCodec.decode(SnapshotCodec.encode(1, vel_bad))).is_empty()
		var scale_bad := _bodies(2)
		scale_bad[0]["scale"] = bad
		assert_dict(SnapshotCodec.decode(SnapshotCodec.encode(1, scale_bad))).is_empty()


func test_wrong_version_unknown_flags_and_two_own_entries_are_rejected() -> void:
	var good := SnapshotCodec.encode(1, _bodies(2))
	var v := good.duplicate()
	v.encode_u8(0, SnapshotCodec.VERSION + 1)
	assert_dict(SnapshotCodec.decode(v)).is_empty()
	var f := good.duplicate()
	f.encode_u8(SnapshotCodec.HEADER_BYTES + SnapshotCodec.ENTRY_BYTES + SnapshotCodec.OWN_EXTRA_BYTES + 4, 0x80) ## flags byte after the u32 id
	assert_dict(SnapshotCodec.decode(f)).is_empty()
	var two_own := _bodies(2)
	two_own[1]["own"] = true
	two_own[1]["seq"] = 1
	two_own[1]["vel"] = Vector3.ZERO
	two_own[1]["on_floor"] = false
	two_own[1]["scale"] = 1.0
	two_own[1]["restores"] = 0
	assert_dict(SnapshotCodec.decode(SnapshotCodec.encode(1, two_own))).is_empty()


# Controller-interaction 016 (ADR-0008 §8): the owner's entry carries its hold for the predicted bar.
func test_own_entry_carries_the_hold_and_rejects_a_bad_net_id() -> void:
	var bodies := _bodies(2)
	bodies[0]["hold_net_id"] = 300
	bodies[0]["hold_elapsed_ticks"] = 4321
	var own: Dictionary = SnapshotCodec.decode(SnapshotCodec.encode(1, bodies)).bodies[0]
	assert_int(own.hold_net_id).is_equal(300)
	assert_int(own.hold_elapsed_ticks).is_equal(4321)
	bodies[0]["hold_net_id"] = -2
	assert_dict(SnapshotCodec.decode(SnapshotCodec.encode(1, bodies))).is_empty()
