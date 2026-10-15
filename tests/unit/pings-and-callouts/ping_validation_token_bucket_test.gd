# Story pings-and-callouts/001: ping request validation and token bucket
# (design/gdd/pings-and-callouts.md rules 1, 5, 6, 7a, 15 and the Formulas "Ping rate limit").
# Real PingsCallouts and Knobs; world sources are fakes (sight is a flag, positions a table).
extends GdUnitTestSuite

const A := 1 ## sender
const B := 2 ## a survivor
const M := 3 ## the monster
const EYE := Vector3(0.0, 1.6, 0.0)
const POINT_H := 1.0
const DOOR := 0
const DRIVE := 1
const MONITOR := 2
const HIDING := 3
const SWITCH := 4
const ROOM_POINT := Vector3(0.0, 1.0, -10.0)

var _knobs: Knobs
var _pc: PingsCallouts
var _hz: int
var _blocked: bool
var _hidden: Dictionary
var _in_play: Dictionary
var _pos: Dictionary
var _true_form: bool


func before_test() -> void:
	_knobs = Knobs.load_all()
	_hz = _knobs.ticks(1.0)
	_blocked = false
	_hidden = {}
	_in_play = {}
	_true_form = false
	_pos = {A: Vector3.ZERO, B: Vector3(5.0, 0.0, -5.0), M: Vector3(-5.0, 0.0, -5.0)}
	var map := MapData.new()
	var door := MapPassage.new()
	door.id = &"d0"
	door.kind = MapPassage.BARRICADABLE
	door.position = Vector3(0.0, 0.0, -8.0)
	map.passages.append(door)
	for t: StringName in [&"drive", &"monitor", &"hiding", &"switch"]:
		var m := MapMarker.new()
		m.id = StringName("m_%s" % t)
		m.type = t
		m.position = Vector3(2.0, 0.0, -6.0)
		map.markers.append(m)
	_pc = PingsCallouts.new()
	_pc.set_sources(_eye, _position, _clear, _identity, _is_hidden, _is_in_play)
	_pc.set_map(map, POINT_H)
	_pc.setup(null, null, null, _knobs)


func _eye(_p: int) -> Vector3:
	return EYE


func _position(p: int) -> Vector3:
	return _pos[p]


func _clear(_sender: int, _from: Vector3, _to: Vector3, _item: int) -> bool:
	return not _blocked


func _identity(p: int) -> int:
	return CharacterDef.TRUE_FORM_APPEARANCE_ID if p == M and _true_form else p + 10


func _is_hidden(p: int) -> bool:
	return _hidden.get(p, false)


func _is_in_play(p: int) -> bool:
	return _in_play.get(p, true)


## Sends a location ping from `p` and runs `tick`; true when it was accepted.
func _loc(p: int, tick: int, at: Vector3 = ROOM_POINT) -> bool:
	_pc.request_ping(p, PingsCallouts.ping_packet(PingsCallouts.LOCATION, at))
	_pc.server_tick(tick)
	return _pc.accepted().size() == 1


func test_location_ping_in_range_and_sight_is_accepted() -> void:
	assert_bool(_loc(A, 0)).is_true()
	var r := _pc.accepted()[0]
	assert_int(r.sender).is_equal(A)
	assert_int(r.kind).is_equal(PingsCallouts.LOCATION)
	assert_vector(r.point).is_equal(ROOM_POINT)


func test_ping_beyond_max_range_is_rejected() -> void:
	var far := Vector3(0.0, 1.0, -(_knobs.ping.ping_max_range_m + 1.0))
	assert_bool(_loc(A, 0, far)).is_false()
	assert_bool(_loc(A, 1, Vector3(0.0, 1.6, -_knobs.ping.ping_max_range_m))).is_true()


func test_ping_without_line_of_sight_is_rejected_and_spends_no_token() -> void:
	_blocked = true
	assert_bool(_loc(A, 0)).is_false()
	assert_float(_pc.tokens_of(A, 0)).is_equal(float(_knobs.ping.ping_bucket_size))


func test_bucket_burst_of_ten_in_one_second_accepts_exactly_three() -> void:
	var ok := 0
	for i in 10:
		if _loc(A, i * _hz / 10):
			ok += 1
	assert_int(ok).is_equal(3)


func test_gdd_example_fourth_at_one_second_rejected_one_at_two_seconds_accepted() -> void:
	for i in 3:
		assert_bool(_loc(A, 0)).is_true()
	assert_bool(_loc(A, _hz)).is_false() # tokens 0.5, nothing spent
	assert_bool(_loc(A, 2 * _hz)).is_true() # 0.5 + 0.5
	assert_bool(_loc(A, 2 * _hz)).is_false()


func test_three_requests_in_one_tick_accept_three_and_buckets_are_per_player() -> void:
	for i in 5:
		_pc.request_ping(A, PingsCallouts.ping_packet(PingsCallouts.LOCATION, ROOM_POINT))
	_pc.request_ping(B, PingsCallouts.ping_packet(PingsCallouts.LOCATION, ROOM_POINT))
	_pc.server_tick(0)
	assert_int(_pc.accepted().size()).is_equal(4) # 3 from A, 1 from B


func test_bucket_state_is_kept_by_player_id_across_ticks() -> void:
	# A reconnect changes the connection, not the player id: the state is keyed by id and nothing clears it.
	for i in 3:
		_loc(A, 10)
	assert_float(_pc.tokens_of(A, 10)).is_equal_approx(0.0, 0.0001)
	assert_float(_pc.tokens_of(A, 10 + _hz)).is_equal_approx(0.5, 0.0001)
	assert_bool(_loc(A, 10 + _hz)).is_false()


func test_accepted_records_clear_on_the_next_tick() -> void:
	assert_bool(_loc(A, 0)).is_true()
	_pc.server_tick(1)
	assert_int(_pc.accepted().size()).is_equal(0)


func test_sender_not_in_play_is_rejected() -> void:
	# Story 002 moved the sender check to can_send; Escaped stands for not in play here.
	_pc.set_sender_sources(M,
			func(p: int) -> MatchFlow.Status: return MatchFlow.Status.ESCAPED if p == A else MatchFlow.Status.HEALTHY,
			func(_p: int) -> Downing.LifeState: return Downing.LifeState.HEALTHY,
			func() -> int: return B, func() -> bool: return false, func(_p: int) -> bool: return false)
	assert_bool(_loc(A, 0)).is_false()


func test_item_ping_names_pingable_types_only() -> void:
	for pair: Array in [[DRIVE, &"drive"], [HIDING, &"hiding"], [SWITCH, &"switch"], [DOOR, PingsCallouts.DOOR_TYPE]]:
		_pc.request_ping(A, PingsCallouts.ping_packet(PingsCallouts.ITEM, Vector3.ZERO, pair[0]))
		_pc.server_tick(0)
		assert_int(_pc.accepted().size()).is_equal(1)
		assert_str(_pc.accepted()[0].item_type).is_equal(pair[1])
		_pc.setup(null, null, null, _knobs) # fresh bucket
	for bad: int in [MONITOR, 99, -1]: # monitor station, unknown index, a taser has no index at all
		_pc.request_ping(A, PingsCallouts.ping_packet(PingsCallouts.ITEM, Vector3.ZERO, bad))
		_pc.server_tick(0)
		assert_int(_pc.accepted().size()).is_equal(0)


func test_item_ping_on_hiding_spot_carries_no_occupant() -> void:
	_hidden[B] = true
	_pc.request_ping(A, PingsCallouts.ping_packet(PingsCallouts.ITEM, Vector3.ZERO, HIDING))
	_pc.server_tick(0)
	var r := _pc.accepted()[0]
	assert_int(r.identity).is_equal(-1)
	assert_int(r.target).is_equal(HIDING)


func test_warning_ping_on_hidden_survivor_is_rejected() -> void:
	_hidden[B] = true
	_pc.request_ping(A, PingsCallouts.ping_packet(PingsCallouts.WARNING_PLAYER, Vector3.ZERO, B))
	_pc.server_tick(0)
	assert_int(_pc.accepted().size()).is_equal(0)
	assert_float(_pc.tokens_of(A, 0)).is_equal(float(_knobs.ping.ping_bucket_size))


func test_warning_ping_stores_position_and_displayed_identity() -> void:
	_pc.request_ping(A, PingsCallouts.ping_packet(PingsCallouts.WARNING_PLAYER, Vector3.ZERO, B))
	_pc.server_tick(0)
	var r := _pc.accepted()[0]
	assert_vector(r.point).is_equal(_pos[B])
	assert_int(r.identity).is_equal(B + 10)
	assert_bool(r.is_monster_label()).is_false()
	_pos[B] = Vector3(9.0, 0.0, -9.0) # the record is a snapshot; it never follows the player
	assert_vector(r.point).is_equal(Vector3(5.0, 0.0, -5.0))


func test_warning_ping_on_true_form_monster_is_labelled_monster() -> void:
	_true_form = true
	_pc.request_ping(A, PingsCallouts.ping_packet(PingsCallouts.WARNING_PLAYER, Vector3.ZERO, M))
	_pc.server_tick(0)
	assert_int(_pc.accepted().size()).is_equal(1)
	assert_bool(_pc.accepted()[0].is_monster_label()).is_true()


func test_warning_ping_on_unseen_or_out_of_play_player_is_rejected() -> void:
	_blocked = true
	_pc.request_ping(A, PingsCallouts.ping_packet(PingsCallouts.WARNING_PLAYER, Vector3.ZERO, B))
	_pc.server_tick(0)
	assert_int(_pc.accepted().size()).is_equal(0)
	_blocked = false
	_in_play[B] = false
	_pc.request_ping(A, PingsCallouts.ping_packet(PingsCallouts.WARNING_PLAYER, Vector3.ZERO, B))
	_pc.server_tick(1)
	assert_int(_pc.accepted().size()).is_equal(0)


func test_decode_rejects_malformed_and_oversized_bytes() -> void:
	assert_bool(PingsCallouts.decode_ping(PackedByteArray()).is_empty()).is_true()
	assert_bool(PingsCallouts.decode_ping(var_to_bytes({"ping": 1})).is_empty()).is_true()
	assert_bool(PingsCallouts.decode_ping(var_to_bytes({"ping": 9, "at": Vector3.ZERO, "target": -1})).is_empty()).is_true()
	assert_bool(PingsCallouts.decode_ping(var_to_bytes({"ping": 1, "at": Vector3(NAN, 0, 0), "target": -1})).is_empty()).is_true()
	assert_bool(PingsCallouts.decode_ping(var_to_bytes({"ping": 1, "at": "x", "target": -1})).is_empty()).is_true()
	assert_bool(PingsCallouts.decode_ping(SurvivorDefense.fire_packet()).is_empty()).is_true()
	assert_bool(PingsCallouts.decode_ping(PackedByteArray([1, 2, 3])).is_empty()).is_true()
	var big := PackedByteArray()
	big.resize(PingsCallouts.REQUEST_CAP_BYTES + 1)
	assert_bool(PingsCallouts.decode_ping(big).is_empty()).is_true()
	assert_bool(PingsCallouts.decode_ping(PingsCallouts.ping_packet(PingsCallouts.LOCATION, Vector3.ONE)).is_empty()).is_false()
