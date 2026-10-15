class_name LobbySync extends RefCounted
## The lobby on the wire (lobby-role-assignment.md UI Requirements; TR-lobby-001, -007, -010). The server
## sends every client the whole lobby as one var_to_bytes Dictionary whenever it changes; clients only
## display it. A client's one request is Ready on or off, two fixed packets the server matches byte for
## byte, so untrusted client bytes are never decoded; the request only sets that player's flag and the
## countdown still follows rule 13 on the server, so no client can start one.
## Rows carry player IDs and display names, never tokens (NetAuthority: tokens are secret).
## Wire: {"lobby": 1, "state": "waiting"|"countdown"|"in_match", "countdown_s": int, "voice": bool,
##   "host": player_id, "players": [{"id", "name", "ready", "pref"}, ...] in join order}.
## Usage (server, each tick):
##   lobby.server_tick(tick); var b := LobbySync.encode(lobby, tick, net.player_id_of_token, net.display_name_of)
##   if b != last: smp.send_bytes(b, 0, MultiplayerPeer.TRANSFER_MODE_RELIABLE, NetChannels.EVENT)
## Usage (server, peer_packet): LobbySync.apply_ready(lobby, net.token_of(net.player_id_of(peer)), bytes)

## Decode cap: 6 rows of a 16-character name are far under it. Protocol constant, not a tuning knob.
const MAX_BYTES := 4096
## Rows a decoded lobby may hold; above lobby.max_players' range (5-6) with headroom. Protocol constant.
const MAX_ROWS := 8
const _STATES: Array[String] = ["waiting", "countdown", "in_match"]

static var _ready_on := var_to_bytes({"lobby_ready": true})
static var _ready_off := var_to_bytes({"lobby_ready": false})


## The server's lobby as bytes for every client. `id_of` is Callable(token) -> player_id and `name_of`
## Callable(player_id) -> display name (NetAuthority.player_id_of_token, display_name_of).
static func encode(lobby: LobbyState, tick: int, id_of: Callable, name_of: Callable) -> PackedByteArray:
	var rows: Array = []
	for token in lobby.tokens():
		var id: int = id_of.call(token)
		rows.append({"id": id, "name": name_of.call(id), "ready": lobby.is_ready(token),
				"pref": String(lobby.preference(token))})
	return var_to_bytes({"lobby": 1, "state": String(lobby.state()), "countdown_s": ceili(lobby.remaining_s(tick)),
			"voice": lobby.proximity_voice(), "host": id_of.call(lobby.host_token) if lobby.host_token != "" else -1,
			"players": rows})


## Client: the decoded lobby, or {} when `bytes` is not a well-formed lobby packet (other packets share
## the channel; a malformed one is ignored).
static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() > MAX_BYTES or bytes.size() < 4 or bytes.decode_u32(0) & 0xFF != TYPE_DICTIONARY:
		return {}
	var d: Variant = bytes_to_var(bytes)
	if not (d is Dictionary and d.size() == 6 and d.get("lobby") is int and d.get("state") is String
			and d.state in _STATES and d.get("countdown_s") is int and d.get("voice") is bool
			and d.get("host") is int and d.get("players") is Array and d.players.size() <= MAX_ROWS):
		return {}
	for row: Variant in d.players:
		if not (row is Dictionary and row.size() == 4 and row.get("id") is int and row.get("name") is String
				and row.get("ready") is bool and row.get("pref") is String):
			return {}
	return d


## Client: the Ready request packet.
static func ready_packet(on: bool) -> PackedByteArray:
	return _ready_on if on else _ready_off


## Server: 1 for a Ready-on request, 0 for Ready-off, -1 for any other bytes.
static func ready_request(bytes: PackedByteArray) -> int:
	if bytes == _ready_on:
		return 1
	if bytes == _ready_off:
		return 0
	return -1


## Server: applies a client's packet to `token`'s Ready flag when it is a Ready request; anything else
## changes nothing (it belongs to another listener).
static func apply_ready(lobby: LobbyState, token: String, bytes: PackedByteArray) -> void:
	var r := ready_request(bytes)
	if r != -1 and token != "":
		lobby.set_ready(token, r == 1)
