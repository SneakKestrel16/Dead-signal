class_name LobbyScreen extends Control
## The lobby screen (story lobby-role-assignment/005; lobby-role-assignment.md UI Requirements; ADR-0014
## §5, §9): a host/join form, then the player list (name, Ready, preferred character), the countdown,
## the Ready toggle and the host-only controls (proximity voice, kick); story 012 adds the rotation queue
## with the next shapeshifter (rule 11, AC-LB-19) and the preferred-character picker, disabled while Ready
## (rule 12). It displays server state only: every peer, the host included, renders the LobbySync packet
## the server last built, and a client's requests are Ready on or off and a preference (LobbySync), which
## cannot start a countdown by themselves.
## The host side owns the session pieces until a client composition root exists (ADR-0005): the
## NetAuthority child, the LobbyState, the ConnectionRouter, the RosterHandoff (whose RotationQueue the
## lobby shows) and the lobby tick clock.
## Deviations (story 005): no InputContextStack yet (ADR-0014 §1; the lobby is the MENU base, whose
## cursor is visible, the engine default). The next shapeshifter is marked in text, no colour: no
## art-direction spec yet.
## Round wiring (match-flow story 013, ADR-0001 §1): the screen is its session's multiplayer root. The host
## adds the server role beside its local player as a RoundHost node, which composes the round on the roster
## lock; the host's local player plays through a seat: a RoundClient under its own multiplayer root that
## joins the host's port over loopback with the host's token, admitted while a round runs (the server reads
## its input through the same queue as everyone's). A joined client keeps a RoundClient ready from the
## room on (its HiddenSpawner must exist before the round is composed) and plays the round over the lobby's
## own session (RoundClient.adopt; no second ENet session) once the lobby packet says In Match; when the
## lobby packet says Waiting again it drops the round scene and shows the room. During a round the screen
## shows only a greybox line from MatchDisplay (phase and time); on RoundEnded it shows the ResultsScreen
## (hud-results story 008) until the round is dropped, and its Leave session leaves the session. A host that leaves sends every client back to the boot scene
## with "Host left" (leave_to, Main.return_with; ADR-0001 §7).
## Last round (hud-results story 009; results.md Entry & Exit, AD-31): the room's Last round button reopens the
## last RoundEnded payload, kept for the session, in ResultsScreen.last_round (no countdown) under MENU on the
## lobby's own InputContextStack; Back closes it and focus returns to the button. The payload is dropped when
## the session closes (Leave, kick, host left), and a starting round closes an open view.
## Command-line flags after `--` drive it for evidence captures: --lobby-host, --lobby-join=ADDR,
## --lobby-port=N, --lobby-name=NAME, --lobby-ready; host only: --lobby-seed=N (the queue shuffle).
## --lobby-shots=DIR (story match-flow/013 evidence) saves lobby.png once the room lists min_players,
## round.png SHOT_AFTER_S after the own body spawned, results.png SHOT_AFTER_S into Results and back.png
## once the room shows again after the round, then quits. --lobby-settings opens the settings screen (with
## --lobby-shots and no host/join: settings.png, then quits).
## Settings (design/game-brief.md MVP; interaction-patterns.md P15): the form's and room's Settings button opens
## SettingsScreen under MENU on the lobby's stack; in a round Esc / Start opens it as a non-pausing OVERLAY on
## the round's stack (only from GAMEPLAY). Each change applies live: bus volumes here, the rest through
## RoundClient.apply_settings.
## Usage: add_child(LobbyScreen.new())

const _ROW_COLUMNS := 4
## --lobby-shots: seconds after a step begins before its screenshot (the view settles).
const SHOT_AFTER_S := 1.5

## Set before add_child to use other knobs than the shipped ones (tests); null = Knobs.load_all().
var knobs: Knobs
## Whether the round scene draws (camera, input, HUD). Tests run several screens headless with false.
var render_round := true
## Callable(tree: SceneTree, text: String) run when the host leaves (default Main.return_with).
var leave_to: Callable = Main.return_with
## The server role (host only; null on a client).
var round_host: RoundHost
## The player's settings; set before add_child (tests), null = PlayerSettings.new() (user://settings.cfg).
var settings: PlayerSettings
## The open settings screen (lobby or in-round), null when closed.
var settings_view: SettingsScreen
## The round scene of this player: a client's adopted RoundClient (from the room on), or the host's seat
## RoundClient while a round runs.
var round_client: RoundClient

var _knobs: Knobs
var _net: NetAuthority
var _version := ""
var _seat: Node ## host: the seat RoundClient's multiplayer root
var _display: MatchDisplay
var _in_round := false
var _round_line: Label
var _results: ResultsScreen ## the Results screen while the round is in Results
var _last_round: Dictionary = {} ## the last RoundEnded payload of this session (AD-31); {} = none yet
var _last_round_view: ResultsScreen ## the open Last round view
var _contexts := InputContextStack.new(InputContextStack.Ctx.MENU) ## the lobby's own; the round has the HUD's
var _rooted := false ## this screen's path carries its session's SceneMultiplayer
var _shots: Dictionary[String, float] = {} ## --lobby-shots: shot name -> seconds its condition has held
var _played := false ## --lobby-shots: a round was entered
var _lobby: LobbyState ## host only
var _router: ConnectionRouter ## host only
var _handoff: RosterHandoff ## host only
var _opts: Dictionary = {} ## command-line flags (_autorun)
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
var _pref: OptionButton
var _queue: Label
var _last_round_button: Button


func _ready() -> void:
	_knobs = knobs if knobs != null else Knobs.load_all()
	_contexts.viewport = get_viewport()
	if settings == null:
		settings = PlayerSettings.new()
	settings.apply_audio()
	settings.changed.connect(_on_setting_changed)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 0)
	center.add_child(box)
	_build_form(box)
	_build_room(box)
	_round_line = Label.new()
	_round_line.hide()
	box.add_child(_round_line)
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
	_button(buttons, "Settings", open_settings)
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
	_pref = _field(_room, "Character", OptionButton.new()) as OptionButton
	for cid in CharacterDef.IDS:
		_pref.add_item(String(cid))
	_pref.item_selected.connect(_on_pref_selected)
	_queue = Label.new()
	_room.add_child(_queue)
	var buttons := HBoxContainer.new()
	_room.add_child(buttons)
	_ready_button = _button(buttons, "Ready", _on_ready_toggled)
	_ready_button.toggle_mode = true
	_last_round_button = _button(buttons, "Last round", _on_last_round)
	_button(buttons, "Settings", open_settings)
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
	_last_round_button.visible = not _last_round.is_empty()


func _new_net() -> NetAuthority:
	get_tree().set_multiplayer(SceneMultiplayer.new(), get_path()) # the session root (RoundHost paths)
	_rooted = true
	_net = NetAuthority.new()
	_net.fail_hard = false
	_version = _knobs.join_version(str(ProjectSettings.get_setting("application/config/version", "0.0.0")))
	_net.setup(_knobs, _version, _lobby)
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
	var rng := RandomNumberGenerator.new()
	if _opts.has("lobby-seed"):
		rng.seed = int(_opts["lobby-seed"])
	else:
		rng.randomize()
	_handoff = RosterHandoff.new(_lobby, RosterHandoff.info_from(_net), _knobs, rng, str(rng.randi()))
	round_host = RoundHost.new(_knobs, _net, _router, _handoff, _lobby)
	add_child(round_host)
	round_host.round_started.connect(_on_round_started)
	round_host.round_over.connect(_on_round_over)
	_net.known_token_in_grace = _admit
	_elapsed_s = 0.0
	_last_sent = PackedByteArray()
	multiplayer.peer_packet.connect(_on_server_packet)
	_show_room()


func _on_join() -> void:
	_lobby = null
	_new_net()
	_net.join_rejected.connect(_on_rejected)
	_net.host_left.connect(_on_host_left)
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
	_drop_round()
	_close_last_round()
	_last_round = {}
	if round_host != null:
		round_host.queue_free()
	round_host = null
	if _net != null:
		_net.close()
		_net.queue_free()
	_net = null
	_lobby = null
	_router = null
	_handoff = null
	_state = {}
	_show_form(message)


# These three are raised from inside SceneMultiplayer's poll (auth callback, packet, disconnect): closing
# the peer there crashed the engine (4.7.2, observed 2026-10-15 on a rejected join), so close next idle.
func _on_rejected(reason: StringName) -> void:
	_close.call_deferred(reject_text(reason, _net.last_reject_details))


func _on_kicked(reason: StringName) -> void:
	_close.call_deferred(reject_text(reason, {}))


## ADR-0001 §7: back to the boot scene with "Host left"; no result is recorded.
func _on_host_left() -> void:
	_close.call_deferred("")
	leave_to.call_deferred(get_tree(), tr("Host left"))


## NetAuthority.known_token_in_grace on the host: a player in reconnect grace, or the host's own seat
## while a round runs (its token has no peer in the lobby, ADR-0001 §1).
func _admit(token: String) -> bool:
	return _router.in_grace(token) or (round_host.is_running() and token == _lobby.host_token)


# --- round wiring (match-flow story 013) --------------------------------------------

## Host: the round is composed; the local player's seat joins it over loopback.
func _on_round_started() -> void:
	# Beside the screen, not under it: a multiplayer root cannot sit under another (4.7.2 refuses it).
	_seat = Node.new()
	_seat.name = String(name) + "Seat"
	get_parent().add_child(_seat)
	round_client = _new_round_client(_seat)
	round_client.version = _version
	round_client.join("127.0.0.1", int(_port.value), _net.display_name_of(_net.local_player_id), _lobby.host_token,
			_seat)
	_enter_round()


## Host: the round is torn down. The seat lets go while the lobby is still In Match: the kick unbinds its
## peer at once (no drop is raised, so the host stays in the lobby), then the lobby returns to Waiting.
func _on_round_over(ended: bool) -> void:
	_net.kick(_net.local_player_id)
	_drop_round()
	round_host.finish(ended)
	_show_room()


## A RoundClient named RoundHost.NODE_NAME under `parent`, with its round map, not yet playing.
func _new_round_client(parent: Node) -> RoundClient:
	var map := MapData.load_map()
	var c := RoundClient.new(_knobs, RoundMoveStep.step_for(_knobs), RoundMoveStep.body_maker(_knobs), map, render_round)
	c.name = RoundHost.NODE_NAME
	parent.add_child(c)
	var floors := Node3D.new()
	floors.name = &"Map"
	c.add_child(floors)
	MapGreybox.build(floors, map)
	c.level = floors # BUG-0018: its doors follow the server's
	c.apply_settings(settings)
	return c


## Client: the round scene (and its HiddenSpawner) waits from the room on.
func _arm_client() -> void:
	if round_client == null:
		round_client = _new_round_client(self)
		round_client.prepare()


func _enter_round() -> void:
	_close_last_round()
	close_settings()
	_in_round = true
	_display = MatchDisplay.new(_knobs, round_client.multiplayer as SceneMultiplayer)
	_room.hide()
	_round_line.show()


## Frees the round scene (host seat or client) and the display. Safe outside a round.
func _drop_round() -> void:
	_in_round = false
	close_settings()
	if _display != null:
		_display.close()
	_display = null
	if round_client != null:
		round_client.close()
		round_client.name = &"Ended" # frees the name for the next round's RoundClient at once
		round_client.queue_free()
	round_client = null
	if _seat != null:
		# BUG-0015: the seat's multiplayer stays rooted until the seat has left the tree, so its synchronizers
		# stop replication on the API that tracks them (unrooted first, they reach the lobby's and log errors).
		_seat.tree_exited.connect(get_tree().set_multiplayer.bind(null, _seat.get_path()), CONNECT_ONE_SHOT)
		_seat.queue_free()
	_seat = null
	_round_line.hide()
	if _results != null:
		_results.queue_free() # pops its MENU on exit; it holds the round's InputContextStack
	_results = null


func _exit_tree() -> void:
	_drop_round()
	if _net != null:
		_net.close()
	if _rooted:
		get_tree().set_multiplayer(null, get_path())
		_rooted = false


func _process(delta: float) -> void:
	if _opts.has("lobby-shots"):
		_capture(delta)
	if _display == null:
		return
	_display.advance(delta)
	_round_line.text = round_line(_display)
	if _display.is_ended() and _results == null:
		_show_results()


## RoundEnded arrived: the Results screen over the frozen round (results.md Entry; story hud-results/008).
func _show_results() -> void:
	close_settings() # its overlay must not sit over Results (the stack was reset to MENU)
	var hud := round_client.ping_hud if round_client != null else null
	_last_round = _display.results()
	_results = ResultsScreen.new(_last_round, _knobs.match_flow.results_duration_s,
			hud.contexts if hud != null else null)
	_results.leave_confirmed.connect(_on_leave)
	add_child(_results)
	_round_line.hide()


## The Last round view of the stored payload (R9); it pushes MENU with Back focused.
func _on_last_round() -> void:
	if _last_round_view != null or _last_round.is_empty():
		return
	_last_round_view = ResultsScreen.last_round(_last_round, _contexts)
	_last_round_view.closed.connect(_close_last_round)
	add_child(_last_round_view)


## Opens the settings screen: in a round over the live view as OVERLAY on the round's stack (only from
## GAMEPLAY), else under MENU on the lobby's own stack. Does nothing when one is open.
func open_settings() -> void:
	if settings_view != null:
		return
	var hud := round_client.ping_hud if round_client != null and _in_round else null
	if _in_round and (hud == null or hud.contexts.top() != InputContextStack.Ctx.GAMEPLAY):
		return
	if hud != null:
		var layer := CanvasLayer.new()
		layer.layer = UiLayers.OVERLAY
		add_child(layer)
		settings_view = SettingsScreen.new(settings, hud.contexts, InputContextStack.Ctx.OVERLAY, true)
		layer.add_child(settings_view)
	else:
		settings_view = SettingsScreen.new(settings, _contexts, InputContextStack.Ctx.MENU, false)
		add_child(settings_view)
	settings_view.closed.connect(close_settings)


## Frees the settings screen (and its overlay layer); its exit saves and pops its context.
func close_settings() -> void:
	if settings_view == null:
		return
	var host := settings_view.get_parent()
	(host if host is CanvasLayer else settings_view).queue_free()
	settings_view = null


func _on_setting_changed(_key: StringName) -> void:
	settings.apply_audio()
	if round_client != null:
		round_client.apply_settings(settings)


## Esc / Start in a round opens the settings overlay (P15); the screen itself handles the close.
func _unhandled_input(event: InputEvent) -> void:
	if _in_round and settings_view == null and event.is_action_pressed(&"menu"):
		open_settings()
		if settings_view != null:
			get_viewport().set_input_as_handled()


## Frees the Last round view; its exit pops MENU, which restores focus to the Last round button.
func _close_last_round() -> void:
	if _last_round_view != null:
		_last_round_view.queue_free()
	_last_round_view = null


## --lobby-shots: each step's screenshot once its condition held SHOT_AFTER_S.
func _capture(delta: float) -> void:
	_played = _played or _in_round
	var in_room := _room.visible and not _state.is_empty()
	if _shot("settings", delta, _opts.has("lobby-settings") and settings_view != null and _net == null):
		get_tree().quit()
	_shot("lobby", delta, in_room and not _played and _state.players.size() >= _knobs.lobby.min_players)
	_shot("round", delta, _in_round and round_client != null and round_client.is_spawned())
	_shot("results", delta, _in_round and _display != null and _display.is_ended())
	if _shot("back", delta, in_room and _played):
		get_tree().quit()


func _shot(tag: String, delta: float, holds: bool) -> bool:
	if not holds or _shots.get(tag, 0.0) < 0.0:
		return false
	_shots[tag] = _shots.get(tag, 0.0) + delta
	if _shots[tag] < SHOT_AFTER_S:
		return false
	_shots[tag] = -1.0
	var path := "%s/%s.png" % [_opts["lobby-shots"], tag]
	print("SHOT %s %s" % [path, error_string(get_viewport().get_texture().get_image().save_png(path))])
	return true


## The greybox round line: the phase clock (hidden once the Results screen shows).
static func round_line(d: MatchDisplay) -> String:
	if d.phase() == -1:
		return TranslationServer.translate("Loading the round...")
	return TranslationServer.translate("Round: %d s left") % ceili(d.time_remaining_s())


## The lobby clock in server ticks (ConnectionRouter's clock too).
func _tick() -> int:
	return int(_elapsed_s * _knobs.net.sim_tick_hz)


func _physics_process(delta: float) -> void:
	if _lobby == null:
		return
	_elapsed_s += delta
	var tick := _tick()
	_lobby.server_tick(tick)
	var bytes := LobbySync.encode(_lobby, tick, _net.player_id_of_token, _net.display_name_of,
			_handoff.queue_order())
	if bytes != _last_sent:
		_last_sent = bytes
		multiplayer.send_bytes(bytes, 0, MultiplayerPeer.TRANSFER_MODE_RELIABLE, NetChannels.EVENT)
		_render(LobbySync.decode(bytes))


func _on_server_packet(peer_id: int, bytes: PackedByteArray) -> void:
	LobbySync.apply_request(_lobby, _net.token_of(_net.player_id_of(peer_id)), bytes)


func _on_client_packet(peer_id: int, bytes: PackedByteArray) -> void:
	if peer_id != 1:
		return
	var s := LobbySync.decode(bytes)
	if s.is_empty():
		return
	if s.state == "in_match" and not _in_round and round_client != null:
		round_client.adopt(_net)
		_enter_round()
	elif s.state != "in_match" and _in_round:
		_drop_round()
	if not _in_round and _room.visible == false:
		_show_room()
	_arm_client()
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
	var my_row := _row(s, me)
	_pref.set_block_signals(true)
	_pref.select(CharacterDef.IDS.find(StringName(my_row.get("pref", ""))))
	_pref.set_block_signals(false)
	_pref.disabled = my_row.get("ready", false) or s.state != "waiting"
	_queue.text = queue_text(s, me)


## The rotation queue as the lobby shows it (rule 11, AC-LB-19): head first, absent players marked, the
## server's next shapeshifter named; before the first round, that the order is not drawn yet.
static func queue_text(s: Dictionary, me: int) -> String:
	if s.queue.is_empty():
		return TranslationServer.translate("Shapeshifter queue: drawn when the first round starts")
	var lines := PackedStringArray([TranslationServer.translate("Shapeshifter queue:")])
	var present := {}
	for row: Dictionary in s.players:
		present[row.id] = true
	for i in s.queue.size():
		var q: Dictionary = s.queue[i]
		var line := "%d. %s" % [i + 1, q.name]
		if q.id == me:
			line += " " + TranslationServer.translate("(you)")
		if not present.has(q.id):
			line += " " + TranslationServer.translate("(away)")
		if q.id == s.next:
			line += "  <- " + TranslationServer.translate("next shapeshifter")
		lines.append(line)
	return "\n".join(lines)


func _cell(text: String) -> void:
	var l := Label.new()
	l.text = text
	_list.add_child(l)


static func _row_ready(s: Dictionary, id: int) -> bool:
	return _row(s, id).get("ready", false)


static func _row(s: Dictionary, id: int) -> Dictionary:
	for row: Dictionary in s.players:
		if row.id == id:
			return row
	return {}


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


## A preference is a request too: the picker shows the server's answer once the next lobby packet arrives.
func _on_pref_selected(index: int) -> void:
	var cid: StringName = CharacterDef.IDS[index]
	if not _state.is_empty():
		_pref.set_block_signals(true)
		_pref.select(CharacterDef.IDS.find(StringName(_row(_state, _net.local_player_id).get("pref", ""))))
		_pref.set_block_signals(false)
	if _lobby != null:
		_lobby.set_preference(_net.local_token, cid)
	else:
		multiplayer.send_bytes(LobbySync.preference_packet(cid), 1, MultiplayerPeer.TRANSFER_MODE_RELIABLE,
				NetChannels.EVENT)


func _on_voice_toggled(on: bool) -> void:
	if _lobby != null:
		_lobby.set_proximity_voice(_lobby.host_token, on)


func _on_kick(player_id: int) -> void:
	if _lobby != null:
		_lobby.kick(_lobby.host_token, _net.token_of(player_id))


func _autorun(args: PackedStringArray) -> void:
	var opts := _opts
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
	if opts.has("lobby-settings"):
		open_settings.call_deferred()


func _auto_ready() -> void:
	# Joining clients get their first lobby packet a few frames later; retry until in the room.
	while _net != null and not _room.visible:
		await get_tree().process_frame
	if _net != null:
		_ready_button.button_pressed = true
		_on_ready_toggled()
