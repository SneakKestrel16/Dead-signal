class_name InputContextStack extends RefCounted
## Which client UI context owns input (ADR-0014 §1-3, §5). The top context wins: `move`, `look`, `actions`,
## `cursor` per the ADR §1 table. push/pop are the only entry points; a pop that does not name the top
## context is an error and changes nothing. The sole writer of Input.mouse_mode once a screen uses a
## cursor context: it writes only when the top context's `cursor` flag changes (GAMEPLAY and WHEEL never
## do), and again on reapply_mouse_mode() (focus-in). LocalInput still captures the mouse itself at start.
## Focus (§5): set `viewport` (a RefCounted has no get_viewport()); push remembers the focused control and
## grabs focus on `focus_owner`; pop restores the remembered control if it is still valid and visible, else
## the lower screen's default control.
## Not built yet: showing and hiding each context's UiLayers root on push/pop (§4), and discarding the
## first relative motion after a switch to captured (§3, Verification 4); both wait for the first screens.
## Usage (client root):
##   var contexts := InputContextStack.new()   # GAMEPLAY at the base
##   contexts.push(InputContextStack.Ctx.WHEEL, null); ...; contexts.pop(InputContextStack.Ctx.WHEEL)
##   contexts.reset(InputContextStack.Ctx.GAMEPLAY)   # round start; Ctx.MENU at round end / lobby

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

## The root viewport, for focus bookkeeping; null = no focus restore.
var viewport: Viewport

var _stack: Array[Ctx] = []
## Aligned with _stack. Untyped on purpose: a freed Control must stay readable (is_instance_valid), which a
## typed Array[Control] element read would error on.
var _remembered: Array = [] ## the control focused when the entry was pushed
var _defaults: Array = [] ## the screen's default control (push's focus_owner)


func _init(base: Ctx = Ctx.GAMEPLAY) -> void:
	_stack = [base]
	_remembered = [null]
	_defaults = [null]


## Pushes `ctx`; grabs focus on `focus_owner` when given.
func push(ctx: Ctx, focus_owner: Control) -> void:
	var was := top()
	_remembered.append(viewport.gui_get_focus_owner() if viewport != null else null)
	_defaults.append(focus_owner)
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
	var remembered: Variant = _remembered.pop_back()
	_defaults.pop_back()
	_restore_focus(remembered, _defaults.back())
	_changed(ctx)


## Drops every pushed context and makes `base` the only one: GAMEPLAY at round start, MENU at round end and on
## return to the lobby, so a stale OVERLAY cannot persist (ADR-0014 §1).
func reset(base: Ctx) -> void:
	var was := top()
	_stack = [base]
	_remembered = [null]
	_defaults = [null]
	_changed(was)


## The context on top.
func top() -> Ctx:
	return _stack[_stack.size() - 1]


func allows_move() -> bool:
	return FLAGS[top()][0]


func allows_look() -> bool:
	return FLAGS[top()][1]


func allows_actions() -> bool:
	return FLAGS[top()][2]


## True when `ctx` shows the mouse cursor.
static func wants_cursor(ctx: Ctx) -> bool:
	return FLAGS[ctx][3]


## Writes Input.mouse_mode for the top context; the client root calls it on NOTIFICATION_APPLICATION_FOCUS_IN
## because alt-tab drops the capture (ADR-0014 §3).
func reapply_mouse_mode() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if wants_cursor(top()) else Input.MOUSE_MODE_CAPTURED


func _restore_focus(remembered: Variant, lower_default: Variant) -> void:
	for c: Variant in [remembered, lower_default]:
		if c != null and is_instance_valid(c) and (c as Control).is_visible_in_tree():
			(c as Control).grab_focus()
			return


func _changed(was: Ctx) -> void:
	if wants_cursor(was) != wants_cursor(top()):
		reapply_mouse_mode()
	top_changed.emit(top())
