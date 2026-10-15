class_name MatchFlow extends RefCounted
## Match Flow round clock and phase machine (Feature layer). Implements design/gdd/match-flow.md
## rules 4-7, Formulas "Phase from elapsed time"; story match-flow/001; ADR-0005.
## Server only. Time comes from counted ticks (`net.sim_tick_hz`), never wall time. The phase only
## moves forward and each move emits exactly one RoundPhaseChanged.
## Usage:
##   var mf := MatchFlow.new()
##   server.start_round({TickOrder.MATCH_FLOW_BEGIN: mf, TickOrder.MATCH_FLOW_RESOLVE: mf.resolve_step()}, knobs)
## Story 002 (rules 8-18): the RESOLVE slot runs the win check in rule 16 order and emits one
## RoundEnded. Set `survivor_ids` before start_round; in production from the locked Roster:
##   mf.survivor_ids.assign(roster.player_ids().filter(
##       func(id: int) -> bool: return roster.entry(id).role == Roster.SURVIVOR))
## Story 003 (rules 10, 14, 15): the BEGIN slot detects escapes (`set_exit`); both drives Extracted
## locks a survivor win, and the round ends at the first of all-out, deadline or the post-escape window.
## Story 005 (rules 19, 21, 22): Match Flow owns the reconnect grace timer. A DISCONNECTED notice starts it
## at the event's tick (the drop's detection tick); RECONNECTED stops it; `reconnect_grace_s` later the
## RESOLVE slot emits GRACE_EXPIRED and runs the win check on that tick. Every disconnect and reconnect is
## logged through the bus's delivered-event list (`EventBus.take_tick_events`), the only log path so far.
## Story 006 (rule 20): set `shapeshifter_id` before start_round; when its grace expires the win check
## forfeits to the survivors, last in rule 16 order, so an earned result in the same tick beats it.
## Story 007 (ADR-0004 §9): `catch_up()` is the round state a reconnecting client missed, as the events
## that set it; ServerMovement re-projects and sends them to that client once (`ServerMovement.catch_up`).

enum Phase { INFILTRATION, INVESTIGATION, EVACUATION }
## `RoundEnded.outcome` values; text in OUTCOME_TEXT (rule 23).
enum Outcome { SURVIVORS_WIN, SHAPESHIFTER_WINS }
## `RoundEnded.reason` values, in rule 16 check order; text in REASON_TEXT (rule 23).
enum Reason { EVIDENCE_ESCAPED, ALL_ELIMINATED, EVIDENCE_LOST, DEADLINE, FORFEIT }
## Per-survivor status for win evaluation, from events only. HEALTHY and DOWNED count as inside, also
## while in reconnect grace (rule 13); DISCONNECTED is grace expired and counts as eliminated (rule 19).
## DID_NOT_ESCAPE: still inside when the round ended (rules 15, 24).
enum Status { HEALTHY, DOWNED, ESCAPED, ELIMINATED, DISCONNECTED, DID_NOT_ESCAPE }

const OUTCOME_TEXT: Array[String] = ["Survivors Win", "Shapeshifter Wins"]
const REASON_TEXT: Array[String] = ["Evidence escaped", "All survivors eliminated", "Evidence lost",
	"Evacuation deadline expired", "Shapeshifter forfeited"]

## Player IDs of this round's survivors; set before start_round (read in setup). Empty disables the
## all-eliminated and evidence-lost checks (no roster, e.g. clock-only tests).
var survivor_ids: Array[int] = []
## Player ID of this round's shapeshifter; set before start_round. -1: nobody can forfeit.
var shapeshifter_id: int = -1


var _bus: EventBus
var _hz: int = 0
var _infiltration_end_s: float = 0.0
var _evac_start_s: float = 0.0
var _round_duration_s: float = 0.0
var _elapsed_ticks: int = 0
var _phase: Phase = Phase.INFILTRATION
var _terminal_armed: bool = false
var _status: Dictionary[int, Status] = {}
var _extracted: Dictionary[int, bool] = {} ## drive objective ids reported EXTRACTED
var _ended: bool = false
var _exit_open: bool = false
## Elapsed ticks at which the post-escape window closes; -1 until the outcome locks (rule 14).
var _lock_end_ticks: int = -1
var _window_ticks: int = 0
var _exit: MapQueries
var _position_of: Callable
## player id -> tick its drop was detected, while in reconnect grace (any role: story 006 reads it too).
var _grace_start: Dictionary[int, int] = {}
var _grace_ticks: int = 0
var _forfeited: bool = false ## the shapeshifter's grace expired (rule 20)
## Catch-up record: every RoundPhaseChanged emitted, the latest life-state event per survivor, the open
## connection event (DISCONNECTED / GRACE_EXPIRED) per player, and RoundEnded.
var _phase_events: Array[ServerEvent] = []
var _life_event: Dictionary[int, ServerEvent] = {}
var _conn_event: Dictionary[int, ServerEvent] = {}
var _ended_event: ServerEvent


## Getter-only view of the clock for StateKeys.ROUND_CLOCK readers. Holds the module weakly, so no
## RefCounted cycle survives end_round(); after the module is freed it reads as a zeroed clock.
class ClockView extends RefCounted:
	var _mf: WeakRef

	func _init(mf: MatchFlow) -> void:
		_mf = weakref(mf)

	## Current Phase.
	func phase() -> int:
		var mf := _mf.get_ref() as MatchFlow
		return mf.phase() if mf != null else MatchFlow.Phase.INFILTRATION

	## Seconds left to the deadline, clamped at 0.
	func time_remaining_s() -> float:
		var mf := _mf.get_ref() as MatchFlow
		return mf.time_remaining_s() if mf != null else 0.0

	## Seconds since the round clock started.
	func elapsed_s() -> float:
		var mf := _mf.get_ref() as MatchFlow
		return mf.elapsed_s() if mf != null else 0.0


## Runs in the MATCH_FLOW_RESOLVE slot; forwards to `MatchFlow._on_resolve`. Holds the module
## weakly (the BEGIN registration keeps it alive for the round).
class ResolveStep extends RefCounted:
	var _mf: WeakRef

	func _init(mf: MatchFlow) -> void:
		_mf = weakref(mf)

	func setup(_runner: TickRunner, _bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
		pass

	func server_tick(tick: int) -> void:
		var mf := _mf.get_ref() as MatchFlow
		if mf != null:
			mf._on_resolve(tick)


## Pure phase rule. Example: `MatchFlow.phase_at(300.0, false, 120.0, 420.0)` -> INVESTIGATION.
static func phase_at(elapsed_s_: float, terminal_armed: bool, infiltration_end_s: float,
		evac_start_s: float) -> Phase:
	if elapsed_s_ >= evac_start_s or terminal_armed:
		return Phase.EVACUATION
	if elapsed_s_ < infiltration_end_s:
		return Phase.INFILTRATION
	return Phase.INVESTIGATION


## Pure deadline rule: max(0, round_duration_s - elapsed_s).
static func time_remaining_at(elapsed_s_: float, round_duration_s: float) -> float:
	return maxf(0.0, round_duration_s - elapsed_s_)


## Injected by RoundServer. Reads knobs, publishes the clock view, listens for the terminal.
func setup(tick_runner: TickRunner, bus: EventBus, registry: StateRegistry, knobs: Knobs) -> void:
	_bus = bus
	_hz = knobs.net.sim_tick_hz
	_round_duration_s = knobs.match_flow.round_duration_s
	_infiltration_end_s = knobs.match_flow.infiltration_end_s
	_evac_start_s = _round_duration_s - knobs.match_flow.evacuation_window_s
	_elapsed_ticks = 0
	_phase = Phase.INFILTRATION
	_terminal_armed = false
	_ended = false
	_exit_open = false
	_lock_end_ticks = -1
	_window_ticks = knobs.ticks(knobs.match_flow.post_escape_window_s)
	_extracted = {}
	_status = {}
	_grace_start = {}
	_grace_ticks = knobs.ticks(knobs.match_flow.reconnect_grace_s)
	_forfeited = false
	_phase_events = []
	_life_event = {}
	_conn_event = {}
	_ended_event = null
	for id in survivor_ids:
		_status[id] = Status.HEALTHY
	registry.register_view(StateKeys.ROUND_CLOCK, &"MatchFlow", ClockView.new(self))
	bus.subscribe(&"ObjectiveProgressChanged", _on_objective_progress)
	# Named methods, not lambdas: the bus must not keep the module alive (no RefCounted cycle).
	bus.subscribe(&"SurvivorDowned", _on_downed)
	bus.subscribe(&"SurvivorRescued", _on_rescued)
	bus.subscribe(&"SurvivorEliminated", _on_eliminated)
	bus.subscribe(&"SurvivorEscaped", _on_escaped)
	bus.subscribe(&"PlayerConnectionChanged", _on_connection)


## Injects escape detection (rule 10): `exit` supplies the exit volume, `position_of.call(id) ->
## Vector3` the survivor positions (until Network Authority publishes
## StateKeys.PLAYER_POSITIONS_LIFE_STATES). Unset: nobody escapes by position. Call before setup.
func set_exit(exit: MapQueries, position_of: Callable) -> void:
	_exit = exit
	_position_of = position_of


## MATCH_FLOW_BEGIN slot: advances the clock one tick, re-evaluates the phase, then records every
## Healthy survivor in the exit volume after activation as Escaped (rule 10). It runs before the
## resolve check, so SurvivorEscaped is delivered to it in the same tick.
func server_tick(_tick: int) -> void:
	_elapsed_ticks += 1
	_update_phase()
	if _ended or not _exit_open or _exit == null or not _position_of.is_valid():
		return
	for id in survivor_ids:
		if _status.get(id, Status.ELIMINATED) == Status.HEALTHY and _exit.in_exit(_position_of.call(id)):
			_status[id] = Status.ESCAPED # at once: no second emit before the event is delivered
			var ev := EvSurvivorEscaped.new()
			ev.survivor = id
			_bus.emit(ev)


## Rule 3: the round enters Infiltration at `elapsed_s = 0` and broadcasts RoundPhaseChanged once.
## RoundLifecycle calls it when the loading barrier opens; clock-only rounds never call it.
func begin() -> void:
	var ev := EvRoundPhaseChanged.new()
	ev.phase = _phase
	_phase_events.append(ev)
	_bus.emit(ev)


## The module to register at TickOrder.MATCH_FLOW_RESOLVE.
func resolve_step() -> ResolveStep:
	return ResolveStep.new(self)


## Current phase.
func phase() -> Phase:
	return _phase


## Seconds elapsed, derived from the tick count.
func elapsed_s() -> float:
	return float(_elapsed_ticks) / float(_hz)


## Seconds to the deadline (0 once reached).
func time_remaining_s() -> float:
	return time_remaining_at(elapsed_s(), _round_duration_s)


## True once RoundEnded was emitted; no later check can emit another (rule 14).
func is_ended() -> bool:
	return _ended


## True once both drives are Extracted: the outcome is a survivor win whatever follows (rule 14).
func is_locked() -> bool:
	return _lock_end_ticks >= 0


## Last known status of survivor `id`; ELIMINATED for an id not on the roster.
func status_of(id: int) -> Status:
	return _status.get(id, Status.ELIMINATED)


## True while player `id` is in reconnect grace (dropped, not yet back or expired).
func in_grace(id: int) -> bool:
	return _grace_start.has(id)


## The round state a reconnecting client needs from Match Flow (ADR-0004 §9, TR-matchflow-006), as the
## events that set it, each with its original tick: every phase change (the Infiltration one fixes the
## client's clock start, MatchDisplay), each survivor's latest Downed / Rescued / Eliminated / Escaped,
## each player still in or past grace, and RoundEnded. Empty before begin(). Replayed, never re-emitted:
## no server subscriber sees them twice. Life states beyond the roster (bleed-out timers, objective
## progress) are their owners' to resync.
func catch_up() -> Array[ServerEvent]:
	var out: Array[ServerEvent] = _phase_events.duplicate()
	out.append_array(_life_event.values())
	out.append_array(_conn_event.values())
	if _ended_event != null:
		out.append(_ended_event)
	return out


## MATCH_FLOW_RESOLVE slot, after every gameplay event of the tick was delivered: the rule 16 win
## check, first match wins, once per tick. Evidence escaped locks the outcome; after the lock only
## rule 15 runs: the round ends when nobody is inside, at the deadline or when the window closes.
func _on_resolve(tick: int) -> void:
	if _ended:
		return
	_expire_grace(tick)
	if not is_locked() and _extracted.size() >= SurvivorObjectives.ACTIVE_DRIVES:
		_lock_end_ticks = _elapsed_ticks + _window_ticks
	var inside := 0
	var out := 0 # Eliminated or Disconnected
	for s: Status in _status.values():
		if s == Status.HEALTHY or s == Status.DOWNED:
			inside += 1
		elif s != Status.ESCAPED:
			out += 1
	if is_locked():
		if inside == 0 or time_remaining_s() <= 0.0 or _elapsed_ticks >= _lock_end_ticks:
			_end(Outcome.SURVIVORS_WIN, Reason.EVIDENCE_ESCAPED)
	elif not _status.is_empty() and out == _status.size():
		_end(Outcome.SHAPESHIFTER_WINS, Reason.ALL_ELIMINATED)
	elif not _status.is_empty() and inside == 0:
		_end(Outcome.SHAPESHIFTER_WINS, Reason.EVIDENCE_LOST)
	elif time_remaining_s() <= 0.0:
		_end(Outcome.SHAPESHIFTER_WINS, Reason.DEADLINE)
	elif _forfeit_due():
		_end(Outcome.SURVIVORS_WIN, Reason.FORFEIT)


## Rule 19: grace ends `reconnect_grace_s` after the drop, the tick ConnectionRouter.in_grace turns
## false, so a rejoin it admitted was delivered (BEGIN flush) before this RESOLVE check. The status is set
## here, not on delivery, so this tick's win check counts the survivor out (rule 16).
func _expire_grace(tick: int) -> void:
	for id: int in _grace_start.keys():
		if tick - _grace_start[id] < _grace_ticks:
			continue
		_grace_start.erase(id)
		_mark_disconnected(id)
		if id == shapeshifter_id:
			_forfeited = true
		var e := EvPlayerConnectionChanged.new()
		e.player = id
		e.status = EvPlayerConnectionChanged.GRACE_EXPIRED
		_bus.emit(e)


## Forfeit hook (rule 20): true once the shapeshifter's reconnect grace expired (story 006).
func _forfeit_due() -> bool:
	return _forfeited


## Survivors still inside become DID_NOT_ESCAPE (rules 15, 24).
func _end(outcome: Outcome, reason: Reason) -> void:
	_ended = true
	for id: int in _status:
		if _status[id] == Status.HEALTHY or _status[id] == Status.DOWNED:
			_status[id] = Status.DID_NOT_ESCAPE
	var ev := EvRoundEnded.new()
	ev.outcome = outcome
	ev.reason = reason # results payload: story 008
	_ended_event = ev
	_bus.emit(ev)


func _set_status(id: int, s: Status, e: ServerEvent) -> void:
	if _status.has(id):
		_status[id] = s
		_life_event[id] = e


func _on_downed(e: ServerEvent) -> void:
	_set_status((e as EvSurvivorDowned).survivor, Status.DOWNED, e)


func _on_rescued(e: ServerEvent) -> void:
	_set_status((e as EvSurvivorRescued).survivor, Status.HEALTHY, e)


func _on_eliminated(e: ServerEvent) -> void:
	_set_status((e as EvSurvivorEliminated).survivor, Status.ELIMINATED, e)


func _on_escaped(e: ServerEvent) -> void:
	_set_status((e as EvSurvivorEscaped).survivor, Status.ESCAPED, e)


## Disconnect and reconnect change no status: in grace a survivor counts as inside in their last state
## (rule 13); they only start and stop the grace timer. Only grace expiry takes a still-inside survivor
## out (rule 19). A RECONNECTED after expiry finds no timer and changes nothing.
func _on_connection(e: ServerEvent) -> void:
	var c := e as EvPlayerConnectionChanged
	match c.status:
		EvPlayerConnectionChanged.DISCONNECTED:
			_grace_start[c.player] = c.tick
			_conn_event[c.player] = c
		EvPlayerConnectionChanged.RECONNECTED:
			if _grace_start.erase(c.player): # a late notice after expiry keeps GRACE_EXPIRED
				_conn_event.erase(c.player)
		EvPlayerConnectionChanged.GRACE_EXPIRED:
			_mark_disconnected(c.player)
			_conn_event[c.player] = c


## A still-inside survivor whose grace expired is Disconnected; Escaped or Eliminated keep theirs.
func _mark_disconnected(id: int) -> void:
	var s: Status = _status.get(id, Status.ESCAPED)
	if s == Status.HEALTHY or s == Status.DOWNED:
		_status[id] = Status.DISCONNECTED


func _on_objective_progress(e: ServerEvent) -> void:
	var p := e as EvObjectiveProgressChanged
	if p.objective >= SurvivorObjectives.DRIVE_ID and p.objective < SurvivorObjectives.FUSE_ID \
			and p.state == SurvivorObjectives.DriveState.EXTRACTED:
		_extracted[p.objective] = true
	if p.objective == SurvivorObjectives.TERMINAL_ID and p.state == SurvivorObjectives.TerminalState.ACTIVATED:
		_exit_open = true
	# The terminal's own id: a drive's CARRIED (also state 1) must not arm it.
	if p.objective == SurvivorObjectives.TERMINAL_ID and p.state == SurvivorObjectives.TerminalState.ARMED:
		_terminal_armed = true # latched: nothing disarms (rule 6, phase never moves backwards)
		_update_phase()


func _update_phase() -> void:
	var next := phase_at(elapsed_s(), _terminal_armed, _infiltration_end_s, _evac_start_s)
	if next <= _phase:
		return
	_phase = next
	var ev := EvRoundPhaseChanged.new()
	ev.phase = _phase
	_phase_events.append(ev)
	_bus.emit(ev)
