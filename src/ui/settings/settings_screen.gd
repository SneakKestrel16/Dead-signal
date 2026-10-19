class_name SettingsScreen extends Control
## The settings screen (design/game-brief.md MVP; design/ux/interaction-patterns.md P15 Non-Pausing Overlay,
## P17 Dual-Device Menu Focus, P20 Toggle, P21 Slider, P27 Tab Bar). Four tabs, Video, Audio, Controls and
## Accessibility, one row per PlayerSettings setting: a CheckButton showing "On"/"Off" as text, an HSlider
## moving in 5% steps of its range with a percent readout, or an OptionButton for a choice. Controls also lists
## every rebindable action (InputBindings) with a keyboard/mouse and a gamepad button: press one, then the new
## input (Esc cancels); a binding another action shares is warned, not refused (accessibility-requirements.md
## Motor), and Reset restores the defaults. Every change writes the setting at once (live); the owner applies
## it (LobbyScreen forwards `changed`). Focus starts on the tab bar (left/right switch tabs), runs down the
## open tab and ends on Back; Esc / B (ui_cancel) and Esc / Start (menu) close it. It pushes `ctx` on
## `contexts` and pops it on exit, unless a reset already dropped it (round end, ADR-0014 §1). Closing saves
## the settings file.
## Deviations: no theme focus stylebox yet (P17): the stock focus ring is used. Mouse sensitivity and stick
## speed read as percent of their default. Controls scrolls (P28) because its actions do not fit one page.
## Usage:
##   var s := SettingsScreen.new(settings, contexts, InputContextStack.Ctx.OVERLAY, true)
##   s.closed.connect(s.queue_free); layer.add_child(s)

signal closed

## Tabs in order (P27), each with its rows: [setting key, label].
const TABS: Array[Array] = [
	["Video", [
		[&"window_mode", "Window mode"],
		[&"vsync", "V-Sync"],
		[&"fps_limit", "Frame rate limit"],
		[&"render_scale", "Render scale"],
	]],
	["Audio", [
		[&"master_volume", "Master volume"],
		[&"effects_volume", "Effects volume"],
		[&"voice_volume", "Callout voice volume"],
		[&"stinger_volume", "Stinger volume"],
		[&"scare_volume", "Scare volume"],
		[&"voice_chat_volume", "Voice chat volume"],
		[&"mic_device", "Microphone"],
		[&"mic_mode", "Microphone mode"],
		[&"mic_volume", "Microphone volume"],
	]],
	["Controls", [
		[&"mouse_sensitivity", "Mouse sensitivity"],
		[&"stick_rate", "Stick look speed"],
	]],
	["Accessibility", [
		[&"reduced_motion", "Reduced motion"],
		[&"reduced_flash", "Reduced flash"],
		[&"flash_scale", "Flash intensity"],
		[&"camera_flinch", "Camera flinch"],
		[&"hud_scale", "HUD scale"],
		[&"captions", "Captions"],
	]],
]
## The tab holding the rebinding rows.
const CONTROLS_TAB := 2
## Settings whose readout is percent of their default rather than of 1.
const RELATIVE: Array[StringName] = [&"mouse_sensitivity", &"stick_rate"]
## Dim backing behind the panel over a round (greybox; no art-direction spec yet): the round stays visible (P15).
const BACKING := Color(0.0, 0.0, 0.0, 0.8)
## Backing over the lobby: opaque, or the form's fields read through the settings rows.
const MENU_BACKING := Color(0.0, 0.0, 0.0, 1.0)
## Panel size: fits every tab but Controls, which scrolls.
const PANEL_SIZE := Vector2(720, 560)

## key -> CheckButton, HSlider or OptionButton.
var controls: Dictionary[StringName, Control] = {}
## key -> percent readout (sliders only).
var readouts: Dictionary[StringName, Label] = {}
## action -> [keyboard/mouse Button, gamepad Button].
var bind_buttons: Dictionary[StringName, Array] = {}
## Conflict warning under the rebinding rows ("" when none).
var bind_note: Label
var reset_bindings_button: Button
var tabs: TabContainer
var back_button: Button
## Focus order of the open tab: the tab bar, its rows, then Back.
var focus_stops: Array[Control] = []
## "The round continues" (P15), shown only over a round.
var round_note: Label

var _settings: PlayerSettings
var _contexts: InputContextStack
var _ctx: InputContextStack.Ctx
var _pushed := false
## Per tab, its focusable rows in order.
var _tab_stops: Array[Array] = []
## [action, slot, button] while waiting for the new input; empty otherwise.
var _capturing: Array = []


## `contexts` null = no context push (focus is grabbed directly). `in_round` shows the P15 note.
func _init(settings: PlayerSettings, contexts: InputContextStack,
		ctx: InputContextStack.Ctx = InputContextStack.Ctx.MENU, in_round := false) -> void:
	_settings = settings
	_contexts = contexts
	_ctx = ctx
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = BACKING if in_round else MENU_BACKING
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(PANEL_SIZE.x, 0)
	center.add_child(box)
	var title := Label.new()
	title.text = tr("Settings")
	box.add_child(title)
	round_note = Label.new()
	round_note.text = tr("The round continues")
	round_note.visible = in_round
	box.add_child(round_note)
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, PANEL_SIZE.y)
	box.add_child(tabs)
	for i in TABS.size():
		var scroll := ScrollContainer.new()
		scroll.name = tr(TABS[i][0])
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		tabs.add_child(scroll)
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(page)
		var grid := GridContainer.new()
		grid.columns = 3
		page.add_child(grid)
		var stops: Array[Control] = []
		for row: Array in TABS[i][1]:
			stops.append(_row(grid, row[0], row[1]))
		if i == CONTROLS_TAB:
			stops.append_array(_binding_rows(page))
		_tab_stops.append(stops)
	tabs.tab_changed.connect(_on_tab_changed)
	back_button = Button.new()
	back_button.text = tr("Back")
	back_button.pressed.connect(closed.emit)
	box.add_child(back_button)


func _ready() -> void:
	_relink()
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


## While rebinding, the next input of the slot's kind becomes the binding; Esc cancels. Runs before GUI and
## gameplay input, so the pressed key reaches nothing else.
func _input(event: InputEvent) -> void:
	if _capturing.is_empty() or not is_inside_tree():
		return
	var key := event as InputEventKey
	if key != null and key.pressed and key.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_end_capture()
		return
	if not event.is_pressed() or event.is_echo() or InputBindings.encode(event).is_empty():
		return
	if InputBindings.slot_of(event) != _capturing[1]:
		return
	get_viewport().set_input_as_handled()
	var action: StringName = _capturing[0]
	_settings.set_binding(action, event)
	var others := InputBindings.conflicts(action, event)
	bind_note.text = "" if others.is_empty() else tr("%s is also bound to %s") % [InputGlyphs.event_text(event),
		", ".join(others.map(func(a: StringName) -> String: return tr(InputBindings.label_of(a))))]
	_end_capture()


func _unhandled_input(event: InputEvent) -> void:
	if not _capturing.is_empty():
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"menu"):
		if is_inside_tree():
			get_viewport().set_input_as_handled()
		closed.emit()


## Whether a rebind is waiting for its input.
func is_capturing() -> bool:
	return not _capturing.is_empty()


## Starts rebinding `action`'s `slot` (InputBindings.Slot): the button asks for the new input.
func begin_capture(action: StringName, slot: InputBindings.Slot) -> void:
	_end_capture()
	var b: Button = bind_buttons[action][slot]
	b.text = tr("Press a key...") if slot == InputBindings.Slot.KB else tr("Press a button...")
	_capturing = [action, slot, b]


func _end_capture() -> void:
	if _capturing.is_empty():
		return
	var action: StringName = _capturing[0]
	_capturing = []
	_refresh_binding(action)


func _row(grid: GridContainer, key: StringName, label: String) -> Control:
	var l := Label.new()
	l.text = tr(label)
	grid.add_child(l)
	var spec: Array = PlayerSettings.SPEC[key]
	var c: Control
	if spec.size() == 1:
		var t := CheckButton.new()
		t.button_pressed = _settings.get(key)
		t.text = tr("On") if t.button_pressed else tr("Off")
		t.toggled.connect(_on_toggled.bind(key, t))
		c = t
		grid.add_child(c)
		grid.add_child(Control.new())
	elif spec.size() == 2:
		var o := OptionButton.new()
		var choices := PackedStringArray(spec[1])
		if spec[0] is String: # filled at runtime: the system's microphones
			choices = PackedStringArray(AudioServer.get_input_device_list()) if DisplayServer.get_name() != "headless" \
					else PackedStringArray(["Default"])
			if not _settings.get(key) in choices:
				choices.insert(0, _settings.get(key))
		for ch in choices:
			o.add_item(tr(ch) if not spec[0] is String else ch)
		o.selected = choices.find(_settings.get(key)) if spec[0] is String else _settings.get(key)
		o.item_selected.connect(_on_chosen.bind(key, o))
		o.custom_minimum_size = Vector2(260, 0)
		c = o
		grid.add_child(c)
		grid.add_child(Control.new())
	else:
		var s := HSlider.new()
		s.min_value = spec[1]
		s.max_value = spec[2]
		# P21: 5% steps. Of 1 for the percent readouts (hud_scale's range / 20 = 0.0375 left 1.0 off the grid: 101%).
		s.step = (spec[2] - spec[1]) / 20.0 if RELATIVE.has(key) else 0.05
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
	return c


## The rebinding rows under the Controls sliders; returns their focus stops in order.
func _binding_rows(page: VBoxContainer) -> Array[Control]:
	var stops: Array[Control] = []
	var head := Label.new()
	head.text = tr("Key bindings  (keyboard / mouse, gamepad)")
	page.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 3
	page.add_child(grid)
	for row: Array in InputBindings.ACTIONS:
		var action: StringName = row[0]
		if not InputMap.has_action(action):
			continue
		var l := Label.new()
		l.text = tr(row[1])
		l.custom_minimum_size = Vector2(260, 0)
		grid.add_child(l)
		var pair: Array = []
		for slot: InputBindings.Slot in [InputBindings.Slot.KB, InputBindings.Slot.PAD]:
			var b := Button.new()
			b.custom_minimum_size = Vector2(180, 0)
			b.accessibility_name = "%s, %s" % [tr(row[1]), tr("keyboard") if slot == InputBindings.Slot.KB else tr("gamepad")]
			b.pressed.connect(begin_capture.bind(action, slot))
			grid.add_child(b)
			pair.append(b)
			stops.append(b)
		bind_buttons[action] = pair
		_refresh_binding(action)
	bind_note = Label.new()
	page.add_child(bind_note)
	reset_bindings_button = Button.new()
	reset_bindings_button.text = tr("Reset key bindings")
	reset_bindings_button.pressed.connect(_on_reset_bindings)
	page.add_child(reset_bindings_button)
	stops.append(reset_bindings_button)
	return stops


func _refresh_binding(action: StringName) -> void:
	for slot: InputBindings.Slot in [InputBindings.Slot.KB, InputBindings.Slot.PAD]:
		var e := InputBindings.event_of(action, slot)
		(bind_buttons[action][slot] as Button).text = InputGlyphs.event_text(e) if e != null else tr("Unbound")


func _on_reset_bindings() -> void:
	_end_capture()
	_settings.reset_bindings()
	bind_note.text = ""
	for action: StringName in bind_buttons:
		_refresh_binding(action)


func _on_toggled(on: bool, key: StringName, t: CheckButton) -> void:
	t.text = tr("On") if on else tr("Off")
	_settings.set_value(key, on)


func _on_chosen(index: int, key: StringName, o: OptionButton) -> void:
	_settings.set_value(key, o.get_item_text(index) if PlayerSettings.SPEC[key][0] is String else index)


func _on_slid(value: float, key: StringName) -> void:
	_readout(key, value)
	_settings.set_value(key, value)


func _readout(key: StringName, value: float) -> void:
	var base: float = PlayerSettings.SPEC[key][0] if RELATIVE.has(key) else 1.0
	readouts[key].text = "%d%%" % roundi(value / base * 100.0)


func _on_tab_changed(_tab: int) -> void:
	_end_capture()
	_relink()


## Focus stops for the open tab, linked top to bottom: up/down walk them; left/right switch tabs on the tab
## bar, stay put on toggles and buttons, and move a slider (HSlider handles them).
func _relink() -> void:
	var bar := tabs.get_tab_bar()
	bar.focus_mode = Control.FOCUS_ALL
	focus_stops = [bar]
	for c: Control in _tab_stops[tabs.current_tab]:
		focus_stops.append(c)
	focus_stops.append(back_button)
	var last := focus_stops.size() - 1
	for i in focus_stops.size():
		var c := focus_stops[i]
		var prev := c.get_path_to(focus_stops[maxi(i - 1, 0)])
		var next := c.get_path_to(focus_stops[mini(i + 1, last)])
		c.focus_neighbor_top = prev
		c.focus_previous = prev
		c.focus_neighbor_bottom = next
		c.focus_next = next
		if not (c is HSlider or c == bar):
			c.focus_neighbor_left = NodePath(".")
			c.focus_neighbor_right = NodePath(".")
