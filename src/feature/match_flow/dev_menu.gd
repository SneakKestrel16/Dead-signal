class_name DevMenu extends Control
## The dev menu (designer, 2026-10-18: "a dev menu to trigger each thing for testing"). F1 in a debug build
## opens it over the round as a non-pausing overlay (P15: the round continues); F1, Esc or Close shuts it.
## Each button sends one DevCommands command to the server, which runs it on the real round: clock skips
## (Evacuation, 1:00, 0:30, 0:10 left, which also plays the PA lines), Power Restored, Blackout here, every
## catalogue scare, and a forced win for either side. Release builds never mount it (DevCommands.enabled).
## Nothing here changes game state on the client.
## Usage (RoundClient, client):
##   if DevCommands.enabled(): hud.add_child(DevMenu.new(ping_hud.contexts, send_bytes_to_server))

## Toggle key (fixed: a dev tool, not a rebindable action).
const TOGGLE_KEY := KEY_F1
## Buttons in order: [label, command]. Scare buttons follow, one per catalogue entry.
const COMMANDS: Array[Array] = [
	["Skip to Evacuation", "evac"], ["Skip to 1:00 left", "last60"], ["Skip to 0:30 left", "last30"],
	["Skip to 0:10 left", "last10"], ["Power restored", "power"], ["Blackout here", "blackout"],
	["Survivors win now", "win_survivors"], ["Shapeshifter wins now", "win_shapeshifter"],
]
const BACKING := Color(0.0, 0.0, 0.0, 0.75)

## command -> its Button (checks).
var buttons: Dictionary[String, Button] = {}
## Commands sent, newest last (checks).
var sent: Array[String] = []

var _contexts: InputContextStack
var _send: Callable
var _panel: Control
var _open := false


## `contexts`: the round's input stack (an overlay frees the mouse). `send(bytes)` delivers a packet to the
## server reliably.
func _init(contexts: InputContextStack, send: Callable) -> void:
	_contexts = contexts
	_send = send
	name = "DevMenu"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.position = Vector2(40, 40)
	var back := StyleBoxFlat.new()
	back.bg_color = BACKING
	_panel.add_theme_stylebox_override(&"panel", back)
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	var title := Label.new()
	title.text = tr("Dev menu (F1)")
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	for row in COMMANDS:
		_button(grid, row[0], row[1])
	var scares := Label.new()
	scares.text = tr("Scares")
	box.add_child(scares)
	var sgrid := GridContainer.new()
	sgrid.columns = 3
	box.add_child(sgrid)
	var catalogue := ScareCatalogue.load_shipped()
	if catalogue != null:
		for e: ScareEntry in catalogue.entries:
			_button(sgrid, String(e.scare_id).capitalize(), "scare:%s" % e.scare_id)
	var close := Button.new()
	close.text = tr("Close")
	close.pressed.connect(toggle)
	box.add_child(close)
	_panel.visible = false


## Whether the panel shows.
func is_open() -> bool:
	return _open


## Opens or shuts the panel. Opens only from gameplay (not over the wheel, settings or a modal).
func toggle() -> void:
	if not _open and _contexts.top() != InputContextStack.Ctx.GAMEPLAY:
		return
	_open = not _open
	_panel.visible = _open
	if _open:
		_contexts.push(InputContextStack.Ctx.OVERLAY, buttons[COMMANDS[0][1]])
	elif _contexts.top() == InputContextStack.Ctx.OVERLAY:
		_contexts.pop(InputContextStack.Ctx.OVERLAY)


## Sends `command` to the server.
func send(command: String) -> void:
	sent.append(command)
	_send.call(DevCommands.packet(command))


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var toggle_key := key != null and key.pressed and not key.echo and key.physical_keycode == TOGGLE_KEY
	if toggle_key or (_open and event.is_action_pressed(&"ui_cancel")):
		if is_inside_tree():
			get_viewport().set_input_as_handled()
		toggle()


func _button(grid: GridContainer, label: String, command: String) -> void:
	var b := Button.new()
	b.text = tr(label)
	b.custom_minimum_size = Vector2(220, 0)
	b.pressed.connect(send.bind(command))
	grid.add_child(b)
	buttons[command] = b
