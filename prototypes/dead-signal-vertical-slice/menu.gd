# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: does one networked greybox round deliver "you can't be sure the person next to you is a person"?
# Date: 2026-10-13
extends Control
## Main menu and lobby: name, host or join by address, roster, Start (host).

var _name: LineEdit
var _addr: LineEdit
var _status: Label
var _roster: Label
var _start: Button
var _join_box: Control
var _lobby_box: Control


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.04)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.custom_minimum_size = Vector2(460, 0)
	col.position = Vector2(-230, -230)
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	col.add_child(_label("DEAD SIGNAL", 40, Color(0.85, 0.2, 0.2)))
	col.add_child(_label("vertical slice — greybox", 14, Color(0.6, 0.6, 0.6)))

	_join_box = VBoxContainer.new()
	col.add_child(_join_box)
	_join_box.add_child(_label("Your name", 14))
	_name = LineEdit.new()
	_name.max_length = 16
	_name.text = Net.args.get("name", OS.get_environment("USERNAME").left(16))
	_join_box.add_child(_name)
	var host := Button.new()
	host.text = "Host a session"
	host.pressed.connect(func() -> void: Net.host(_name.text))
	_join_box.add_child(host)
	_join_box.add_child(_label("Host address (Tailscale or LAN IP)", 14))
	_addr = LineEdit.new()
	_addr.placeholder_text = "100.x.y.z"
	_addr.text = Net.args.get("join", "")
	_join_box.add_child(_addr)
	var join := Button.new()
	join.text = "Join"
	join.pressed.connect(func() -> void: Net.join(_addr.text.strip_edges(), _name.text))
	_join_box.add_child(join)

	_lobby_box = VBoxContainer.new()
	col.add_child(_lobby_box)
	_lobby_box.add_child(_label("Lobby", 20))
	_roster = _label("", 16)
	_lobby_box.add_child(_roster)
	_start = Button.new()
	_start.text = "Start round"
	_start.pressed.connect(Net.start_round)
	_lobby_box.add_child(_start)
	var leave := Button.new()
	leave.text = "Leave"
	leave.pressed.connect(Net.leave)
	_lobby_box.add_child(leave)

	_status = _label("", 14, Color(0.9, 0.75, 0.3))
	col.add_child(_status)
	col.add_child(_label("WASD move · Shift sprint · Ctrl crouch · E interact (hold) · F flashlight · LMB taser / lunge\nShapeshifter: 1-5 borrow an observed face · Q true form · Tab roster · Esc release mouse", 12, Color(0.55, 0.55, 0.55)))

	if not Net.last_results.is_empty():
		col.add_child(_label("Last round: " + String(Net.last_results.get("headline", "")), 14, Color(0.7, 0.8, 0.9)))

	Net.roster_changed.connect(_refresh)
	Net.status.connect(func(t: String) -> void: _status.text = t)
	_refresh()
	if not Net.online():
		if Net.args.has("host"):
			Net.host(_name.text)
		elif Net.args.has("join"):
			Net.join(Net.args["join"], _name.text)


func _process(_dt: float) -> void:
	var auto := int(Net.args.get("autostart", "0"))
	if auto > 0 and Net.is_host() and Net.players.size() >= auto and not Net.in_round:
		Net.args.erase("autostart")
		Net.start_round()


func _refresh() -> void:
	var connected := Net.online() and not Net.players.is_empty()
	_join_box.visible = not connected
	_lobby_box.visible = connected
	_start.visible = Net.is_host()
	var lines: PackedStringArray = []
	var ids: Array = Net.players.keys()
	ids.sort()
	for id in ids:
		lines.append(("★ " if id == 1 else "• ") + String(Net.players[id].name))
	lines.append("%d / %d players (min %d)" % [Net.players.size(), Knobs.i("max_players"), Knobs.i("min_players")])
	_roster.text = "\n".join(lines)


func _label(t: String, size: int, c: Color = Color(0.9, 0.9, 0.9)) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
