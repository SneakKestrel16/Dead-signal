class_name InputBindings extends RefCounted
## Player rebinding of InputMap actions (design/accessibility-requirements.md Motor, "Full input remapping":
## keyboard/mouse and gamepad independently, mouse buttons bindable, conflicts warned, saved locally).
## Each rebindable action has one keyboard/mouse slot and one gamepad slot: rebinding a slot replaces that
## action's first event of the slot's kind in the live InputMap, so InputGlyphs prompts follow at once (P18).
## Bindings are stored as short strings ("key:87", "mouse:1", "joybutton:2", "joyaxis:4:1"), never as
## serialized objects, so the settings file holds no code. The project defaults are read from ProjectSettings
## (never from the live map, which a rebind changes).
## Usage:
##   InputBindings.apply(settings.bindings)                       # at load
##   var code := InputBindings.encode(event); InputBindings.bind(&"interact", KB, event)

enum Slot { KB, PAD }

## Rebindable actions in screen order, with their labels. Menu (Esc / Start) stays fixed, so a bad binding can
## always be undone.
const ACTIONS: Array[Array] = [
	[&"move_forward", "Move forward"], [&"move_back", "Move back"], [&"move_left", "Move left"],
	[&"move_right", "Move right"], [&"sprint", "Sprint"], [&"crouch", "Crouch"], [&"interact", "Interact"],
	[&"interact_alt", "Interact (alternate)"], [&"use_item", "Use item"], [&"flashlight", "Flashlight"],
	[&"ping", "Ping"], [&"warning_ping", "Warning ping"], [&"callout_wheel", "Callout wheel"],
	[&"feed_scrollback", "Feed scrollback"], [&"push_to_talk", "Push to talk"], [&"lunge", "Lunge"],
	[&"false_signal", "False Signal"], [&"blackout", "Blackout"], [&"form_picker", "Form picker"],
]


## The slot an event belongs to.
static func slot_of(e: InputEvent) -> Slot:
	return Slot.PAD if e is InputEventJoypadButton or e is InputEventJoypadMotion else Slot.KB


## A storable code for a bindable event, or "" for one that cannot be bound (a release, a small stick nudge).
static func encode(e: InputEvent) -> String:
	if e is InputEventKey:
		var k := e as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		return "key:%d" % code if code != KEY_NONE else ""
	if e is InputEventMouseButton:
		return "mouse:%d" % (e as InputEventMouseButton).button_index
	if e is InputEventJoypadButton:
		return "joybutton:%d" % (e as InputEventJoypadButton).button_index
	if e is InputEventJoypadMotion:
		var m := e as InputEventJoypadMotion
		if absf(m.axis_value) < InputGlyphs.SWITCH_AXIS:
			return ""
		return "joyaxis:%d:%d" % [m.axis, 1 if m.axis_value > 0.0 else -1]
	return ""


## The event a code stands for, or null for an unreadable code (untrusted file text).
static func decode(code: String) -> InputEvent:
	var parts := code.split(":")
	if parts.size() < 2 or not parts[1].is_valid_int():
		return null
	var n := parts[1].to_int()
	match parts[0]:
		"key":
			var k := InputEventKey.new()
			k.physical_keycode = n as Key
			return k
		"mouse":
			var b := InputEventMouseButton.new()
			b.button_index = n as MouseButton
			return b
		"joybutton":
			var j := InputEventJoypadButton.new()
			j.button_index = n as JoyButton
			return j
		"joyaxis":
			if parts.size() != 3 or not parts[2].is_valid_int():
				return null
			var a := InputEventJoypadMotion.new()
			a.axis = n as JoyAxis
			a.axis_value = 1.0 if parts[2].to_int() > 0 else -1.0
			return a
	return null


## The project's default events of `action` (project.godot), whatever the live map holds now.
static func defaults(action: StringName) -> Array:
	var d: Variant = ProjectSettings.get_setting("input/" + action)
	return (d as Dictionary).get("events", []) if d is Dictionary else []


## The live event of `action` in `slot`, or null.
static func event_of(action: StringName, slot: Slot) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for e: InputEvent in InputMap.action_get_events(action):
		if slot_of(e) == slot:
			return e
	return null


## Puts `e` in `action`'s slot of its kind in the live InputMap, replacing the slot's event.
static func bind(action: StringName, e: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	var old := event_of(action, slot_of(e))
	if old != null:
		InputMap.action_erase_event(action, old)
	InputMap.action_add_event(action, e)


## Restores every rebindable action to the project defaults.
static func reset_all() -> void:
	for row in ACTIONS:
		var action: StringName = row[0]
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
			for e: InputEvent in defaults(action):
				InputMap.action_add_event(action, e)


## Applies stored bindings ({action: {"kb": code, "pad": code}}) over the defaults. Unknown actions and
## unreadable codes are skipped.
static func apply(stored: Dictionary) -> void:
	reset_all()
	for action: Variant in stored:
		if not (action is StringName or action is String) or not stored[action] is Dictionary:
			continue
		for key: String in ["kb", "pad"]:
			var code: Variant = stored[action].get(key)
			var e := decode(code) if code is String else null
			if e != null and slot_of(e) == (Slot.KB if key == "kb" else Slot.PAD):
				bind(StringName(action), e)


## The other rebindable actions whose live binding matches `e` (the conflict warning).
static func conflicts(action: StringName, e: InputEvent) -> Array[StringName]:
	var out: Array[StringName] = []
	var code := encode(e)
	for row in ACTIONS:
		var other: StringName = row[0]
		if other == action:
			continue
		var o := event_of(other, slot_of(e))
		if o != null and encode(o) == code:
			out.append(other)
	return out


## The label of a rebindable action.
static func label_of(action: StringName) -> String:
	for row in ACTIONS:
		if row[0] == action:
			return row[1]
	return String(action)
