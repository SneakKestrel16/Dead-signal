extends GdUnitTestSuite
## BUG-0014 (ADR-0014 §3, Verification 4): the first relative mouse motion after InputContextStack switches
## back to the captured mouse, or re-applies it on app focus-in, does not turn the view; the next one does.

const BIG := Vector2(400, 0)
const SMALL := Vector2(10, 0)

var _stack: InputContextStack
var _li: LocalInput


func before_test() -> void:
	_stack = InputContextStack.new()
	_li = auto_free(LocalInput.new())
	_li.contexts = _stack


func _motion(rel: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.relative = rel
	e.screen_relative = rel
	return e


func test_motion_before_any_recapture_turns_the_view() -> void:
	_li.handle(_motion(SMALL))
	assert_float(_li.yaw).is_not_zero()


func test_first_motion_after_overlay_pop_is_discarded_then_motion_turns() -> void:
	_stack.push(InputContextStack.Ctx.OVERLAY, null)
	_stack.pop(InputContextStack.Ctx.OVERLAY)
	_li.handle(_motion(BIG))
	assert_float(_li.yaw).is_zero()
	_li.handle(_motion(SMALL))
	assert_float(_li.yaw).is_equal_approx(-SMALL.x * _li.sensitivity, 1e-6)


func test_first_motion_after_focus_in_reapply_is_discarded() -> void:
	_stack.reapply_mouse_mode()
	_li.handle(_motion(BIG))
	assert_float(_li.yaw).is_zero()
	_li.handle(_motion(SMALL))
	assert_float(_li.yaw).is_not_zero()


func test_stick_motion_does_not_use_up_the_discard() -> void:
	_stack.reapply_mouse_mode()
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 0.0
	_li.handle(stick)
	_li.handle(_motion(BIG))
	assert_float(_li.yaw).is_zero()


func test_switch_to_cursor_context_does_not_arm_the_discard() -> void:
	_stack.push(InputContextStack.Ctx.OVERLAY, null)
	assert_bool(_stack.take_motion_discard()).is_false()


## The verifier saw the engine deliver a zero-relative motion after the capture switch, which spent the
## discard so the next real motion turned the view a full radian (BUG-0014 reopened, 2026-10-15).
func test_zero_motion_does_not_use_up_the_discard() -> void:
	_stack.reapply_mouse_mode()
	_li.handle(_motion(Vector2.ZERO))
	_li.handle(_motion(BIG))
	assert_float(_li.yaw).is_zero()
	_li.handle(_motion(SMALL))
	assert_float(_li.yaw).is_not_zero()
