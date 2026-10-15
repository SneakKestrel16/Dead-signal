class_name LobbyState extends RefCounted
## The lobby's server-side state machine (lobby-role-assignment.md States and Transitions, rule 13;
## ADR-0002: timers counted in ticks on the server clock). Waiting -> Countdown when at least
## `min_players` are connected and every one is Ready; a countdown is cancelled back to Waiting by any
## un-ready, leave or join, and restarts at the full `lobby_countdown_s`. When it reaches 0 the roster
## locks. Rule 13 is re-checked at lock by construction (GDD Edge Cases): every trigger cancels at the
## moment it is applied, so a disconnect processed in the lock tick has already sent the lobby back to
## Waiting before server_tick() runs.
## Server only: clients display the replicated state and never call these methods.
## In Match the lobby is dormant: joins, leaves and Ready changes still update its membership (for
## return_to_waiting, AC-LB-27) but never touch the roster already handed to Match Flow.
## Not thread-safe: server main thread only. Host left -> Closed belongs to network-authority story 003.
## Usage:
##   var lobby := LobbyState.new(knobs)
##   lobby.join("tok-a"); lobby.set_ready("tok-a", true)
##   lobby.server_tick(tick)   # once per server tick
##   lobby.roster_locked.connect(match_flow.start)

## The countdown reached 0 and rule 13 still held: these tokens play. RosterHandoff builds the roster.
signal roster_locked(tokens: PackedStringArray)

const WAITING := &"waiting"
const COUNTDOWN := &"countdown"
const IN_MATCH := &"in_match"

var _knobs: Knobs
var _state := WAITING
var _ready_by_token: Dictionary[String, bool] = {} ## token -> Ready, one entry per connected player, in join order
var _start_tick := -1 ## tick the running countdown started; -1 when none runs


## `knobs` must be valid (Knobs.errors() empty): reads lobby.min_players, lobby.lobby_countdown_s
## and net.sim_tick_hz through Knobs.ticks().
func _init(knobs: Knobs) -> void:
	_knobs = knobs


## WAITING, COUNTDOWN or IN_MATCH. NetAuthority's join check reads it.
func state() -> StringName:
	return _state


## Connected players. NetAuthority's lobby-full check reads it.
func player_count() -> int:
	return _ready_by_token.size()


## Connected tokens in join order (humans only: no bot ever fills a seat, rule 4).
func tokens() -> PackedStringArray:
	return PackedStringArray(_ready_by_token.keys())


## Adds a connected player, not Ready. Cancels a running countdown (rule 13).
func join(token: String) -> void:
	if _ready_by_token.has(token):
		return
	_ready_by_token[token] = false
	_cancel()


## Removes a player (leave or disconnect). Cancels a running countdown (rule 13).
func leave(token: String) -> void:
	if _ready_by_token.erase(token):
		_cancel()


## Sets a player's Ready flag; un-readying cancels a running countdown (rule 13).
func set_ready(token: String, is_ready: bool) -> void:
	if not _ready_by_token.has(token) or _ready_by_token[token] == is_ready:
		return
	_ready_by_token[token] = is_ready
	if not is_ready:
		_cancel()


## Seconds left on the countdown at `tick`, in [0, lobby_countdown_s]; the full value when none runs.
func remaining_s(tick: int) -> float:
	return float(_remaining_ticks(tick)) / _knobs.net.sim_tick_hz


## Advances the machine on server tick `tick`. Starts the countdown on the first tick rule 13 holds;
## at 0 locks the roster (IN_MATCH, roster_locked).
func server_tick(tick: int) -> void:
	if _state == WAITING and _rule_13():
		_state = COUNTDOWN
		_start_tick = tick
	elif _state == COUNTDOWN and _remaining_ticks(tick) == 0:
		_state = IN_MATCH
		_start_tick = -1
		roster_locked.emit(tokens())


## After Results or a Cancelled round (AC-LB-27): back to Waiting with every Ready cleared. Players
## who left during the match (a survivor whose grace expired) were removed by leave() and are absent.
func return_to_waiting() -> void:
	if _state != IN_MATCH:
		return
	_state = WAITING
	for token in _ready_by_token:
		_ready_by_token[token] = false


## Rule 13: at least min_players connected and every connected player Ready.
func _rule_13() -> bool:
	if _ready_by_token.size() < _knobs.lobby.min_players:
		return false
	for token in _ready_by_token:
		if not _ready_by_token[token]:
			return false
	return true


func _remaining_ticks(tick: int) -> int:
	var total := _knobs.ticks(_knobs.lobby.lobby_countdown_s)
	if _start_tick == -1:
		return total
	return clampi(total - (tick - _start_tick), 0, total)


func _cancel() -> void:
	if _state == COUNTDOWN:
		_state = WAITING
		_start_tick = -1
