class_name LobbySync extends RefCounted
## The lobby on the wire (lobby-role-assignment.md UI Requirements; TR-lobby-001, -007, -010). The server
## sends every client the whole lobby as one var_to_bytes Dictionary whenever it changes; clients only
## display it. A client's requests are Ready on or off and a preferred character (rule 12; story 012), fixed
## packets the server matches byte for byte, so untrusted client bytes are never decoded; a request only
## sets that player's flag or preference and the countdown still follows rule 13 on the server, so no
## client can start one. The rotation queue (rule 11) is sent head first, absent players included, with
## the first present player as the next shapeshifter.
## Rows carry player IDs and display names, never tokens (NetAuthority: tokens are secret).
## Wire: {"lobby": 1, "state": "waiting"|"countdown"|"in_match", "countdown_s": int, "voice": bool,
##   "host": player_id, "players": [{"id", "name", "ready", "pref"}, ...] in join order,
##   "queue": [{"id", "name"}, ...] head first ([] before the first round), "next": player_id or -1}.
## Usage (server, each tick):
##   lobby.server_tick(tick); var b := LobbySync.encode(lobby, tick, net.player_id_of_token, net.display_name_of)
##   if b != last: smp.send_bytes(b, 0, MultiplayerPeer.TRANSFER_MODE_RELIABLE, NetChannels.EVENT)
## Usage (server, peer_packet): LobbySync.apply_request(lobby, net.token_of(net.player_id_of(peer)), bytes)

## Decode cap: 8 rows plus MAX_QUEUE queue entries, each with a 16-character name of 4-byte characters,
## stay under it. Protocol constant, not a tuning knob.
const MAX_BYTES := 8192
## Rows a decoded lobby may hold; above lobby.max_players' range (5-6) with headroom. Protocol constant.
const MAX_ROWS := 8
## Queue entries sent and accepted. The queue keeps every token that joined the session (GDD Edge Cases:
## accepted), so a long session can outgrow it. Protocol constant.
## ponytail: entries past the cap are not shown; page or summarise if a session ever gets that long.
const MAX_QUEUE := 32
const _STATES: Array[String] = ["waiting", "countdown", "in_match"]

static var _ready_on := var_to_bytes({"lobby_ready": true})
static var _ready_off := var_to_bytes({"lobby_ready": false})
static var _pref_packets: Dictionary[StringName, PackedByteArray] = _make_pref_packets()


## The server's lobby as bytes for every client. `id_of` is Callable(token) -> player_id and `name_of`
## Callable(player_id) -> display name (NetAuthority.player_id_of_token, display_name_of; both keep a
## player who left, rule 10). `queue` is RosterHandoff.queue_order(), empty before the first round.
static func encode(lobby: LobbyState, tick: int, id_of: Callable, name_of: Callable,
		queue := PackedStringArray()) -> PackedByteArray:
	var rows: Array = []
	for token in lobby.tokens():
		var id: int = id_of.call(token)
		rows.append({"id": id, "name": name_of.call(id), "ready": lobby.is_ready(token),
				"pref": String(lobby.preference(token))})
	var present := lobby.tokens()
	var queue_rows: Array = []
	var next := -1
	for token in queue:
		var id: int = id_of.call(token)
		if next == -1 and present.has(token):
			next = id
		if queue_rows.size() < MAX_QUEUE:
			queue_rows.append({"id": id, "name": name_of.call(id)})
	return var_to_bytes({"lobby": 1, "state": String(lobby.state()), "countdown_s": ceili(lobby.remaining_s(tick)),
			"voice": lobby.proximity_voice(), "host": id_of.call(lobby.host_token) if lobby.host_token != "" else -1,
			"players": rows, "queue": queue_rows, "next": next})


## Client: the decoded lobby, or {} when `bytes` is not a well-formed lobby packet (other packets share
## the channel; a malformed one is ignored).
static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() > MAX_BYTES or bytes.size() < 4 or bytes.decode_u32(0) & 0xFF != TYPE_DICTIONARY:
		return {}
	var d: Variant = bytes_to_var(bytes)
	if not (d is Dictionary and d.size() == 8 and d.get("lobby") is int and d.get("state") is String
			and d.state in _STATES and d.get("countdown_s") is int and d.get("voice") is bool
			and d.get("host") is int and d.get("players") is Array and d.players.size() <= MAX_ROWS
			and d.get("queue") is Array and d.queue.size() <= MAX_QUEUE and d.get("next") is int):
		return {}
	for row: Variant in d.players:
		if not (row is Dictionary and row.size() == 4 and row.get("id") is int and row.get("name") is String
				and row.get("ready") is bool and row.get("pref") is String):
			return {}
	for row: Variant in d.queue:
		if not (row is Dictionary and row.size() == 2 and row.get("id") is int and row.get("name") is String):
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


## Client: the request packet for preferring `character` (one of CharacterDef.IDS).
static func preference_packet(character: StringName) -> PackedByteArray:
	return _pref_packets[character]


## Server: the character a preference request asks for, or &"" for any other bytes.
static func preference_request(bytes: PackedByteArray) -> StringName:
	for cid: StringName in _pref_packets:
		if bytes == _pref_packets[cid]:
			return cid
	return &""


## Server: applies a client's Ready or preference request to `token`; a preference while Ready is
## refused by LobbyState (rule 12, AC-LB-20). Any other bytes change nothing.
static func apply_request(lobby: LobbyState, token: String, bytes: PackedByteArray) -> void:
	apply_ready(lobby, token, bytes)
	var cid := preference_request(bytes)
	if cid != &"" and token != "":
		lobby.set_preference(token, cid)


static func _make_pref_packets() -> Dictionary[StringName, PackedByteArray]:
	var out: Dictionary[StringName, PackedByteArray] = {}
	for cid in CharacterDef.IDS:
		out[cid] = var_to_bytes({"lobby_pref": String(cid)})
	return out
