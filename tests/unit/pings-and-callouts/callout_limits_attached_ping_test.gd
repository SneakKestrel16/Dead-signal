# Story pings-and-callouts/003: callout acceptance limits and attached item ping
# (design/gdd/pings-and-callouts.md rules 9, 13, 16, 17, 28; Formulas "Callout acceptance").
# Real PingsCallouts, Knobs, EventBus and the shipped CalloutSet; world sources are fakes.
extends GdUnitTestSuite

const A := 1 ## a survivor sender
const B := 2 ## the survivor a fake callout impersonates
const M := 3 ## the monster, disguised (no sender sources: nobody is gated)
const EYE := Vector3(0.0, 1.6, 0.0)
const POINT_H := 1.0
const DRIVE := 0
const MONITOR := 1
const FAKE_AT := Vector3(4.0, 0.0, -4.0)
const DANGER := &"danger"
const WAIT := &"wait"
const DRIVE_HERE := &"drive_here"

var _knobs: Knobs
var _bus: EventBus
var _pc: PingsCallouts
var _hz: int


func before_test() -> void:
	_knobs = Knobs.load_all()
	_hz = _knobs.ticks(1.0)
	var map := MapData.new()
	for t: StringName in [&"drive", &"monitor"]:
		var m := MapMarker.new()
		m.id = StringName("m_%s" % t)
		m.type = t
		m.position = Vector3(2.0, 0.0, -6.0)
		map.markers.append(m)
	_bus = EventBus.new(_knobs.core.max_flush_rounds)
	_pc = PingsCallouts.new()
	_pc.set_sources(_eye, _position, _clear, _identity, _is_hidden)
	_pc.set_map(map, POINT_H)
	_pc.setup(null, _bus, null, _knobs)


func _eye(_p: int) -> Vector3:
	return EYE


func _position(p: int) -> Vector3:
	return Vector3(p, 0.0, 0.0)


func _clear(_sender: int, _from: Vector3, _to: Vector3, _item: int) -> bool:
	return true


func _identity(p: int) -> int:
	return p + 10


func _is_hidden(_p: int) -> bool:
	return false


## Sends `line` from `p` at second `s` (optionally attaching item `item`); true when it was accepted.
func _call(p: int, line: StringName, s: float, item: int = -1) -> bool:
	_pc.request_callout(p, PingsCallouts.callout_packet(line, item))
	_pc.server_tick(roundi(s * _hz))
	return _pc.callouts().size() == 1


## A False Signal fake callout of `line` in B's voice, flushed and then taken by the tick at second `s`.
func _fake(line: StringName, s: float) -> void:
	var e := EvAbilityUsed.new()
	e.ability = MonsterAbilities.Ability.FALSE_SIGNAL
	e.detail = MonsterAbilities.SIGNAL_DETAILS[MonsterAbilities.SignalType.CALLOUT]
	e.survivor = B
	e.line = line
	e.target = FAKE_AT
	_bus.emit(e)
	_bus.flush()
	_pc.server_tick(roundi(s * _hz))


func test_lines_come_from_the_data_resource() -> void:
	var set := CalloutSet.load_shipped()
	assert_object(set).is_not_null()
	assert_array(PingsCallouts.CALLOUT_LINES).is_equal(set.lines)
	assert_int(set.lines.size()).is_equal(8)
	assert_str(set.text_of(DRIVE_HERE)).is_equal("Drive here")
	assert_str(set.text_of(&"that_wasnt_me")).is_equal("That wasn't me")


func test_same_line_twice_within_repeat_block_is_accepted_once() -> void:
	assert_bool(_call(A, DANGER, 0.0)).is_true()
	assert_bool(_call(A, DANGER, 4.0)).is_false()
	assert_bool(_call(A, DANGER, 8.0)).is_true()


func test_global_cooldown_rejects_a_different_line_at_1s_and_accepts_at_3s() -> void:
	assert_bool(_call(A, DANGER, 0.0)).is_true()
	assert_bool(_call(A, WAIT, 1.0)).is_false()
	assert_bool(_call(A, WAIT, 3.0)).is_true() ## the t=1 rejection updated nothing


func test_gdd_example_only_accepted_callouts_update_the_timestamps() -> void:
	assert_bool(_call(A, DANGER, 0.0)).is_true()
	assert_bool(_call(A, WAIT, 3.0)).is_true()
	assert_bool(_call(A, DANGER, 6.0)).is_false()
	assert_bool(_call(A, DANGER, 8.0)).is_true() ## the t=6 rejection did not restart the block


func test_limits_are_per_player() -> void:
	assert_bool(_call(A, DANGER, 0.0)).is_true()
	assert_bool(_call(B, DANGER, 0.5)).is_true()


func test_accepted_callout_record() -> void:
	assert_bool(_call(A, WAIT, 0.0)).is_true()
	var c := _pc.callouts()[0]
	assert_int(c.sender).is_equal(A)
	assert_int(c.identity).is_equal(A + 10)
	assert_str(c.line).is_equal(WAIT)
	assert_vector(c.origin).is_equal(_position(A))
	assert_bool(c.fake).is_false()
	assert_object(c.ping).is_null()
	_pc.server_tick(1)
	assert_array(_pc.callouts()).is_empty()


func test_drive_here_with_attached_item_ping_spends_one_token() -> void:
	assert_bool(_call(A, DRIVE_HERE, 0.0, DRIVE)).is_true()
	var c := _pc.callouts()[0]
	assert_object(c.ping).is_not_null()
	assert_int(c.ping.kind).is_equal(PingsCallouts.ITEM)
	assert_int(c.ping.target).is_equal(DRIVE)
	assert_int(_pc.accepted().size()).is_equal(1) ## delivered as a ping like any other
	assert_float(_pc.tokens_of(A, 0)).is_equal(_knobs.ping.ping_bucket_size - 1.0)


func test_drive_here_with_no_tokens_plays_without_the_attached_ping() -> void:
	for i in _knobs.ping.ping_bucket_size:
		_pc.request_ping(A, PingsCallouts.ping_packet(PingsCallouts.ITEM, Vector3.ZERO, DRIVE))
	_pc.server_tick(0)
	assert_float(_pc.tokens_of(A, 0)).is_equal(0.0)
	assert_bool(_call(A, DRIVE_HERE, 0.0, DRIVE)).is_true()
	assert_object(_pc.callouts()[0].ping).is_null()
	assert_array(_pc.accepted()).is_empty()


func test_invalid_attached_ping_spends_nothing_and_the_callout_plays() -> void:
	assert_bool(_call(A, DRIVE_HERE, 0.0, MONITOR)).is_true()
	assert_object(_pc.callouts()[0].ping).is_null()
	assert_float(_pc.tokens_of(A, 0)).is_equal(float(_knobs.ping.ping_bucket_size))


func test_rejected_callout_spends_no_token_for_its_attachment() -> void:
	assert_bool(_call(A, DANGER, 0.0)).is_true()
	assert_bool(_call(A, DRIVE_HERE, 1.0, DRIVE)).is_false()
	assert_array(_pc.accepted()).is_empty()
	assert_float(_pc.tokens_of(A, _hz)).is_equal(float(_knobs.ping.ping_bucket_size))


func test_fake_callout_is_recorded_as_fake_from_the_chosen_point_in_the_survivors_voice() -> void:
	_fake(DANGER, 0.0)
	assert_int(_pc.callouts().size()).is_equal(1)
	var c := _pc.callouts()[0]
	assert_bool(c.fake).is_true()
	assert_str(c.line).is_equal(DANGER)
	assert_vector(c.origin).is_equal(FAKE_AT)
	assert_int(c.identity).is_equal(B + 10)
	assert_object(c.ping).is_null()


func test_fake_callout_touches_no_limit_state() -> void:
	_pc.set_sender_sources(M, func(_p: int) -> MatchFlow.Status: return MatchFlow.Status.HEALTHY,
		func(_p: int) -> Downing.LifeState: return Downing.LifeState.HEALTHY, func() -> int: return B,
		func() -> bool: return false, func(_p: int) -> bool: return false)
	_fake(DRIVE_HERE, 0.0)
	assert_float(_pc.tokens_of(B, 0)).is_equal(float(_knobs.ping.ping_bucket_size))
	assert_float(_pc.tokens_of(M, 0)).is_equal(float(_knobs.ping.ping_bucket_size))
	assert_bool(_call(B, DRIVE_HERE, 1.0)).is_true()
	assert_bool(_call(M, DRIVE_HERE, 1.0)).is_true()


func test_fake_callout_with_an_unknown_line_or_another_signal_is_ignored() -> void:
	_fake(&"not_a_line", 0.0)
	assert_array(_pc.callouts()).is_empty()
	var e := EvAbilityUsed.new()
	e.ability = MonsterAbilities.Ability.FALSE_SIGNAL
	e.detail = MonsterAbilities.SIGNAL_DETAILS[MonsterAbilities.SignalType.FOOTSTEPS]
	e.line = DANGER
	_bus.emit(e)
	_bus.flush()
	_pc.server_tick(1)
	assert_array(_pc.callouts()).is_empty()


func test_decode_callout_validates_untrusted_bytes() -> void:
	assert_dict(PingsCallouts.decode_callout(PingsCallouts.callout_packet(WAIT))).is_equal({"line": WAIT, "target": -1})
	assert_dict(PingsCallouts.decode_callout(PingsCallouts.callout_packet(DRIVE_HERE, 4))) \
		.is_equal({"line": DRIVE_HERE, "target": 4})
	assert_dict(PingsCallouts.decode_callout(PingsCallouts.callout_packet(&"nope"))).is_empty()
	assert_dict(PingsCallouts.decode_callout(PingsCallouts.callout_packet(WAIT, 4))).is_empty() ## rule 13
	assert_dict(PingsCallouts.decode_callout(PingsCallouts.callout_packet(DRIVE_HERE, -2))).is_empty()
	assert_dict(PingsCallouts.decode_callout(var_to_bytes({PingsCallouts.CALLOUT_KEY: "wait",
		PingsCallouts.TARGET_KEY: -1}))).is_empty() ## a String, not a StringName
	var big := PingsCallouts.callout_packet(WAIT)
	big.resize(PingsCallouts.CALLOUT_CAP_BYTES + 1)
	assert_dict(PingsCallouts.decode_callout(big)).is_empty()
	assert_dict(PingsCallouts.decode_callout(PingsCallouts.ping_packet(PingsCallouts.LOCATION))).is_empty()
	assert_dict(PingsCallouts.decode_ping(PingsCallouts.callout_packet(WAIT))).is_empty()


func test_only_the_first_callout_per_player_per_tick_is_kept() -> void:
	_pc.request_callout(A, PingsCallouts.callout_packet(DANGER))
	_pc.request_callout(A, PingsCallouts.callout_packet(WAIT))
	_pc.server_tick(0)
	assert_int(_pc.callouts().size()).is_equal(1)
	assert_str(_pc.callouts()[0].line).is_equal(DANGER)
