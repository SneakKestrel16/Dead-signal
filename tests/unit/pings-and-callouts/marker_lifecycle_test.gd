extends GdUnitTestSuite
## Story pings-and-callouts/005 (design/gdd/pings-and-callouts.md rules 5, 8): the client marker list.
## Markers are static, at most ping_max_active per sender handle (newest kept), expire ping_lifetime_s of
## server ticks after acceptance, and keep the identity they were sent under. Duplicate names stay apart.

const SERVER_PEER := 1

var _knobs: Knobs
var _router: ClientEventRouter
var _markers: PingMarkers
var _life: int


func before_test() -> void:
	_knobs = Knobs.load_all()
	_router = ClientEventRouter.new()
	_markers = PingMarkers.new(_router, _knobs)
	_life = _knobs.ticks(_knobs.ping.ping_lifetime_s)


## Delivers one ping entry through the router, as the server's batch at `tick` would.
func _deliver(tick: int, handle: int, from: int, point: Vector3, kind: int = PingsCallouts.LOCATION,
		identity: int = -1) -> void:
	var p := {"kind": kind, "point": point, "item": -1, "type": &"", "identity": identity, "from": from,
		"handle": handle}
	var bytes := EventBatch.build(tick, 0, [], [], Vector3.ZERO, null, -1, [[EventBatch.PING, p]])
	_router.on_packet(SERVER_PEER, bytes)


func _points(now: int) -> Array:
	return _markers.active(now).map(func(m: Dictionary) -> Vector3: return m["point"])


func test_warning_marker_stays_at_ping_time_point_with_frozen_identity() -> void:
	var at := Vector3(3, 0, -4)
	_deliver(100, 7, 2, at, PingsCallouts.WARNING_PLAYER, 5)
	# The target moves and transforms: later pings name its new identity, the old marker does not follow.
	_deliver(110, 8, 3, Vector3(9, 0, 9), PingsCallouts.WARNING_PLAYER, CharacterDef.TRUE_FORM_APPEARANCE_ID)
	var m: Dictionary = _markers.active(100 + _life - 1)[0]
	assert_vector(m["point"]).is_equal(at)
	assert_int(m["identity"]).is_equal(5)
	assert_int(m["from"]).is_equal(2)


func test_max_active_keeps_newest_per_sender() -> void:
	assert_int(_knobs.ping.ping_max_active).is_equal(2)
	_deliver(10, 7, 2, Vector3(1, 0, 0))
	_deliver(11, 7, 2, Vector3(2, 0, 0))
	_deliver(12, 9, 3, Vector3(9, 0, 0))
	_deliver(13, 7, 2, Vector3(3, 0, 0))
	assert_array(_points(13)).contains_exactly_in_any_order(
		[Vector3(2, 0, 0), Vector3(3, 0, 0), Vector3(9, 0, 0)])


func test_marker_expires_lifetime_after_acceptance_on_server_ticks() -> void:
	_deliver(50, 7, 2, Vector3.ONE)
	assert_int(_markers.active(50 + _life - 1).size()).is_equal(1)
	assert_int(_markers.active(50 + _life).size()).is_equal(0)


func test_sender_disconnect_leaves_markers_to_expire_normally() -> void:
	_deliver(50, 7, 2, Vector3.ONE)
	# A disconnect is no ping message: nothing reaches the list, so the marker lives out its lifetime.
	_router.on_packet(SERVER_PEER, EventBatch.build(60, 0, [], [], Vector3.ZERO, null, -1, []))
	assert_int(_markers.active(50 + _life - 1).size()).is_equal(1)
	assert_int(_markers.active(50 + _life).size()).is_equal(0)


func test_two_bodies_sharing_a_name_show_two_markers() -> void:
	_deliver(10, 7, 2, Vector3(1, 0, 0))
	_deliver(10, 8, 2, Vector3(2, 0, 0))
	_deliver(11, 7, 2, Vector3(3, 0, 0))
	_deliver(11, 8, 2, Vector3(4, 0, 0))
	var froms: Array = _markers.active(11).map(func(m: Dictionary) -> int: return m["from"])
	assert_array(froms).is_equal([2, 2, 2, 2])


func test_malformed_payload_is_ignored() -> void:
	var bad := {"kind": PingsCallouts.LOCATION, "point": "x", "from": 2, "handle": 7}
	_router.on_packet(SERVER_PEER, EventBatch.build(10, 0, [], [], Vector3.ZERO, null, -1, [[EventBatch.PING, bad]]))
	_router.on_packet(SERVER_PEER, EventBatch.build(10, 0, [], [], Vector3.ZERO, null, -1,
		[[EventBatch.PING, {"point": Vector3.ONE}]]))
	assert_int(_markers.active(10).size()).is_equal(0)


func test_server_handle_separates_bodies_sharing_a_name_and_reveals_no_player_id() -> void:
	# The shapeshifter (player 4) wears survivor 2's appearance (id 20): both `from` read 20.
	var shown := {2: 20, 4: 20}
	var pings := PingsCallouts.new()
	var d := PingDelivery.new(pings, 4, func(_p: int) -> bool: return true,
		func(p: int) -> int: return shown[p], func() -> int: return 0, func(_p: int, _b: PackedByteArray) -> void: pass)
	var real: int = d.handle_of(2, 20)
	var fake: int = d.handle_of(4, 20)
	assert_int(real).is_not_equal(fake)
	assert_int(d.handle_of(2, 20)).is_equal(real)
	# A new disguise is a new handle, so markers never link one disguise to another.
	assert_int(d.handle_of(4, 30)).is_not_equal(fake)
