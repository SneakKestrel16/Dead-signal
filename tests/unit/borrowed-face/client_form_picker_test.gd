# Story borrowed-face/011: the shipped client's form picker (design/gdd/borrowed-face.md rules 6-9, 14;
# design/ux/hud.md S1; interaction-patterns P6, P10; ADR-0014 §1-§3). The picker reads HudModel only, is a
# WHEEL context (movement live, look and actions off), sends BorrowedFace.request_packet and shows a server
# refusal (no transformation started within the round trip) through the HUD-3 label callable.
extends GdUnitTestSuite

const S1 := 2
const S2 := 3
const S3 := 4
## Appearance ids of the fake survivors (CharacterDef ids 1-5 are survivors; 0 is the true form).
const APP := {2: 1, 3: 2, 4: 3}
const RTT_TICKS := 6

var _knobs: Knobs
var _model: HudModel
var _contexts: InputContextStack
var _picker: FormPicker
var _sent: Array[PackedByteArray] = []
var _refusals := 0
var _latest := 100


func before_test() -> void:
	_sent = []
	_refusals = 0
	_latest = 100
	_knobs = Knobs.load_all()
	_model = HudModel.new(MatchDisplay.new(_knobs), _knobs)
	_contexts = InputContextStack.new()
	_picker = auto_free(FormPicker.new(_model, _contexts, _knobs, _send, _refuse, _latest_tick, _rtt))


func _send(bytes: PackedByteArray) -> void:
	_sent.append(bytes)


func _refuse() -> void:
	_refusals += 1


func _latest_tick() -> int:
	return _latest


func _rtt() -> int:
	return RTT_TICKS


## S1 face state: S1 observed, S2 half observed, S3 observed; `transform_end` -1 = none running.
func _hud(transform_end: int = -1) -> void:
	var full := _knobs.borrowed_face.observe_time_s
	_model.on_monster_hud(_latest, {"ready": {&"lunge": 0, &"form": 0}, "transform_end": transform_end,
		"stun_end": -1, "immune_end": -1,
		"faces": [[S1, full, APP[S1]], [S2, full / 2.0, APP[S2]], [S3, full, APP[S3]]]})


func _own_form(appearance: int) -> void:
	_model.on_own_body({"appearance": appearance})


## Aims at entry `i` of the open wheel and closes it, sending.
func _pick(i: int) -> bool:
	var n := _picker.entries().size()
	_picker.aim(Vector2.UP.rotated(TAU * i / n) * FormPicker.WHEEL_RADIUS_PX)
	return _picker.close(true)


func test_survivor_client_cannot_open_the_picker() -> void:
	_picker.open()
	assert_bool(_picker.is_open()).is_false()
	assert_int(_contexts.top()).is_equal(InputContextStack.Ctx.GAMEPLAY)


func test_entries_are_true_form_then_each_survivor_with_server_availability() -> void:
	_hud()
	_own_form(APP[S3]) # disguised as S3
	_model.on_survivor_event(0, {"survivor": S1}, &"SurvivorEliminated")
	var e := _picker.entries()
	assert_array(e.map(func(d: Dictionary) -> int: return d["form"])).is_equal([BorrowedFace.TRUE_FORM, S1, S2, S3])
	# true form: available (not current); S1 observed but Eliminated (rule 6); S2 not observed; S3 is the current form
	assert_array(e.map(func(d: Dictionary) -> bool: return d["available"])).is_equal([true, false, false, false])
	assert_array(e.map(func(d: Dictionary) -> bool: return d["current"])).is_equal([false, false, false, true])


func test_open_is_a_wheel_context_movement_live_look_and_actions_off() -> void:
	_hud()
	_picker.open()
	assert_bool(_picker.is_open()).is_true()
	assert_int(_contexts.top()).is_equal(InputContextStack.Ctx.WHEEL)
	assert_bool(_contexts.allows_move()).is_true()
	assert_bool(_contexts.allows_look()).is_false()
	_picker.close(false)
	assert_int(_contexts.top()).is_equal(InputContextStack.Ctx.GAMEPLAY)
	assert_array(_sent).is_empty()


func test_not_opened_while_another_context_holds_input() -> void:
	_hud()
	_contexts.push(InputContextStack.Ctx.OVERLAY, null)
	_picker.open()
	assert_bool(_picker.is_open()).is_false()


func test_choosing_an_available_survivor_sends_its_request_packet() -> void:
	_hud()
	_own_form(CharacterDef.TRUE_FORM_APPEARANCE_ID)
	_picker.open()
	assert_bool(_pick(1)).is_true()
	assert_int(_sent.size()).is_equal(1)
	assert_int(BorrowedFace.decode_request(_sent[0])).is_equal(S1)
	assert_int(_contexts.top()).is_equal(InputContextStack.Ctx.GAMEPLAY)


func test_choosing_true_form_sends_the_true_form_request() -> void:
	_hud()
	_own_form(APP[S1])
	_picker.open()
	_pick(0)
	assert_int(BorrowedFace.decode_request(_sent[0])).is_equal(BorrowedFace.TRUE_FORM)


func test_an_unavailable_form_is_never_sent_and_shows_the_refusal() -> void:
	_hud()
	_picker.open()
	assert_bool(_pick(2)).is_false() # S2: not observed
	assert_array(_sent).is_empty()
	assert_int(_refusals).is_equal(1)


func test_dead_zone_cancels_with_nothing_sent() -> void:
	_hud()
	_picker.open()
	assert_bool(_picker.close(true)).is_false()
	assert_array(_sent).is_empty()
	assert_int(_refusals).is_equal(0)


func test_no_transformation_within_the_round_trip_is_a_refusal_shown_once() -> void:
	_hud()
	_picker.open()
	_pick(1)
	var deadline := 100 + RTT_TICKS + _knobs.net.slack_ticks
	_latest = deadline
	_picker.advance()
	assert_int(_refusals).is_equal(0)
	_latest = deadline + 1
	_picker.advance()
	_latest += 30
	_picker.advance()
	assert_int(_refusals).is_equal(1)


func test_a_started_transformation_is_no_refusal() -> void:
	_hud()
	_picker.open()
	_pick(1)
	_latest = 104
	_hud(104 + _knobs.ticks(_knobs.borrowed_face.transform_duration_s))
	_picker.advance()
	_latest = 200
	_picker.advance()
	assert_int(_refusals).is_equal(0)


func test_a_request_while_already_transforming_is_still_judged() -> void:
	_hud(150)
	_picker.open()
	_pick(1)
	_latest = 200
	_picker.advance()
	assert_int(_refusals).is_equal(1)
