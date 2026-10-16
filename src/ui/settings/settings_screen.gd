class_name SettingsScreen extends Control
## The settings screen (design/game-brief.md MVP; design/ux/interaction-patterns.md P15 Non-Pausing Overlay,
## P17 Dual-Device Menu Focus, P20 Toggle, P21 Slider). One row per PlayerSettings setting: a CheckButton
## showing "On"/"Off" as text, or an HSlider moving in 5% steps of its range with a percent readout. Every
## change writes the setting at once (live); the owner applies it (LobbyScreen forwards `changed`). Focus
## runs top to bottom and ends on Back; Esc / B (ui_cancel) and Esc / Start (menu) close it. It pushes `ctx`
## on `contexts` with the first row focused and pops it on exit, unless a reset already dropped it (round
## end, ADR-0014 §1). Closing saves the settings file.
## Deviations: no tab bar (P27) and no scroll (P28): twelve rows fit one page. No theme focus stylebox yet
## (P17): the stock focus ring is used. Mouse sensitivity and stick speed read as percent of their default.
## Usage:
##   var s := SettingsScreen.new(settings, contexts, InputContextStack.Ctx.OVERLAY, true)
##   s.closed.connect(s.queue_free); layer.add_child(s)

signal closed

## Row order and labels.
const ROWS: Array[Array] = [
	[&"reduced_motion", "Reduced motion"],
	[&"reduced_flash", "Reduced flash"],
	[&"flash_scale", "Flash intensity"],
	[&"camera_flinch", "Camera flinch"],
	[&"master_volume", "Master volume"],
	[&"effects_volume", "Effects volume"],
	[&"voice_volume", "Voice volume"],
	[&"stinger_volume", "Stinger volume"],
	[&"scare_volume", "Scare volume"],
	[&"mouse_sensitivity", "Mouse sensitivity"],
	[&"stick_rate", "Stick look speed"],
	[&"hud_scale", "HUD scale"],
]
## Settings whose readout is percent of their default rather than of 1.
const RELATIVE: Array[StringName] = [&"mouse_sensitivity", &"stick_rate"]
## Dim backing behind the panel (greybox; no art-direction spec yet).
const BACKING := Color(0.0, 0.0, 0.0, 0.8)

## key -> CheckButton or HSlider.
var controls: Dictionary[StringName, Control] = {}
## key -> percent readout (sliders only).
var readouts: Dictionary[StringName, Label] = {}
var back_button: Button
## Focus order, top to bottom.
var focus_stops: Array[Control] = []
## "The round continues" (P15), shown only over a round.
var round_note: Label

var _settings: PlayerSettings
var _contexts: InputContextStack
var _ctx: InputContextStack.Ctx
var _pushed := false


## `contexts` null = no context push (focus is grabbed directly). `in_round` shows the P15 note.
func _init(settings: PlayerSettings, contexts: InputContextStack,
		ctx: InputContextStack.Ctx = InputContextStack.Ctx.MENU, in_round := false) -> void:
	_settings = settings
	_contexts = contexts
	_ctx = ctx
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = BACKING
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	center.add_child(box)
	var title := Label.new()
	title.text = tr("Settings")
	box.add_child(title)
	round_note = Label.new()
	round_note.text = tr("The round continues")
	round_note.visible = in_round
	box.add_child(round_note)
	var grid := GridContainer.new()
	grid.columns = 3
	box.add_child(grid)
	for row in ROWS:
		_row(grid, row[0], row[1])
	back_button = Button.new()
	back_button.text = tr("Back")
	back_button.pressed.connect(closed.emit)
	box.add_child(back_button)
	focus_stops.append(back_button)


func _ready() -> void:
	_link_focus()
	if _contexts != null:
		_contexts.push(_ctx, focus_stops[0])
		_pushed = true
	else:
		focus_stops[0].grab_focus.call_deferred()


func _exit_tree() -> void:
	_settings.save()
	if _pushed:
		_pushed = false
		if _contexts.top() == _ctx: # a reset (round end) already dropped it
			_contexts.pop(_ctx)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"menu"):
		if is_inside_tree():
			get_viewport().set_input_as_handled()
		closed.emit()


func _row(grid: GridContainer, key: StringName, label: String) -> void:
	var l := Label.new()
	l.text = tr(label)
	grid.add_child(l)
	var spec: Array = PlayerSettings.SPEC[key]
	var c: Control
	if spec.size() < 3:
		var t := CheckButton.new()
		t.button_pressed = _settings.get(key)
		t.text = tr("On") if t.button_pressed else tr("Off")
		t.toggled.connect(_on_toggled.bind(key, t))
		c = t
		grid.add_child(c)
		grid.add_child(Control.new())
	else:
		var s := HSlider.new()
		s.min_value = spec[1]
		s.max_value = spec[2]
		s.step = (spec[2] - spec[1]) / 20.0 # P21: 5% steps
		s.value = _settings.get(key)
		s.custom_minimum_size = Vector2(260, 0)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var r := Label.new()
		r.custom_minimum_size = Vector2(64, 0)
		readouts[key] = r
		_readout(key, s.value)
		s.value_changed.connect(_on_slid.bind(key))
		c = s
		grid.add_child(c)
		grid.add_child(r)
	c.accessibility_name = tr(label)
	controls[key] = c
	focus_stops.append(c)


func _on_toggled(on: bool, key: StringName, t: CheckButton) -> void:
	t.text = tr("On") if on else tr("Off")
	_settings.set_value(key, on)


func _on_slid(value: float, key: StringName) -> void:
	_readout(key, value)
	_settings.set_value(key, value)


func _readout(key: StringName, value: float) -> void:
	var base: float = PlayerSettings.SPEC[key][0] if RELATIVE.has(key) else 1.0
	readouts[key].text = "%d%%" % roundi(value / base * 100.0)


## Up/down walk the rows; left/right stay on a toggle or button and move a slider (HSlider handles them).
func _link_focus() -> void:
	var last := focus_stops.size() - 1
	for i in focus_stops.size():
		var c := focus_stops[i]
		var prev := c.get_path_to(focus_stops[maxi(i - 1, 0)])
		var next := c.get_path_to(focus_stops[mini(i + 1, last)])
		c.focus_neighbor_top = prev
		c.focus_previous = prev
		c.focus_neighbor_bottom = next
		c.focus_next = next
		if not c is HSlider:
			c.focus_neighbor_left = NodePath(".")
			c.focus_neighbor_right = NodePath(".")
