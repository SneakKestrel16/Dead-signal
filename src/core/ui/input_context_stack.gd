class_name InputContextStack extends RefCounted
## Which client UI context owns input (ADR-0014 §1-3). The top context wins: `move`, `look`, `actions`,
## `cursor` per the ADR §1 table. push/pop are the only entry points; a pop that does not name the top
## context is an error and changes nothing.
## Minimal first cut (story pings-and-callouts/008, for the callout wheel's WHEEL context): focus restore
## (§5) and the round start/end reset are not built yet, and LocalInput still captures the mouse itself;
## this stack writes Input.mouse_mode only when the top context's `cursor` flag changes, which GAMEPLAY and
## WHEEL never do. Settled when the HUD epic adds OVERLAY/MENU screens.
## Usage (client root):
##   var contexts := InputContextStack.new()   # GAMEPLAY at the base
##   contexts.push(InputContextStack.Ctx.WHEEL, null); ...; contexts.pop(InputContextStack.Ctx.WHEEL)

enum Ctx { GAMEPLAY, WHEEL, OVERLAY, MENU, MODAL }

## ADR-0014 §1 table: [move, look, actions, cursor] per context.
const FLAGS := {
	Ctx.GAMEPLAY: [true, true, true, false],
	Ctx.WHEEL: [true, false, false, false],
	Ctx.OVERLAY: [false, false, false, true],
	Ctx.MENU: [false, false, false, true],
	Ctx.MODAL: [false, false, false, true],
}

signal top_changed(ctx: Ctx)

var _stack: Array[Ctx] = []


func _init(base: Ctx = Ctx.GAMEPLAY) -> void:
	_stack = [base]


## Pushes `ctx`; grabs focus on `focus_owner` when given.
func push(ctx: Ctx, focus_owner: Control) -> void:
	var was := top()
	_stack.append(ctx)
	if focus_owner != null:
		focus_owner.grab_focus.call_deferred()
	_changed(was)


## Pops `ctx`, which must be on top (else push_error and nothing changes). The base is never popped.
func pop(ctx: Ctx) -> void:
	if _stack.size() < 2 or top() != ctx:
		push_error("InputContextStack: pop(%s) but top is %s" % [Ctx.keys()[ctx], Ctx.keys()[top()]])
		return
	_stack.pop_back()
	_changed(ctx)


## The context on top.
func top() -> Ctx:
	return _stack[_stack.size() - 1]


func allows_move() -> bool:
	return FLAGS[top()][0]


func allows_look() -> bool:
	return FLAGS[top()][1]


func allows_actions() -> bool:
	return FLAGS[top()][2]


func _changed(was: Ctx) -> void:
	if FLAGS[was][3] != FLAGS[top()][3] and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if FLAGS[top()][3] else Input.MOUSE_MODE_CAPTURED
	top_changed.emit(top())
