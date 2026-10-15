class_name ConnectionRouter extends RefCounted
## Routes NetAuthority's join and drop notifications to the owner of the current phase (ADR-0001 §6).
## Lobby phase (Waiting, Countdown): a join adds the player to the lobby, a drop removes them at once
## (lobby rule 18); a host kick the lobby accepted disconnects the player's peer (lobby rule 20); a
## proximity voice change goes to every client, and a joining or rejoining player gets the current
## value (lobby rule 16, AC-LB-26). In a round (In Match): a drop starts the player's reconnect grace at the detection
## tick and emits PlayerConnectionChanged (DISCONNECTED); a rejoin inside grace emits RECONNECTED.
## Stand-in for Match Flow's half until the Match Flow epic exists: grace expiry and forfeit are its
## (story 003 Out of Scope), and it takes over emitting PlayerConnectionChanged (systems-index emitter).
## Server only; keyed by player ID, with the token used only to address the lobby.
## One router per NetAuthority for the whole session: it connects to the net's signals and never
## disconnects, so a second router on the same net would route every drop twice.
## Usage:
##   var router := ConnectionRouter.new(knobs, net, lobby, runner.current_tick)
##   net.known_token_in_grace = router.in_grace
##   router.bus = round_bus   # while a round runs; null in the lobby

## The running round's bus; null outside a round (nothing is emitted then).
var bus: EventBus

var _knobs: Knobs
var _net: NetAuthority
var _lobby: LobbyState
var _clock: Callable
## player_id -> server tick its drop was detected, for players dropped during a round.
var _grace_start: Dictionary[int, int] = {}


## `clock` is Callable() -> int, the current server tick.
func _init(knobs: Knobs, net: NetAuthority, lobby: LobbyState, clock: Callable) -> void:
	_knobs = knobs
	_net = net
	_lobby = lobby
	_clock = clock
	net.player_joined.connect(_on_joined)
	net.player_dropped.connect(_on_dropped)
	net.player_rejoined.connect(_on_rejoined)
	lobby.player_kicked.connect(_on_kicked)
	lobby.proximity_voice_changed.connect(_on_proximity_voice_changed)


## Server tick at which `player_id`'s grace started, or -1 when it is not in grace.
func grace_start_tick(player_id: int) -> int:
	return _grace_start.get(player_id, -1)


## NetAuthority.known_token_in_grace: true while the token's player is inside reconnect_grace_s.
func in_grace(token: String) -> bool:
	var limit := _knobs.ticks(_knobs.match_flow.reconnect_grace_s)
	for pid in _grace_start:
		if _net.token_of(pid) == token:
			return _clock.call() - _grace_start[pid] < limit
	return false


func _in_lobby_phase() -> bool:
	return _lobby.state() != LobbyState.IN_MATCH


func _on_joined(player_id: int) -> void:
	_lobby.join(_net.token_of(player_id))
	_net.send_proximity_voice(_lobby.proximity_voice(), player_id)


func _on_dropped(player_id: int) -> void:
	if _in_lobby_phase():
		_lobby.leave(_net.token_of(player_id))
		return
	_grace_start[player_id] = _clock.call()
	_emit(player_id, EvPlayerConnectionChanged.DISCONNECTED)


func _on_kicked(token: String) -> void:
	_net.kick(_net.player_id_of_token(token))


func _on_proximity_voice_changed(on: bool) -> void:
	_net.send_proximity_voice(on)


func _on_rejoined(player_id: int, _new_peer: int) -> void:
	_net.send_proximity_voice(_lobby.proximity_voice(), player_id)
	if _grace_start.erase(player_id):
		_emit(player_id, EvPlayerConnectionChanged.RECONNECTED)


func _emit(player_id: int, status: int) -> void:
	if bus == null:
		return
	var e := EvPlayerConnectionChanged.new()
	e.player = player_id
	e.status = status
	bus.emit(e)
