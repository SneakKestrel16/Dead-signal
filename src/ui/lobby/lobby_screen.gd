class_name LobbyScreen extends Control
## The lobby screen (story lobby-role-assignment/005; lobby-role-assignment.md UI Requirements; ADR-0014
## §5, §9): a host/join form, then the player list (name, Ready, preferred character), the countdown,
## the Ready toggle and the host-only controls (proximity voice, kick). It displays server state only:
## every peer, the host included, renders the LobbySync packet the server last built, and a client's one
## request is Ready on or off (LobbySync), which cannot start a countdown by itself.
## The host side owns the session pieces until a client composition root exists (ADR-0005): the
## NetAuthority child, the LobbyState, the ConnectionRouter and the lobby tick clock.
## Deviations (story 005): no InputContextStack yet (ADR-0014 §1; the lobby is the MENU base, whose
## cursor is visible, the engine default); no character picker (rule 12 has no request path yet); the
## round start after the countdown is not wired, the screen shows "Starting".
## Command-line flags after `--` drive it for evidence captures: --lobby-host, --lobby-join=ADDR,
## --lobby-port=N, --lobby-name=NAME, --lobby-ready.
## Usage: add_child(LobbyScreen.new())

const _ROW_COLUMNS := 4

var _knobs: Knobs
var _net: NetAuthority
var _lobby: LobbyState ## host only
var _router: ConnectionRouter ## host only
var _elapsed_s := 0.0 ## host: seconds the lobby clock has run
var _last_sent := PackedByteArray()
var _state: Dictionary = {} ## the lobby packet last received (decoded)

var _form: VBoxContainer
var _name: LineEdit
var _address: LineEdit
var _port: SpinBox
var _status: Label
var _room: VBoxContainer
var _title: Label
var _list: GridContainer
var _countdown: Label
var _voice: CheckButton
var _ready_button: Button


func _ready() -> void:
	_knobs = Knobs.load_all()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 0)
	center.add_child(box)
	_build_form(box)
	_build_room(box)
	_show_form("")
	_autorun(OS.get_cmdline_user_args())


## The join screen text for a refused join (lobby rules 2, 3; AC-LB-03 wording). `details` is
## NetAuthority.last_reject_details: a version mismatch shows both version strings.
static func reject_text(reason: StringName, details: Dictionary) -> String:
	match reason:
		NetAuthority.REASON_LOBBY_FULL:
			return TranslationServer.translate("Lobby full")
		NetAuthority.REASON_ROUND_IN_PROGRESS:
			return TranslationServer.translate("Round in progress, try again shortly")
		NetAuthority.REASON_VERSION_MISMATCH:
			return TranslationServer.translate("Version mismatch: host %s, you %s") \
					% [details.get("server_version", "?"), details.get("client_version", "?")]
		NetAuthority.REASON_BAD_NAME:
			return TranslationServer.translate("That name is empty or too long")
		NetAuthority.REASON_TOKEN_IN_USE:
			return TranslationServer.translate("Already joining from another window")
		NetAuthority.REASON_KICKED:
			return TranslationServer.translate("Removed by the host")
	return TranslationServer.translate("Could not join")


func _build_form(box: VBoxContainer) -> void:
	_form = VBoxContainer.new()
	box.add_child(_form)
	_name = _field(_form, "Name", LineEdit.new()) as LineEdit
	_address = _field(_form, "Host address", LineEdit.new()) as LineEdit
	_address.text = "127.0.0.1"
	_port = _field(_form, "Port", SpinBox.new()) as SpinBox
	_port.min_value = 1
	_port.max_value = 65535
	_port.value = _knobs.net.port
	var buttons := HBoxContainer.new()
	_form.add_child(buttons)
	_button(buttons, "Host", _on_host)
	_button(buttons, "Join", _on_join)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_form.add_child(_status)


func _build_room(box: VBoxContainer) -> void:
	_room = VBoxContainer.new()
	box.add_child(_room)
	_title = Label.new()
	_room.add_child(_title)
	_list = GridContainer.new()
	_list.columns = _ROW_COLUMNS
	_list.add_theme_constant_override("h_separation", 24)
	_room.add_child(_list)
	_countdown = Label.new()
	_room.add_child(_countdown)
	_voice = CheckButton.new()
	_voice.text = tr("Proximity voice")
	_voice.toggled.connect(_on_voice_toggled)
	_room.add_child(_voice)
	var buttons := HBoxContainer.new()
	_room.add_child(buttons)
	_ready_button = _button(buttons, "Ready", _on_ready_toggled)
	_ready_button.toggle_mode = true
	_button(buttons, "Leave", _on_leave)


## A labelled input; the label text is also its screen-reader name (ADR-0014 §9).
func _field(parent: Container, label: String, input: Control) -> Control:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := Label.new()
	l.text = tr(label)
	l.custom_minimum_size = Vector2(140, 0)
	row.add_child(l)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.accessibility_name = tr(label)
	row.add_child(input)
	return input


func _button(parent: Container, label: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = tr(label)
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


func _show_form(message: String) -> void:
	_room.hide()
	_form.show()
	_status.text = message
	_name.grab_focus.call_deferred()


func _show_room() -> void:
	_form.hide()
	_room.show()
	_ready_button.button_pressed = false
	_ready_button.grab_focus.call_deferred()


func _new_net() -> NetAuthority:
	_net = NetAuthority.new()
	_net.fail_hard = false
	_net.setup(_knobs, _knobs.join_version(str(ProjectSettings.get_setting("application/config/version", "0.0.0"))),
			_lobby)
	add_child(_net)
	return _net


func _on_host() -> void:
	_lobby = LobbyState.new(_knobs)
	_new_net()
	if _net.add_host_player(_name.text) == -1:
		_close(reject_text(NetAuthority.REASON_BAD_NAME, {}))
		return
	var err := _net.host(int(_port.value))
	if err != OK:
		_close(tr("Could not host on port %d (%s)") % [int(_port.value), error_string(err)])
		return
	_router = ConnectionRouter.new(_knobs, _net, _lobby, _tick)
	_lobby.host_token = _net.local_token
	_lobby.join(_net.local_token)
	_elapsed_s = 0.0
	_last_sent = PackedByteArray()
	multiplayer.peer_packet.connect(_on_server_packet)
	_show_room()


func _on_join() -> void:
	_lobby = null
	_new_net()
	_net.join_rejected.connect(_on_rejected)
	_net.host_left.connect(_on_lost.bind(tr("Host left")))
	_net.kicked.connect(_on_kicked)
	if _net.join(_address.text, int(_port.value), _name.text) != OK:
		_close(tr("Could not join"))
		return
	multiplayer.peer_packet.connect(_on_client_packet)
	_status.text = tr("Joining...")


func _on_leave() -> void:
	_close("")


func _close(message: String) -> void:
	for c in [_on_server_packet, _on_client_packet]:
		if multiplayer.peer_packet.is_connected(c):
			multiplayer.peer_packet.disconnect(c)
	if _net != null:
		_net.close()
		_net.queue_free()
	_net = null
	_lobby = null
	_router = null
	_state = {}
	_show_form(message)


# These three are raised from inside SceneMultiplayer's poll (auth callback, packet, disconnect): closing
# the peer there crashed the engine (4.7.2, observed 2026-10-15 on a rejected join), so close next idle.
func _on_rejected(reason: StringName) -> void:
	_close.call_deferred(reject_text(reason, _net.last_reject_details))


func _on_kicked(reason: StringName) -> void:
	_close.call_deferred(reject_text(reason, {}))


func _on_lost(message: String) -> void:
	_close.call_deferred(message)


## The lobby clock in server ticks (ConnectionRouter's clock too).
func _tick() -> int:
	return int(_elapsed_s * _knobs.net.sim_tick_hz)


func _physics_process(delta: float) -> void:
	if _lobby == null:
		return
	_elapsed_s += delta
	var tick := _tick()
	_lobby.server_tick(tick)
	var bytes := LobbySync.encode(_lobby, tick, _net.player_id_of_token, _net.display_name_of)
	if bytes != _last_sent:
		_last_sent = bytes
		multiplayer.send_bytes(bytes, 0, MultiplayerPeer.TRANSFER_MODE_RELIABLE, NetChannels.EVENT)
		_render(LobbySync.decode(bytes))


func _on_server_packet(peer_id: int, bytes: PackedByteArray) -> void:
	LobbySync.apply_ready(_lobby, _net.token_of(_net.player_id_of(peer_id)), bytes)


func _on_client_packet(peer_id: int, bytes: PackedByteArray) -> void:
	if peer_id != 1:
		return
	var s := LobbySync.decode(bytes)
	if s.is_empty():
		return
	if _room.visible == false:
		_show_room()
	_render(s)


func _render(s: Dictionary) -> void:
	_state = s
	var me := _net.local_player_id
	var am_host: bool = s.host == me
	_title.text = tr("Lobby (%d)") % s.players.size()
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	for header in ["Player", "Ready", "Character", ""]:
		_cell(tr(header) if header != "" else "")
	for row: Dictionary in s.players:
		var name_text: String = row.name
		if row.id == s.host:
			name_text += " " + tr("(host)")
		if row.id == me:
			name_text += " " + tr("(you)")
		_cell(name_text)
		_cell(tr("Ready") if row.ready else tr("Not ready"))
		_cell(row.pref)
		if am_host and row.id != me and s.state == "waiting":
			var kick := _button(_list, "Kick", _on_kick.bind(int(row.id)))
			kick.accessibility_name = tr("Kick %s") % row.name
		else:
			_cell("")
	match s.state:
		"countdown":
			_countdown.text = tr("Starting in %d") % s.countdown_s
		"in_match":
			_countdown.text = tr("Starting")
		_:
			_countdown.text = tr("Waiting for %d players, all Ready") % _knobs.lobby.min_players
	_voice.set_block_signals(true)
	_voice.button_pressed = s.voice
	_voice.set_block_signals(false)
	_voice.disabled = not (am_host and s.state == "waiting")
	_ready_button.set_block_signals(true)
	_ready_button.button_pressed = _row_ready(s, me)
	_ready_button.set_block_signals(false)
	_ready_button.text = tr("Ready") if not _ready_button.button_pressed else tr("Not ready")


func _cell(text: String) -> void:
	var l := Label.new()
	l.text = text
	_list.add_child(l)


static func _row_ready(s: Dictionary, id: int) -> bool:
	for row: Dictionary in s.players:
		if row.id == id:
			return row.ready
	return false


## Ready is a request: the toggle shows the server's answer once the next lobby packet arrives.
func _on_ready_toggled() -> void:
	var want := _ready_button.button_pressed
	_ready_button.set_block_signals(true)
	_ready_button.button_pressed = _row_ready(_state, _net.local_player_id) if not _state.is_empty() else false
	_ready_button.set_block_signals(false)
	if _lobby != null:
		_lobby.set_ready(_net.local_token, want)
	else:
		multiplayer.send_bytes(LobbySync.ready_packet(want), 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE,
				NetChannels.EVENT)


func _on_voice_toggled(on: bool) -> void:
	if _lobby != null:
		_lobby.set_proximity_voice(_lobby.host_token, on)


func _on_kick(player_id: int) -> void:
	if _lobby != null:
		_lobby.kick(_lobby.host_token, _net.token_of(player_id))


func _autorun(args: PackedStringArray) -> void:
	var opts := {}
	for a in args:
		var kv := a.trim_prefix("--").split("=", true, 1)
		opts[kv[0]] = kv[1] if kv.size() > 1 else ""
	if opts.has("lobby-name"):
		_name.text = opts["lobby-name"]
	if opts.has("lobby-port"):
		_port.value = int(opts["lobby-port"])
	if opts.has("lobby-join"):
		_address.text = opts["lobby-join"]
		_on_join()
	elif opts.has("lobby-host"):
		_on_host()
	if opts.has("lobby-ready"):
		_auto_ready.call_deferred()


func _auto_ready() -> void:
	# Joining clients get their first lobby packet a few frames later; retry until in the room.
	while _net != null and not _room.visible:
		await get_tree().process_frame
	if _net != null:
		_ready_button.button_pressed = true
		_on_ready_toggled()
