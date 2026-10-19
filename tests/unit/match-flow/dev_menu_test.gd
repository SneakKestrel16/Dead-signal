extends GdUnitTestSuite
## DevMenu (designer, 2026-10-18): F1 opens it only from gameplay as an overlay that frees the mouse, each
## button sends its DevCommands packet, and F1 or Esc shuts it.

var _stack: InputContextStack
var _sent: Array[PackedByteArray] = []


func before_test() -> void:
	_stack = InputContextStack.new()
	_sent.clear()


func _menu() -> DevMenu:
	var m := DevMenu.new(_stack, func(b: PackedByteArray) -> void: _sent.append(b))
	add_child(m)
	return m


func _f1() -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = DevMenu.TOGGLE_KEY
	k.pressed = true
	return k


func test_f1_opens_as_an_overlay_and_closes() -> void:
	var m := _menu()
	m._unhandled_input(_f1())
	assert_bool(m.is_open()).is_true()
	assert_int(_stack.top()).is_equal(InputContextStack.Ctx.OVERLAY)
	m._unhandled_input(_f1())
	assert_bool(m.is_open()).is_false()
	assert_int(_stack.top()).is_equal(InputContextStack.Ctx.GAMEPLAY)
	m.free()


func test_never_opens_over_another_menu() -> void:
	var m := _menu()
	_stack.push(InputContextStack.Ctx.MENU, null)
	m.toggle()
	assert_bool(m.is_open()).is_false()
	m.free()


func test_each_button_sends_its_command_and_every_scare_has_one() -> void:
	var m := _menu()
	m.buttons["last10"].pressed.emit()
	assert_array(_sent).is_equal([DevCommands.packet("last10")])
	for e: ScareEntry in ScareCatalogue.load_shipped().entries:
		assert_bool(m.buttons.has("scare:%s" % e.scare_id)).override_failure_message(String(e.scare_id)).is_true()
	m.free()
