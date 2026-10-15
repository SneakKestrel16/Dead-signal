class_name InputGlyphs extends RefCounted
## Input glyph of an action for the last-used device class (ADR-0014 §8; interaction-patterns P18). The class
## switches on the event type (key or mouse vs joypad), never on `device == 0` (4.7 gives mouse and keyboard
## their own InputEvent.DEVICE_ID_* values, docs/engine-reference/godot/deprecated-apis.md). It reads the live
## InputMap each call, so a remapped binding shows at once.
## PLACEHOLDER: glyphs are text ("E", "X", "Mouse 1"), not the Texture2D the ADR's glyph_for names; the art
## pass adds textures behind the same lookup.
## Usage: forward every input event to note_event(); label.text = glyphs.glyph_text(&"interact").

signal device_changed

enum Device { KEYBOARD_MOUSE, GAMEPAD }

## Shown when the action has no binding for the current device class.
const UNBOUND := "?"
## A stick or trigger below this deflection is noise and does not switch the class. Inference: the 0.2 action
## dead zone in project.godot is for actions; a switch wants a deliberate push. Playtest settles it.
const SWITCH_AXIS := 0.5
## SDL / Xbox face and shoulder names by JoyButton index (placeholder text glyphs).
const PAD_BUTTONS: PackedStringArray = ["A", "B", "X", "Y", "Back", "Guide", "Start", "LS", "RS", "LB", "RB",
	"Up", "Down", "Left", "Right"]
const PAD_AXES: PackedStringArray = ["LS", "LS", "RS", "RS", "LT", "RT"]

var device := Device.KEYBOARD_MOUSE


## Switches the device class by the event's type.
func note_event(event: InputEvent) -> void:
	var d := device
	if event is InputEventJoypadButton:
		d = Device.GAMEPAD
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= SWITCH_AXIS:
			d = Device.GAMEPAD
	elif event is InputEventKey or event is InputEventMouse:
		d = Device.KEYBOARD_MOUSE
	if d != device:
		device = d
		device_changed.emit()


## Text glyph of the first InputMap event of `action` for the current device class; UNBOUND when none.
func glyph_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return UNBOUND
	for e: InputEvent in InputMap.action_get_events(action):
		var pad := e is InputEventJoypadButton or e is InputEventJoypadMotion
		if pad != (device == Device.GAMEPAD):
			continue
		if e is InputEventKey:
			var k := e as InputEventKey
			return OS.get_keycode_string(k.keycode if k.keycode != KEY_NONE else k.physical_keycode)
		if e is InputEventMouseButton:
			return "Mouse %d" % (e as InputEventMouseButton).button_index
		if e is InputEventJoypadButton:
			var b := (e as InputEventJoypadButton).button_index
			return PAD_BUTTONS[b] if b >= 0 and b < PAD_BUTTONS.size() else "Pad %d" % b
		if e is InputEventJoypadMotion:
			var a := (e as InputEventJoypadMotion).axis
			return PAD_AXES[a] if a >= 0 and a < PAD_AXES.size() else "Axis %d" % a
	return UNBOUND
