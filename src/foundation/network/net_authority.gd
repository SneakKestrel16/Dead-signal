class_name NetAuthority extends Node
## Host, join and join validation over ENet direct IP (ADR-0001). The server role is separable:
## host() starts and runs with no local player; the host's own player is added by the caller.
## Created and injected by the composition root; never an autoload.
## Everything outside this class is keyed by player_id; peer IDs never leave it.
## Wire: client sends var_to_bytes({version, display_name, token}) with send_auth(1, ..); the
## server replies {ok: true, player_id, token} or {ok: false, reason[, server_version, client_version]}.
## One round trip per join. A rejected peer is disconnected after reject_close_delay_s (a reason
## sent immediately before disconnect_peer is lost, ADR-0001 verification 6).
## Reconnect (ADR-0001 §5): a join carrying a known token rebinds that player ID to the new peer when
## the player is still bound (its old peer has not timed out) or known_token_in_grace says so. In
## Waiting a known token whose player left the lobby joins again under its own token and player ID
## (lobby rule 10, story lobby-role-assignment/008: it keeps its queue place); any other token is a new join. A still-connected old peer is evicted with disconnect_peer and raises
## no player_dropped. Per-peer visibility granted with set_player_visibility() follows the player to
## the new peer. Snapshots need nothing here: ServerMovement looks the peer up every tick and every
## snapshot is full (there are no deltas yet).
## Usage:
##   var net := NetAuthority.new(); net.setup(knobs, "1.0+ab12cd34", lobby)
##   add_child(net); net.host(knobs.net.port)          # or net.join("1.2.3.4", port, "Ann")

## Client: the host kicked this player (lobby rule 20). The connection closes after this; host_left is
## not raised for it. The player may join again with local_token.
signal kicked(reason: StringName)
## Server: a player passed auth and its peer connected. Client-side nothing is emitted.
signal player_joined(player_id: int)
## Server: a bound player's peer disconnected. Never raised for a peer evicted by a reconnect.
signal player_dropped(player_id: int)
## Server: a known token rebound its player to a new peer (after any eviction and visibility re-grant).
signal player_rejoined(player_id: int, new_peer_id: int)
## Client: the server refused the join. Reason is one of REASON_*; details in last_reject_details.
signal join_rejected(reason: StringName)
## Server: a join was refused with `reason` (one of REASON_*). The reply is on its way to the client.
signal join_refused(reason: StringName)
## Client: the server went away after this client was admitted (host quit, or the server timed out).
## ADR-0001 §7: the caller returns to the main menu with "Host left" and records no result.
signal host_left
## Server: create_server failed (e.g. port in use). Nothing was left initialised.
signal host_failed(error: Error)
## Server: host() refused because the knobs have errors (ADR-0006 §4); `errors` is Knobs.errors(), every
## one, for the host UI to list. create_server was never called.
signal host_refused(errors: PackedStringArray)

const REASON_LOBBY_FULL := &"lobby_full"
const REASON_ROUND_IN_PROGRESS := &"round_in_progress"
const REASON_VERSION_MISMATCH := &"version_mismatch"
const REASON_BAD_NAME := &"bad_name"
const REASON_BAD_PAYLOAD := &"bad_payload"
## A second join with the same token while the first is still authenticating (one wins).
const REASON_TOKEN_IN_USE := &"token_in_use"
## Sent to a kicked peer (kick()); the client raises kicked with it.
const REASON_KICKED := &"kicked"
## The kick notice on the wire (a static var: a const cannot call var_to_bytes).
static var _kick_packet := var_to_bytes({"kicked": String(REASON_KICKED)})

## ENet's default throttle measurement interval (ENET_PEER_PACKET_THROTTLE_INTERVAL); protocol constant.
const THROTTLE_INTERVAL_MS := 5000

## Server seam: Callable(token: String) -> bool, true when the token's player is inside its reconnect
## grace (Match Flow owns grace, story 003). Asked only for a known token whose player is unbound.
## Unset means false.
var known_token_in_grace: Callable
## Client: extra fields of the last rejection (version_mismatch carries server_version, client_version).
var last_reject_details: Dictionary = {}
## When true a refused host() also ends in assert(false) (ADR-0006 §4: debug builds assert). Default:
## debug builds only; tests and the manual harness set false to observe the refusal.
var fail_hard: bool = OS.is_debug_build()
## Client: the player_id and token the server issued. The token is a secret: never log or send it on.
var local_player_id: int = -1
var local_token: String = ""
## Client: the server kicked this session (kicked was raised).
var was_kicked: bool = false

var _knobs: Knobs
var _version: String
## Provider object with state() -> StringName (&"waiting"/&"countdown"/&"in_match") and player_count() -> int.
var _lobby: Object
var _smp: SceneMultiplayer
var _display_name: String = ""
var _join_token: String = ""
var _player_by_peer: Dictionary = {}
var _peer_by_player: Dictionary = {}
## Authenticated but not yet connected: peer_id -> {player_id, token, rebind}. A new join counts
## toward the cap; a rebind does not.
var _pending: Dictionary = {}
## token -> player_id.
var _tokens: Dictionary = {}
## Server: player ID -> sanitized display name, for the roster (LB-2). Public: names are shown.
var _names: Dictionary[int, String] = {}
## player_id -> Array of MultiplayerSynchronizer this player may see (set_player_visibility).
var _visibility: Dictionary = {}
var _next_player_id: int = 0


## Injects dependencies. `version` is the full build string compared exactly; `lobby` is the state provider.
func setup(knobs: Knobs, version: String, lobby: Object) -> void:
	_knobs = knobs
	_version = version
	_lobby = lobby


## Starts the listen server on `port`. Refuses (host_refused, ERR_INVALID_DATA) while the knobs have
## any error; on a socket failure emits host_failed. Either way nothing is left initialised.
func host(port: int) -> Error:
	if _smp != null:
		return ERR_ALREADY_IN_USE
	var errs := _knobs.errors()
	if not errs.is_empty():
		host_refused.emit(errs)
		assert(not fail_hard, "refusing to host: %d knob errors: %s" % [errs.size(), "; ".join(errs)])
		return ERR_INVALID_DATA
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
## connected_to_server. Pass the stored local_token to reconnect. Returns the create_client error.
func join(address: String, port: int, display_name: String, token: String = "") -> Error:
	if _smp != null:
		return ERR_ALREADY_IN_USE
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	_display_name = display_name
	_join_token = token
	# A new session starts unadmitted: a stale ID from an earlier session would turn this session's
	# reject-and-close into host_left (code review 2026-10-14). The caller already passed the old token.
	local_player_id = -1
	local_token = ""
	last_reject_details = {}
	was_kicked = false
	_attach(peer, _client_auth)
	_smp.peer_authenticating.connect(_on_authenticating)
	_smp.connected_to_server.connect(_on_connected_to_server)
	_smp.server_disconnected.connect(_on_server_disconnected)
	_smp.peer_packet.connect(_on_client_packet)
	return OK


## Closes the connection or server and returns to the unstarted state. Safe to call twice.
func close() -> void:
	if _smp != null:
		if _smp.multiplayer_peer != null:
			_smp.multiplayer_peer.close()
		_smp.auth_callback = Callable()
		_smp.multiplayer_peer = null
		for sig in [&"peer_connected", &"peer_disconnected", &"peer_authentication_failed", &"peer_authenticating",
				&"connected_to_server", &"server_disconnected", &"peer_packet"]:
			for c in _smp.get_signal_connection_list(sig):
				if c.callable.get_object() == self:
					_smp.disconnect(sig, c.callable)
	_smp = null
	_player_by_peer.clear()
	_peer_by_player.clear()
	_pending.clear()
	_tokens.clear()
	_names.clear()
	_visibility.clear()


## The player bound to `peer_id`, or -1 when unbound.
func player_id_of(peer_id: int) -> int:
	return _player_by_peer.get(peer_id, -1)


## The connected peer of `player_id`, or -1 when disconnected.
func peer_id_of(player_id: int) -> int:
	return _peer_by_player.get(player_id, -1)


## Server: the session token of `player_id`, or "" when unknown. Server-side routing only (the lobby is
## keyed by token); never send or log it.
func token_of(player_id: int) -> String:
	for token: String in _tokens:
		if _tokens[token] == player_id:
			return token
	return ""


## Server: the player whose session token is `token`, or -1. Server-side routing only (the lobby is
## keyed by token).
func player_id_of_token(token: String) -> int:
	return _tokens.get(token, -1)


## Server: `player_id`'s sanitized display name (the latest it joined with), or "" when unknown.
func display_name_of(player_id: int) -> String:
	return _names.get(player_id, "")


## Server: disconnects `player_id`'s peer with REASON_KICKED (lobby rule 20; the lobby validated the
## kick). The player is unbound at once, so its disconnect raises no player_dropped; the token and
## player ID stay, so a later join with that token is the Waiting rejoin path (same ID, queue place).
## The peer closes after reject_close_delay_s (a reason sent immediately before disconnect_peer is lost,
## ADR-0001 verification 6). Returns false when the player has no connected peer.
func kick(player_id: int) -> bool:
	var peer := peer_id_of(player_id)
	if peer == -1:
		return false
	_player_by_peer.erase(peer)
	_peer_by_player.erase(player_id)
	for sync: Variant in _visibility.get(player_id, []):
		if is_instance_valid(sync):
			(sync as MultiplayerSynchronizer).set_visibility_for(peer, false)
	_smp.send_bytes(_kick_packet, peer, MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	_close_after_delay(peer)
	return true


## Server: lets `player_id` see (or stop seeing) `sync`, now and on every later peer of that player.
## The synchronizer should have public_visibility = false. Callers name players, never peers.
func set_player_visibility(sync: MultiplayerSynchronizer, player_id: int, visible: bool) -> void:
	var list: Array = _visibility.get_or_add(player_id, [])
	if visible and not sync in list:
		list.append(sync)
	elif not visible:
		list.erase(sync)
	var peer := peer_id_of(player_id)
	if peer != -1:
		sync.set_visibility_for(peer, visible)


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
	var payload := {"version": _version, "display_name": _display_name, "token": _join_token}
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


## ADR-0001 §6: the client side of the dead-peer timeout, set once the server peer exists.
func _on_connected_to_server() -> void:
	var enet := _smp.multiplayer_peer as ENetMultiplayerPeer
	if enet != null:
		_set_timeout(enet.get_peer(1))


## The server's kick notice (kick()), matched byte for byte: every snapshot and event batch passes
## through here too, so nothing is decoded. Other packets belong to other listeners.
func _on_client_packet(peer_id: int, data: PackedByteArray) -> void:
	if peer_id == 1 and not was_kicked and data == _kick_packet:
		was_kicked = true
		kicked.emit(REASON_KICKED)


func _on_server_disconnected() -> void:
	if local_player_id >= 0 and not was_kicked:
		host_left.emit()


func _reject_client(reason: StringName, details: Dictionary) -> void:
	last_reject_details = details
	join_rejected.emit(reason)


# --- server ------------------------------------------------------------------

func _server_auth(id: int, data: PackedByteArray) -> void:
	# A peer gets one verdict: a repeat packet while pending or after joining would mint a second
	# player ID and token and orphan the first (SR-1 review 2026-10-14).
	if _pending.has(id) or player_id_of(id) != -1:
		return
	var verdict := _validate(data)
	if verdict.ok:
		var rebind: bool = verdict.get("rebind", false)
		var player_id: int = verdict.get("player_id", _next_player_id)
		var token: String = verdict.get("token", "")
		if not verdict.has("player_id"):
			_next_player_id += 1
			token = Crypto.new().generate_random_bytes(16).hex_encode()
			_tokens[token] = player_id
		_pending[id] = {"player_id": player_id, "token": token, "rebind": rebind}
		_names[player_id] = verdict.name
		_smp.send_auth(id, var_to_bytes({"ok": true, "player_id": player_id, "token": token}))
		_smp.complete_auth(id)
		return
	_smp.send_auth(id, var_to_bytes(verdict))
	join_refused.emit(StringName(verdict.reason))
	var smp := _smp
	await get_tree().create_timer(_knobs.net.reject_close_delay_s).timeout
	if _smp == smp and id in _smp.get_authenticating_peers(): ## not a session started since
		_smp.disconnect_peer(id)


## Runs the checks in the ADR order. Returns {ok: true, name} (plus player_id and token for a known
## token, and rebind: true when it rebinds a bound or in-grace player) or the reject reply.
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
	if n.length() < _knobs.lobby.name_min_chars or n.length() > _knobs.lobby.name_max_chars:
		return _reject(REASON_BAD_NAME)
	var known_id: int = _tokens.get(d.token, -1)
	if known_id != -1:
		for p: Dictionary in _pending.values():
			if p.player_id == known_id:
				return _reject(REASON_TOKEN_IN_USE)
		if peer_id_of(known_id) != -1 or _in_grace(d.token):
			return {"ok": true, "player_id": known_id, "token": d.token, "name": n, "rebind": true}
	if _lobby.state() != &"waiting":
		return _reject(REASON_ROUND_IN_PROGRESS)
	var new_joins := _pending.values().filter(func(p: Dictionary) -> bool: return not p.rebind).size()
	if _lobby.player_count() + new_joins >= _knobs.lobby.max_players:
		return _reject(REASON_LOBBY_FULL)
	if known_id != -1:
		# A lobby leaver returning in Waiting: a join like any other, but the session still holds its
		# token (TR-lobby-004), so it keeps its player ID and rotation-queue place (lobby rule 10).
		return {"ok": true, "player_id": known_id, "token": d.token, "name": n}
	return {"ok": true, "name": n}


func _in_grace(token: String) -> bool:
	return known_token_in_grace.is_valid() and known_token_in_grace.call(token)


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


## Disconnects connected `peer` after reject_close_delay_s, unless the session was closed or restarted.
func _close_after_delay(peer: int) -> void:
	var smp := _smp
	await get_tree().create_timer(_knobs.net.reject_close_delay_s).timeout
	if _smp == smp and peer in _smp.get_peers():
		_smp.disconnect_peer(peer)


func _on_peer_connected(id: int) -> void:
	if not _pending.has(id):
		return
	var player_id: int = _pending[id].player_id
	var rebind: bool = _pending[id].rebind
	var token: String = _pending[id].token
	_pending.erase(id)
	var old := peer_id_of(player_id)
	# Auth may have admitted the rebind because the old peer was still bound; if it dropped before
	# this peer connected (player_dropped already raised), only grace can admit it now.
	if rebind and old == -1 and not _in_grace(token):
		_smp.disconnect_peer(id)
		return
	var syncs: Array = _visibility.get(player_id, [])
	syncs = syncs.filter(func(s: Variant) -> bool: return is_instance_valid(s))
	_visibility[player_id] = syncs
	if old != -1:
		# Unbind and revoke first: the evicted peer's peer_disconnected then finds no player and raises
		# nothing, and the replication interface forgets a peer once it is disconnected.
		_player_by_peer.erase(old)
		for sync: MultiplayerSynchronizer in syncs:
			sync.set_visibility_for(old, false)
		_smp.disconnect_peer(old)
	_player_by_peer[id] = player_id
	_peer_by_player[player_id] = id
	for sync: MultiplayerSynchronizer in syncs:
		sync.set_visibility_for(id, true)
	# ENet's packet throttle drops unreliable packets when the measured round trip rises. Under 30 ms
	# jitter that starved input: 58-62 corrections per ~4360 states without this, 1 per ~4820 with it
	# (story 006, prediction_reconcile_test.gd, 2026-10-13). The game has its own redundancy (3 frames
	# per input packet, a snapshot every tick), so keep the throttle full: acceleration to the limit,
	# no deceleration. ENet sends the command to the client, which applies it to its side.
	var enet := _smp.multiplayer_peer as ENetMultiplayerPeer
	var packet_peer := enet.get_peer(id) if enet != null else null
	if packet_peer != null:
		packet_peer.throttle_configure(THROTTLE_INTERVAL_MS, ENetPacketPeer.PACKET_THROTTLE_SCALE, 0)
		_set_timeout(packet_peer)
	if rebind:
		player_rejoined.emit(player_id, id)
	else:
		player_joined.emit(player_id)


## ADR-0001 §6: dead-peer detection from data, on both sides.
func _set_timeout(packet_peer: ENetPacketPeer) -> void:
	if packet_peer != null:
		packet_peer.set_timeout(_knobs.net.enet_timeout_limit, _knobs.net.enet_timeout_min_ms, _knobs.net.enet_timeout_max_ms)


## Raises player_dropped for a bound player. An evicted peer was unbound first, so it raises nothing.
## ConnectionRouter (Core) routes it to the lobby or the round (story 003).
func _on_peer_disconnected(id: int) -> void:
	var player_id: int = _player_by_peer.get(id, -1)
	_player_by_peer.erase(id)
	if player_id != -1:
		_peer_by_player.erase(player_id)
		player_dropped.emit(player_id)


## Also raised for a peer that passed our auth_callback but disconnected before connecting (verified
## 2026-10-14, tokens_reconnect_test.gd), so a pending rebind cannot hold its token as token_in_use.
func _on_auth_failed(id: int) -> void:
	if _pending.has(id):
		if not _pending[id].rebind:
			_tokens.erase(_pending[id].token)
			_names.erase(_pending[id].player_id) ## a new joiner that never joined leaves no name behind
		_pending.erase(id)
