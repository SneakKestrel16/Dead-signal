class_name NetAuthority extends Node
## Host, join and join validation over ENet direct IP (ADR-0001). The server role is separable:
## host() starts and runs with no local player; the host's own player is added by the caller.
## Created and injected by the composition root; never an autoload.
## Everything outside this class is keyed by player_id; peer IDs never leave it.
## Wire: client sends var_to_bytes({version, display_name, token}) with send_auth(1, ..); the
## server replies {ok: true, player_id, token} or {ok: false, reason[, server_version, client_version]}.
## One round trip per join. A rejected peer is disconnected after reject_close_delay_s (a reason
## sent immediately before disconnect_peer is lost, ADR-0001 verification 6).
## Usage:
##   var net := NetAuthority.new(); net.setup(knobs, "1.0+ab12cd34", lobby)
##   add_child(net); net.host(knobs.net.port)          # or net.join("1.2.3.4", port, "Ann")

## Server: a player passed auth and its peer connected. Client-side nothing is emitted.
signal player_joined(player_id: int)
## Client: the server refused the join. Reason is one of REASON_*; details in last_reject_details.
signal join_rejected(reason: StringName)
## Server: create_server failed (e.g. port in use). Nothing was left initialised.
signal host_failed(error: Error)

const REASON_LOBBY_FULL := &"lobby_full"
const REASON_ROUND_IN_PROGRESS := &"round_in_progress"
const REASON_VERSION_MISMATCH := &"version_mismatch"
const REASON_BAD_NAME := &"bad_name"
const REASON_BAD_PAYLOAD := &"bad_payload"

const NAME_MIN := 1
const NAME_MAX := 16

## Server seam for story 002: Callable(token: String) -> bool, true when the token belongs to a
## player inside its reconnect grace. Unset means false. Story 002 must also rebind the old
## player_id (today a true result only passes the lobby-state check and a NEW id is issued).
var known_token_in_grace: Callable
## Client: extra fields of the last rejection (version_mismatch carries server_version, client_version).
var last_reject_details: Dictionary = {}
## Client: the player_id and token the server issued. The token is a secret: never log or send it on.
var local_player_id: int = -1
var local_token: String = ""

var _knobs: Knobs
var _version: String
## Provider object with state() -> StringName (&"waiting"/&"countdown"/&"in_match") and player_count() -> int.
var _lobby: Object
var _smp: SceneMultiplayer
var _display_name: String = ""
var _player_by_peer: Dictionary = {}
var _peer_by_player: Dictionary = {}
## Authenticated but not yet connected: peer_id -> {player_id, token}. Counts toward the cap.
var _pending: Dictionary = {}
## token -> player_id. Story 002 reads this.
var _tokens: Dictionary = {}
var _next_player_id: int = 0


## Injects dependencies. `version` is the full build string compared exactly; `lobby` is the state provider.
func setup(knobs: Knobs, version: String, lobby: Object) -> void:
	_knobs = knobs
	_version = version
	_lobby = lobby


## Starts the listen server on `port`. On failure emits host_failed and changes nothing.
func host(port: int) -> Error:
	if _smp != null:
		return ERR_ALREADY_IN_USE
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, _knobs.lobby.max_players + _knobs.net.max_clients_headroom)
	if err != OK:
		host_failed.emit(err)
		return err
	_attach(peer, _server_auth)
	_smp.peer_connected.connect(_on_peer_connected)
	_smp.peer_disconnected.connect(_on_peer_disconnected)
	_smp.peer_authentication_failed.connect(_on_auth_failed)
	return OK


## Connects to a host. The outcome arrives as join_rejected, or the usual SceneMultiplayer
## connected_to_server. Returns the create_client error.
func join(address: String, port: int, display_name: String) -> Error:
	if _smp != null:
		return ERR_ALREADY_IN_USE
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	_display_name = display_name
	_attach(peer, _client_auth)
	_smp.peer_authenticating.connect(_on_authenticating)
	return OK


## Closes the connection or server and returns to the unstarted state. Safe to call twice.
func close() -> void:
	if _smp != null:
		if _smp.multiplayer_peer != null:
			_smp.multiplayer_peer.close()
		_smp.auth_callback = Callable()
		_smp.multiplayer_peer = null
		for sig in [&"peer_connected", &"peer_disconnected", &"peer_authentication_failed", &"peer_authenticating"]:
			for c in _smp.get_signal_connection_list(sig):
				if c.callable.get_object() == self:
					_smp.disconnect(sig, c.callable)
	_smp = null
	_player_by_peer.clear()
	_peer_by_player.clear()
	_pending.clear()
	_tokens.clear()


## The player bound to `peer_id`, or -1 when unbound.
func player_id_of(peer_id: int) -> int:
	return _player_by_peer.get(peer_id, -1)


## The connected peer of `player_id`, or -1 when disconnected.
func peer_id_of(player_id: int) -> int:
	return _peer_by_player.get(player_id, -1)


func _exit_tree() -> void:
	close()


## Callbacks and relay/timeout go on BEFORE the peer is assigned (ADR-0001).
func _attach(peer: ENetMultiplayerPeer, auth: Callable) -> void:
	_smp = multiplayer as SceneMultiplayer
	_smp.server_relay = false
	_smp.auth_timeout = _knobs.net.auth_timeout_s
	_smp.auth_callback = auth
	_smp.multiplayer_peer = peer


func _on_authenticating(id: int) -> void:
	if id != 1:
		return
	var payload := {"version": _version, "display_name": _display_name, "token": ""}
	_smp.send_auth(1, var_to_bytes(payload))


# --- client ------------------------------------------------------------------

func _client_auth(_id: int, data: PackedByteArray) -> void:
	var reply: Variant = null
	if data.size() <= _knobs.net.auth_payload_cap_bytes:
		reply = bytes_to_var(data)
	if not (reply is Dictionary and reply.get("ok") is bool):
		_reject_client(REASON_BAD_PAYLOAD, {})
	elif reply.ok:
		if not (reply.get("player_id") is int and reply.get("token") is String):
			_reject_client(REASON_BAD_PAYLOAD, {})
			return
		local_player_id = reply.player_id
		local_token = reply.token
		_smp.complete_auth(1)
	elif reply.get("reason") is String:
		_reject_client(StringName(reply.reason), reply)
	else:
		_reject_client(REASON_BAD_PAYLOAD, {})


func _reject_client(reason: StringName, details: Dictionary) -> void:
	last_reject_details = details
	join_rejected.emit(reason)


# --- server ------------------------------------------------------------------

func _server_auth(id: int, data: PackedByteArray) -> void:
	var verdict := _validate(data)
	if verdict.ok:
		var player_id := _next_player_id
		_next_player_id += 1
		var token := Crypto.new().generate_random_bytes(16).hex_encode()
		_pending[id] = {"player_id": player_id, "token": token}
		_tokens[token] = player_id
		_smp.send_auth(id, var_to_bytes({"ok": true, "player_id": player_id, "token": token}))
		_smp.complete_auth(id)
		return
	_smp.send_auth(id, var_to_bytes(verdict))
	await get_tree().create_timer(_knobs.net.reject_close_delay_s).timeout
	if _smp != null and id in _smp.get_authenticating_peers():
		_smp.disconnect_peer(id)


## Runs the checks in the ADR order. Returns {ok: true} or the reject reply.
func _validate(data: PackedByteArray) -> Dictionary:
	if data.size() > _knobs.net.auth_payload_cap_bytes:
		return _reject(REASON_BAD_PAYLOAD)
	var d: Variant = bytes_to_var(data)
	if not (d is Dictionary and d.size() == 3 and d.get("version") is String \
			and d.get("display_name") is String and d.get("token") is String):
		return _reject(REASON_BAD_PAYLOAD)
	if d.version != _version:
		var r := _reject(REASON_VERSION_MISMATCH)
		r["server_version"] = _version
		r["client_version"] = d.version
		return r
	var n := sanitize_name(d.display_name)
	if n.length() < NAME_MIN or n.length() > NAME_MAX:
		return _reject(REASON_BAD_NAME)
	var state: StringName = _lobby.state()
	if state != &"waiting" and not (state in [&"countdown", &"in_match"] \
			and known_token_in_grace.is_valid() and known_token_in_grace.call(d.token)):
		return _reject(REASON_ROUND_IN_PROGRESS)
	if _lobby.player_count() + _pending.size() >= _knobs.lobby.max_players:
		return _reject(REASON_LOBBY_FULL)
	return {"ok": true}


func _reject(reason: StringName) -> Dictionary:
	return {"ok": false, "reason": String(reason)}


## Removes C0/C1 controls, DEL and the bidirectional override/isolate/mark characters.
static func sanitize_name(raw: String) -> String:
	var out := ""
	for i in raw.length():
		var c := raw.unicode_at(i)
		if c < 0x20 or (c >= 0x7F and c <= 0x9F) or (c >= 0x202A and c <= 0x202E) \
				or (c >= 0x2066 and c <= 0x2069) or c == 0x200E or c == 0x200F:
			continue
		out += raw.substr(i, 1)
	return out


func _on_peer_connected(id: int) -> void:
	if not _pending.has(id):
		return
	var player_id: int = _pending[id].player_id
	_pending.erase(id)
	_player_by_peer[id] = player_id
	_peer_by_player[player_id] = id
	player_joined.emit(player_id)


## Story 003 will turn this into player_dropped; for now only the id maps are cleared.
func _on_peer_disconnected(id: int) -> void:
	var player_id: int = _player_by_peer.get(id, -1)
	_player_by_peer.erase(id)
	if player_id != -1:
		_peer_by_player.erase(player_id)


func _on_auth_failed(id: int) -> void:
	if _pending.has(id):
		_tokens.erase(_pending[id].token)
		_pending.erase(id)
