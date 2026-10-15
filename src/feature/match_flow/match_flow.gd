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

enum Phase { INFILTRATION, INVESTIGATION, EVACUATION }
## `RoundEnded.outcome` values; text in OUTCOME_TEXT (rule 23).
enum Outcome { SURVIVORS_WIN, SHAPESHIFTER_WINS }
## `RoundEnded.reason` values, in rule 16 check order; text in REASON_TEXT (rule 23).
enum Reason { EVIDENCE_ESCAPED, ALL_ELIMINATED, EVIDENCE_LOST, DEADLINE, FORFEIT }
## Per-survivor status for win evaluation, from events only. HEALTHY and DOWNED count as inside, also
## while in reconnect grace (rule 13); DISCONNECTED is grace expired and counts as eliminated (rule 19).
enum Status { HEALTHY, DOWNED, ESCAPED, ELIMINATED, DISCONNECTED }

const OUTCOME_TEXT: Array[String] = ["Survivors Win", "Shapeshifter Wins"]
const REASON_TEXT: Array[String] = ["Evidence escaped", "All survivors eliminated", "Evidence lost",
	"Evacuation deadline expired", "Shapeshifter forfeited"]

## Player IDs of this round's survivors; set before start_round (read in setup). Empty disables the
## all-eliminated and evidence-lost checks (no roster, e.g. clock-only tests).
var survivor_ids: Array[int] = []


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
	_extracted = {}
	_status = {}
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


## MATCH_FLOW_BEGIN slot: advances the clock one tick and re-evaluates the phase.
func server_tick(_tick: int) -> void:
	_elapsed_ticks += 1
	_update_phase()


## Rule 3: the round enters Infiltration at `elapsed_s = 0` and broadcasts RoundPhaseChanged once.
## RoundLifecycle calls it when the loading barrier opens; clock-only rounds never call it.
func begin() -> void:
	var ev := EvRoundPhaseChanged.new()
	ev.phase = _phase
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


## Last known status of survivor `id`; ELIMINATED for an id not on the roster.
func status_of(id: int) -> Status:
	return _status.get(id, Status.ELIMINATED)


## MATCH_FLOW_RESOLVE slot, after every gameplay event of the tick was delivered: the rule 16 win
## check, first match wins, once per tick. Evidence escaped ends the round at once here; the
## post-escape window (rule 15) is story 003.
func _on_resolve(_tick: int) -> void:
	if _ended:
		return
	var inside := 0
	var out := 0 # Eliminated or Disconnected
	for s: Status in _status.values():
		if s == Status.HEALTHY or s == Status.DOWNED:
			inside += 1
		elif s != Status.ESCAPED:
			out += 1
	if _extracted.size() >= SurvivorObjectives.ACTIVE_DRIVES:
		_end(Outcome.SURVIVORS_WIN, Reason.EVIDENCE_ESCAPED)
	elif not _status.is_empty() and out == _status.size():
		_end(Outcome.SHAPESHIFTER_WINS, Reason.ALL_ELIMINATED)
	elif not _status.is_empty() and inside == 0:
		_end(Outcome.SHAPESHIFTER_WINS, Reason.EVIDENCE_LOST)
	elif time_remaining_s() <= 0.0:
		_end(Outcome.SHAPESHIFTER_WINS, Reason.DEADLINE)
	elif _forfeit_due():
		_end(Outcome.SURVIVORS_WIN, Reason.FORFEIT)


## Forfeit hook (rule 20): true once the shapeshifter's reconnect grace expired. Story 006 supplies
## the input; until then nothing forfeits.
func _forfeit_due() -> bool:
	return false


func _end(outcome: Outcome, reason: Reason) -> void:
	_ended = true
	var ev := EvRoundEnded.new()
	ev.outcome = outcome
	ev.reason = reason # results payload: story 008
	_bus.emit(ev)


func _set_status(id: int, s: Status) -> void:
	if _status.has(id):
		_status[id] = s


func _on_downed(e: ServerEvent) -> void:
	_set_status((e as EvSurvivorDowned).survivor, Status.DOWNED)


func _on_rescued(e: ServerEvent) -> void:
	_set_status((e as EvSurvivorRescued).survivor, Status.HEALTHY)


func _on_eliminated(e: ServerEvent) -> void:
	_set_status((e as EvSurvivorEliminated).survivor, Status.ELIMINATED)


func _on_escaped(e: ServerEvent) -> void:
	_set_status((e as EvSurvivorEscaped).survivor, Status.ESCAPED)


## Disconnect and reconnect change nothing: in grace a survivor counts as inside in their last state
## (rule 13). Only grace expiry takes a still-inside survivor out (rule 19).
func _on_connection(e: ServerEvent) -> void:
	var c := e as EvPlayerConnectionChanged
	var s: Status = _status.get(c.player, Status.ESCAPED)
	if c.status == EvPlayerConnectionChanged.GRACE_EXPIRED and (s == Status.HEALTHY or s == Status.DOWNED):
		_status[c.player] = Status.DISCONNECTED


func _on_objective_progress(e: ServerEvent) -> void:
	var p := e as EvObjectiveProgressChanged
	if p.objective >= SurvivorObjectives.DRIVE_ID and p.objective < SurvivorObjectives.FUSE_ID \
			and p.state == SurvivorObjectives.DriveState.EXTRACTED:
		_extracted[p.objective] = true
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
	_bus.emit(ev)
