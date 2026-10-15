# Story pings-and-callouts/010: rejection echo for over-cap pings and the SightTest 360-degree blind spot
# (design/gdd/pings-and-callouts.md rules 2, 6; ADR-0002 every request answered; ADR-0012 SightTest).
# Real PingsCallouts, SightTest and Knobs; world sources are fakes (the ray always clear).
extends GdUnitTestSuite

const A := 1
const B := 2
const EYE := Vector3(0.0, 1.6, 0.0)
const AHEAD := Vector3(0.0, 1.6, -10.0)
const BEHIND := Vector3(0.0, 1.6, 10.0)

var _knobs: Knobs
var _pc: PingsCallouts
var _cap: int


func before_test() -> void:
	_knobs = Knobs.load_all()
	_cap = _knobs.ping.ping_bucket_size
	_pc = PingsCallouts.new()
	_pc.set_sources(_eye, _position, _clear, _identity, _hidden)
	_pc.set_map(MapData.new(), 1.0)
	_pc.setup(null, null, null, _knobs)


func _eye(_p: int) -> Vector3:
	return EYE


func _position(_p: int) -> Vector3:
	return Vector3.ZERO


func _clear(_sender: int, _from: Vector3, _to: Vector3, _item: int) -> bool:
	return true


func _ray_clear(_from: Vector3, _to: Vector3) -> bool:
	return true


func _identity(p: int) -> int:
	return p


func _hidden(_p: int) -> bool:
	return false


func _send(p: int, at: Vector3 = AHEAD) -> void:
	_pc.request_ping(p, PingsCallouts.ping_packet(PingsCallouts.LOCATION, at))


func _rejected_of(p: int) -> Array:
	return _pc.rejected().filter(func(r: Array) -> bool: return r[0] == p)


func test_over_cap_requests_are_echoed_as_rejections_to_their_sender() -> void:
	for i in _cap + 2:
		_send(A, AHEAD + Vector3(0.0, 0.0, -i))
	_send(B)
	_pc.server_tick(0)
	assert_int(_pc.accepted().size()).is_equal(_cap + 1) # A's first cap, B's one
	var own := _rejected_of(A)
	assert_int(own.size()).is_equal(2)
	# The echo carries the request itself, so the client's matching pending marker clears.
	assert_dict(own[0][1]).is_equal({"kind": PingsCallouts.LOCATION, "at": AHEAD + Vector3(0.0, 0.0, -_cap),
			"target": -1})
	assert_dict(own[1][1]).is_equal({"kind": PingsCallouts.LOCATION, "at": AHEAD + Vector3(0.0, 0.0, -_cap - 1),
			"target": -1})
	assert_int(_rejected_of(B).size()).is_equal(0)


func test_over_cap_rejections_spend_no_token() -> void:
	for i in _cap * 2:
		_send(A)
	_pc.server_tick(0)
	assert_float(_pc.tokens_of(A, 0)).is_equal_approx(0.0, 0.0001)
	_pc.server_tick(1)
	assert_int(_pc.rejected().size()).is_equal(0) # the echo is that tick's only


func test_flood_memory_is_bounded() -> void:
	for i in 1000:
		_send(A)
	_pc.server_tick(0)
	# Bounded: the cap kept for validation plus at most the same number echoed; the rest are dropped.
	assert_int(_pc.accepted().size()).is_equal(_cap)
	assert_int(_pc.rejected().size()).is_equal(_cap)


func test_ping_exactly_behind_the_sender_is_accepted() -> void:
	_send(A, BEHIND)
	_pc.server_tick(0)
	assert_int(_pc.accepted().size()).is_equal(1)


func test_sight_test_full_circle_never_refuses_on_angle() -> void:
	var clear := Callable(self, "_ray_clear")
	for yaw: float in [0.0, PI / 3.0, PI, -PI / 2.0, 2.0]:
		for i in 72:
			var a := deg_to_rad(i * 5.0)
			var p := EYE + Vector3(sin(a), 0.0, cos(a)) * 10.0
			assert_bool(SightTest.sees(EYE, yaw, PackedVector3Array([p]), 20.0, 360.0, clear)) \
					.override_failure_message("yaw %s point %s" % [yaw, p]).is_true()
	assert_bool(SightTest.sees(EYE, 0.0, PackedVector3Array([BEHIND]), 20.0, 360.0, clear)).is_true()


func test_sight_test_narrow_cone_still_refuses_behind() -> void:
	var clear := Callable(self, "_ray_clear")
	assert_bool(SightTest.sees(EYE, 0.0, PackedVector3Array([BEHIND]), 20.0, 359.0, clear)).is_false()
	assert_bool(SightTest.sees(EYE, 0.0, PackedVector3Array([AHEAD]), 20.0, 90.0, clear)).is_true()
