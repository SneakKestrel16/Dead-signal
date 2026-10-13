# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: does one networked greybox round deliver "you can't be sure the person next to you is a person"?
# Date: 2026-10-13
extends Node
## Session layer: host or join over ENet (Tailscale or LAN address), lobby roster,
## role and character assignment, switch into the round. Roles are public
## (lobby-role-assignment.md TR-lobby-010); bodies carry no names.
##
## Command line (after `--`): --host | --join=<addr> --name=<n> --autostart=<players>
## --monster=<peer id> --bot=<mode> --scenario=<name> (tests).

signal roster_changed
signal status(text: String)

const PORT := 24690


## --port overrides the default so tests can run beside a live session.
func port() -> int:
	return int(args.get("port", str(PORT)))
const VERSION := "slice-1"
## Survivor characters C1-C5: colour and silhouette are the whole identity a disguise copies.
const CHARACTERS := [
	{"name": "C1 Rook", "color": Color(0.85, 0.22, 0.2), "hat": "box"},
	{"name": "C2 Vale", "color": Color(0.2, 0.45, 0.9), "hat": "cone"},
	{"name": "C3 Moss", "color": Color(0.25, 0.75, 0.3), "hat": "ball"},
	{"name": "C4 Quill", "color": Color(0.92, 0.8, 0.2), "hat": "pack"},
	{"name": "C5 Wren", "color": Color(0.65, 0.3, 0.85), "hat": "tall"},
]

## peer_id -> {name, role ("survivor"/"monster"/""), character (0-4, -1 for the monster)}
var players: Dictionary = {}
var my_name := ""
var round_seed := 0
var in_round := false
var args: Dictionary = {}
var last_results: Dictionary = {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_setup_input()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void: status.emit("Could not connect"); _reset())
	multiplayer.server_disconnected.connect(_on_server_gone)


## Starts a listen server; the host is player 1. Returns an Error code.
func host(display_name: String) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port(), Knobs.i("max_players"))
	if err != OK:
		status.emit("Could not host on port %d (error %d)" % [port(), err])
		return err
	multiplayer.multiplayer_peer = peer
	my_name = _clean_name(display_name)
	players = {1: {"name": my_name, "role": "", "character": -1}}
	status.emit("Hosting on port %d" % port())
	roster_changed.emit()
	return OK


## Connects to a host at `address`. Returns an Error code.
func join(address: String, display_name: String) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port())
	if err != OK:
		status.emit("Bad address (error %d)" % err)
		return err
	multiplayer.multiplayer_peer = peer
	my_name = _clean_name(display_name)
	status.emit("Connecting to %s..." % address)
	return OK


func leave() -> void:
	_reset()
	get_tree().change_scene_to_file("res://menu.tscn")


## True once host() or join() set a real peer (the default offline peer does not count).
func online() -> bool:
	return multiplayer.multiplayer_peer is ENetMultiplayerPeer


func is_host() -> bool:
	return online() and multiplayer.is_server()


func me() -> int:
	return multiplayer.get_unique_id()


## Host only: assigns roles and characters, then moves everyone into the round.
func start_round() -> void:
	if not is_host() or in_round:
		return
	if players.size() < Knobs.i("min_players"):
		status.emit("Need at least %d players" % Knobs.i("min_players"))
		return
	var ids: Array = players.keys()
	ids.sort()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var monster: int = int(args.get("monster", "0"))
	for id in ids:
		if args.has("monster_name") and String(players[id].name) == args["monster_name"]:
			monster = id
	if not players.has(monster):
		monster = ids[rng.randi() % ids.size()]
	var chars := [0, 1, 2, 3, 4]
	for k in range(chars.size() - 1, 0, -1):
		var j := rng.randi() % (k + 1)
		var t: int = chars[k]
		chars[k] = chars[j]
		chars[j] = t
	var n := 0
	for id in ids:
		if id == monster:
			players[id].role = "monster"
			players[id].character = -1
		else:
			players[id].role = "survivor"
			players[id].character = chars[n]
			n += 1
	_begin.rpc(players, rng.randi())


@rpc("authority", "call_local", "reliable")
func _begin(p: Dictionary, seed_value: int) -> void:
	players = p
	round_seed = seed_value
	in_round = true
	get_tree().change_scene_to_file("res://game.tscn")


## Host only: back to the lobby after the results screen.
func return_to_lobby() -> void:
	if is_host():
		_to_lobby.rpc()


@rpc("authority", "call_local", "reliable")
func _to_lobby() -> void:
	in_round = false
	for id in players:
		players[id].role = ""
		players[id].character = -1
	get_tree().change_scene_to_file("res://menu.tscn")


func _on_connected() -> void:
	_register.rpc_id(1, my_name, VERSION)


@rpc("any_peer", "reliable")
func _register(display_name: String, version: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	var reason := ""
	if version != VERSION:
		reason = "Version mismatch (host %s, you %s)" % [VERSION, version]
	elif in_round:
		reason = "Round in progress"
	elif players.size() >= Knobs.i("max_players"):
		reason = "Lobby full"
	if reason != "":
		_rejected.rpc_id(id, reason)
		get_tree().create_timer(0.2).timeout.connect(func() -> void:
			if online():
				(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id))
		return
	var base := _clean_name(display_name)
	var nm := base
	var k := 2
	while players.values().any(func(p: Dictionary) -> bool: return String(p.name).to_lower() == nm.to_lower()):
		nm = "%s (%d)" % [base, k]
		k += 1
	players[id] = {"name": nm, "role": "", "character": -1}
	_sync_roster.rpc(players)
	roster_changed.emit()


@rpc("authority", "reliable")
func _rejected(reason: String) -> void:
	status.emit("Rejected: " + reason)


@rpc("authority", "reliable")
func _sync_roster(p: Dictionary) -> void:
	players = p
	status.emit("Joined. Waiting for the host to start.")
	roster_changed.emit()


func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	if not in_round:
		players.erase(id)
		_sync_roster.rpc(players)
		roster_changed.emit()


func _on_server_gone() -> void:
	if args.has("bot"):
		get_tree().quit()
		return
	_reset()
	status.emit("Host left the session")
	get_tree().change_scene_to_file("res://menu.tscn")


func _reset() -> void:
	if online():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players = {}
	in_round = false
	roster_changed.emit()


func _clean_name(n: String) -> String:
	var s := n.strip_edges().left(16)
	return s if s != "" else "Player"


func _setup_input() -> void:
	var keys := {
		"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
		"sprint": KEY_SHIFT, "crouch": KEY_CTRL, "interact": KEY_E, "flashlight": KEY_F,
		"true_form": KEY_Q, "face_1": KEY_1, "face_2": KEY_2, "face_3": KEY_3, "face_4": KEY_4,
		"face_5": KEY_5, "release_mouse": KEY_ESCAPE, "roster": KEY_TAB,
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[action]
		InputMap.action_add_event(action, ev)
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", mb)
