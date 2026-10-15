extends GdUnitTestSuite
## Story hud-results/003 (design/ux/hud.md H7-H9 and the Z4 rule; interaction-patterns P2, P3, P10, P18;
## ADR-0014 §6, §8): InputGlyphs device switching, InteractionHud Z4 exclusivity and label timing, and the
## PredictedHoldBar end causes the ring reads.

const ACTION := &"test_glyph_action"
const DT := 0.05

var _knobs: Knobs
var _glyphs: InputGlyphs
var _contexts: InputContextStack
var _bar: PredictedHoldBar
var _hud: InteractionHud
var _prompt := {}
var _seq := 0


func before_test() -> void:
	_knobs = Knobs.load_all()
	InputMap.add_action(ACTION)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	InputMap.action_add_event(ACTION, key)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_X
	InputMap.action_add_event(ACTION, pad)
	_glyphs = InputGlyphs.new()
	_contexts = InputContextStack.new()
	_bar = auto_free(PredictedHoldBar.new())
	_bar.setup(_knobs)
	_prompt = {}
	_seq = 0
	_hud = auto_free(InteractionHud.new(_glyphs, _contexts, _bar, func() -> Dictionary: return _prompt, ACTION))


func after_test() -> void:
	InputMap.erase_action(ACTION)


func _frame(interact: bool) -> InputFrame:
	_seq += 1
	var f := InputFrame.new()
	f.seq = _seq
	f.interact = interact
	return f


func _steps(seconds: float) -> void:
	for i in roundi(seconds / DT):
		_hud.step(DT)


# --- InputGlyphs (P18) ---

func test_glyph_follows_the_last_used_device_class_by_event_type() -> void:
	assert_str(_glyphs.glyph_text(ACTION)).is_equal("E")
	var pad := InputEventJoypadButton.new()
	pad.device = 0 # a pad on device 0 is still a pad: the class comes from the event type, never device == 0
	_glyphs.note_event(pad)
	assert_int(_glyphs.device).is_equal(InputGlyphs.Device.GAMEPAD)
	assert_str(_glyphs.glyph_text(ACTION)).is_equal("X")
	var key := InputEventKey.new()
	key.device = 3
	_glyphs.note_event(key)
	assert_int(_glyphs.device).is_equal(InputGlyphs.Device.KEYBOARD_MOUSE)
	assert_str(_glyphs.glyph_text(ACTION)).is_equal("E")


func test_stick_noise_does_not_switch_but_a_deflection_does() -> void:
	var m := InputEventJoypadMotion.new()
	m.axis = JOY_AXIS_LEFT_X
	m.axis_value = 0.1
	_glyphs.note_event(m)
	assert_int(_glyphs.device).is_equal(InputGlyphs.Device.KEYBOARD_MOUSE)
	m.axis_value = -0.9
	_glyphs.note_event(m)
	assert_int(_glyphs.device).is_equal(InputGlyphs.Device.GAMEPAD)


func test_glyph_reads_the_live_input_map_so_a_remap_shows_at_once() -> void:
	InputMap.action_erase_events(ACTION)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	InputMap.action_add_event(ACTION, key)
	assert_str(_glyphs.glyph_text(ACTION)).is_equal("F")
	_glyphs.note_event(InputEventJoypadButton.new())
	assert_str(_glyphs.glyph_text(ACTION)).is_equal(InputGlyphs.UNBOUND)


# --- Prompt (H7) ---

func test_prompt_shows_verb_object_glyph_and_hold_or_press_and_switches_glyph() -> void:
	_prompt = {"text": "Extract drive", "hold": true}
	_hud.step(DT)
	assert_str(_hud.shown()).is_equal(&"prompt")
	assert_str(_hud.prompt_text()).is_equal("Hold E  Extract drive")
	_glyphs.note_event(InputEventJoypadButton.new())
	_hud.step(DT)
	assert_str(_hud.prompt_text()).is_equal("Hold X  Extract drive")
	_prompt = {"text": "Open door", "hold": false}
	_hud.step(DT)
	assert_str(_hud.prompt_text()).is_equal("Press X  Open door")
	_prompt = {}
	_hud.step(DT)
	assert_str(_hud.shown()).is_equal(&"")


# --- Z4 exclusivity (hud.md Layout rule) ---

func test_ring_replaces_the_prompt_and_another_z4_element_replaces_both() -> void:
	_prompt = {"text": "Hide", "hold": true}
	_bar.advance(_frame(true), true, 2.0)
	_hud.step(DT)
	assert_str(_hud.shown()).is_equal(&"ring")
	assert_float(_hud.ring_value()).is_greater(0.0)
	_hud.z4_taken = true # bleed-out or transforming bar
	_hud.step(DT)
	assert_str(_hud.shown()).is_equal(&"")
	_hud.z4_taken = false
	_contexts.push(InputContextStack.Ctx.WHEEL, null)
	_hud.step(DT)
	assert_str(_hud.shown()).is_equal(&"")


func test_wheel_suppresses_prompt_and_reject_label() -> void:
	_prompt = {"text": "Hide", "hold": true}
	_hud.refuse()
	_contexts.push(InputContextStack.Ctx.WHEEL, null)
	_hud.step(DT)
	assert_str(_hud.shown()).is_equal(&"")
	assert_str(_hud.label_text()).is_equal("")


# --- Cancel cause (H8) and reject label (H9) ---

func test_release_breaks_the_ring_for_200_ms_and_shows_its_cause() -> void:
	_bar.advance(_frame(true), true, 2.0)
	_hud.step(DT)
	_bar.advance(_frame(false), true, 2.0)
	_hud.step(DT)
	assert_str(_hud.shown()).is_equal(&"cancel")
	assert_str(_hud.label_text()).is_equal("Released")
	_steps(InteractionHud.RING_END_S)
	assert_str(_hud.shown()).is_equal(&"")
	assert_str(_hud.label_text()).is_equal("Released")
	_steps(InteractionHud.CAUSE_S)
	assert_str(_hud.label_text()).is_equal("")


func test_server_cancel_after_ack_is_interrupted_and_completion_has_no_label() -> void:
	var press := _frame(true)
	_bar.advance(press, true, 2.0)
	_bar.on_snapshot({"seq": press.seq, "hold_net_id": 4, "hold_elapsed_ticks": 1})
	_bar.on_snapshot({"seq": press.seq + 1, "hold_net_id": -1, "hold_elapsed_ticks": 0})
	_hud.step(DT)
	assert_str(_hud.shown()).is_equal(&"cancel")
	assert_str(_hud.label_text()).is_equal("Interrupted")
	_steps(InteractionHud.CAUSE_S + DT)
	_bar.advance(_frame(false), false, 0.0)
	press = _frame(true)
	_bar.advance(press, true, 0.1)
	var ticks := roundi(0.1 * _knobs.net.sim_tick_hz)
	_bar.on_snapshot({"seq": press.seq, "hold_net_id": 4, "hold_elapsed_ticks": ticks})
	_bar.on_snapshot({"seq": press.seq + 1, "hold_net_id": -1, "hold_elapsed_ticks": 0})
	_hud.step(DT)
	assert_str(_hud.shown()).is_equal(&"complete")
	assert_str(_hud.label_text()).is_equal("")


func test_refused_start_shows_the_reject_label_for_1_5_s() -> void:
	var press := _frame(true)
	_bar.advance(press, true, 2.0)
	_bar.on_snapshot({"seq": press.seq, "hold_net_id": -1, "hold_elapsed_ticks": 0})
	_hud.step(DT)
	assert_str(_hud.label_text()).is_equal("Not now")
	assert_str(_hud.shown()).is_not_equal(&"cancel")
	_steps(InteractionHud.REJECT_S - 2 * DT)
	assert_str(_hud.label_text()).is_equal("Not now")
	_steps(3 * DT) # one step of slack for float accumulation
	assert_str(_hud.label_text()).is_equal("")


func test_a_newer_label_replaces_the_older_one() -> void:
	_hud.refuse()
	_hud.step(DT)
	_hud.on_hold_ended(&"released")
	assert_str(_hud.label_text()).is_equal("Released")


# --- BUG-0008: reduced motion cuts the fades ---

func test_prompt_fades_in_over_fade_s_and_cuts_with_reduced_motion() -> void:
	_prompt = {"text": "Extract drive", "hold": true}
	_hud.step(DT / 5.0)
	assert_float(_hud.prompt_alpha()).is_less(1.0)
	_hud.reduced_motion = true
	assert_float(_hud.prompt_alpha()).is_equal(1.0)


func test_label_fade_cuts_with_reduced_motion() -> void:
	_hud.refuse()
	_steps(1.45)
	assert_float(_hud.label_alpha()).is_less(1.0)
	_hud.reduced_motion = true
	assert_float(_hud.label_alpha()).is_equal(1.0)
