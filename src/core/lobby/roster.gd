class_name Roster extends RefCounted
## The locked roster of one round (lobby-role-assignment.md rules 7, 8, 14; AC-LB-01, AC-LB-24). Built
## once at countdown 0 and never changed: `player_count` is fixed for the round. Players are named by
## player ID, never peer ID (control manifest: peer IDs stay inside NetAuthority; the GDD's "peer ID"
## predates that rule, AD-108). Phase M1: the shapeshifter is picked uniformly at random with the
## injected RNG (story 007's rotation queue replaces it); survivors' characters come from
## CharacterAssignment.deal_m1. Server-side; Match Flow and every reader see it through RosterView.
## Usage: `var r := Roster.lock(tokens, info, session_id, round_index, knobs, rng)` (null = refused)

const SHAPESHIFTER := &"shapeshifter"
const SURVIVOR := &"survivor"

var _session_id: String
var _round_index: int
var _player_count: int
## player ID -> {name: String, role: StringName, character: StringName (&"" for the shapeshifter)}
var _players: Dictionary[int, Dictionary] = {}


## Locks the roster for `tokens` (join order). `info` is Callable(token) -> {player_id: int, name:
## String}. Returns null when the count is outside lobby.min_players..max_players (AC-LB-01: 3 or 7
## refused), or when any token is unknown (player_id -1).
static func lock(tokens: PackedStringArray, info: Callable, session: String, index: int, knobs: Knobs,
		rng: RandomNumberGenerator) -> Roster:
	if tokens.size() < knobs.lobby.min_players or tokens.size() > knobs.lobby.max_players:
		return null
	var ids: Array[int] = []
	var names: Dictionary[int, String] = {}
	for t in tokens:
		var d: Dictionary = info.call(t)
		var pid: int = d.get("player_id", -1)
		if pid < 0 or names.has(pid): ## unknown token, or two tokens naming one player
			return null
		ids.append(pid)
		names[pid] = str(d.get("name", ""))
	var r := Roster.new()
	r._session_id = session
	r._round_index = index
	r._player_count = ids.size()
	var monster: int = ids[rng.randi_range(0, ids.size() - 1)]
	var survivors: Array[int] = ids.filter(func(id: int) -> bool: return id != monster)
	var chars := CharacterAssignment.deal_m1(survivors, CharacterDef.IDS, rng)
	for id in ids:
		r._players[id] = {"name": names[id], "role": SHAPESHIFTER if id == monster else SURVIVOR,
			"character": chars.get(id, &"")}
	return r


func session_id() -> String:
	return _session_id


func round_index() -> int:
	return _round_index


## Fixed for the round: nothing outside lock() can change it.
func player_count() -> int:
	return _player_count


## Player IDs in join order.
func player_ids() -> Array[int]:
	var out: Array[int] = []
	out.assign(_players.keys())
	return out


## The entry of `player_id`, a copy: {name, role, character}; {} when not on the roster.
func entry(player_id: int) -> Dictionary:
	return _players.get(player_id, {}).duplicate()
