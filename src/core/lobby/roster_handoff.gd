class_name RosterHandoff extends RefCounted
## Turns a locked lobby into Match Flow's roster (lobby-role-assignment.md rule 14, AC-LB-24): at
## countdown 0 it locks the Roster and emits handed_off; Match Flow then starts the round
## (RoundServer.start_round builds the round's registry) and the composition root calls publish() to
## register the read-only RosterView under StateKeys.PLAYER_ROSTER. Sending the roster to clients and
## Loading on every peer belong to Match Flow. end_round() returns the lobby to Waiting after Results
## or a Cancelled round (AC-LB-27). A roster that cannot lock sends the lobby back to Waiting.
## Server only. Usage:
##   var handoff := RosterHandoff.new(lobby, RosterHandoff.info_from(net), knobs, rng, session_id)
##   handoff.handed_off.connect(func(r): server.start_round(modules, knobs); handoff.publish(server.registry))

signal handed_off(roster: Roster)

## The roster of the running round; null outside a round.
var roster: Roster

var _lobby: LobbyState
var _info: Callable
var _knobs: Knobs
var _rng: RandomNumberGenerator
var _session: String
var _round_index := 0


## `info`: Callable(token) -> {player_id, name}; info_from(net) builds it from NetAuthority.
func _init(lobby: LobbyState, info: Callable, knobs: Knobs, rng: RandomNumberGenerator, session_id: String) -> void:
	_lobby = lobby
	_info = info
	_knobs = knobs
	_rng = rng
	_session = session_id
	_lobby.roster_locked.connect(_on_locked)


## The `info` callable over NetAuthority's server-side token and name maps.
static func info_from(net: NetAuthority) -> Callable:
	return func(token: String) -> Dictionary:
		var pid := net.player_id_of_token(token)
		return {"player_id": pid, "name": net.display_name_of(pid)}


## Registers the running round's RosterView in that round's (fresh) registry. Call once per round,
## after RoundServer.start_round.
func publish(registry: StateRegistry) -> void:
	if roster == null:
		push_error("RosterHandoff.publish: no locked roster")
		return
	registry.register_view(StateKeys.PLAYER_ROSTER, &"Lobby", RosterView.new(roster))


## After Results or a Cancelled round: every connected player back in Waiting, Ready cleared.
func end_round() -> void:
	roster = null
	_lobby.return_to_waiting()


func _on_locked(tokens: PackedStringArray) -> void:
	var r := Roster.lock(tokens, _info, _session, _round_index + 1, _knobs, _rng)
	if r == null:
		push_error("RosterHandoff: roster of %d refused (outside %d-%d, unknown or repeated player)" % [
			tokens.size(), _knobs.lobby.min_players, _knobs.lobby.max_players])
		_lobby.return_to_waiting()
		return
	_round_index += 1
	roster = r
	handed_off.emit(r)
