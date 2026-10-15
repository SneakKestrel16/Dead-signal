class_name MatchFlow extends RefCounted
## Match Flow round clock and phase machine (Feature layer). Implements design/gdd/match-flow.md
## rules 4-7, Formulas "Phase from elapsed time"; story match-flow/001; ADR-0005.
## Server only. Time comes from counted ticks (`net.sim_tick_hz`), never wall time. The phase only
## moves forward and each move emits exactly one RoundPhaseChanged.
## Usage:
##   var mf := MatchFlow.new()
##   server.start_round({TickOrder.MATCH_FLOW_BEGIN: mf, TickOrder.MATCH_FLOW_RESOLVE: mf.resolve_step()}, knobs)
## Story 002 extends the RESOLVE slot by overriding `_on_resolve(tick)`; no win checks live here.

enum Phase { INFILTRATION, INVESTIGATION, EVACUATION }


var _bus: EventBus
var _hz: int = 0
var _infiltration_end_s: float = 0.0
var _evac_start_s: float = 0.0
var _round_duration_s: float = 0.0
var _elapsed_ticks: int = 0
var _phase: Phase = Phase.INFILTRATION
var _terminal_armed: bool = false


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
	registry.register_view(StateKeys.ROUND_CLOCK, &"MatchFlow", ClockView.new(self))
	bus.subscribe(&"ObjectiveProgressChanged", _on_objective_progress)


## MATCH_FLOW_BEGIN slot: advances the clock one tick and re-evaluates the phase.
func server_tick(_tick: int) -> void:
	_elapsed_ticks += 1
	_update_phase()


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


## Hook for story 002 (win evaluation). Default does nothing.
func _on_resolve(_tick: int) -> void:
	pass


func _on_objective_progress(e: ServerEvent) -> void:
	var p := e as EvObjectiveProgressChanged
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
