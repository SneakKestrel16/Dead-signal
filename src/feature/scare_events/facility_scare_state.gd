class_name FacilityScareState extends RefCounted
## Server facility scare state, story scare-events/006 (design/gdd/scare-events.md rule 22, States and
## Transitions; ADR-0009 §7). Reacts to the same RoundPhaseChanged / ObjectiveProgressChanged / RoundEnded
## the Facility Map reacts to and requests nothing from it: it never writes lighting. Low at round start,
## Rising on Investigation, Emergency on Evacuation (also straight from Low when the terminal is armed
## early), Results on round end; Power Restored is an overlay flag set when the terminal reports POWERED.
## Blackout is not here: it is a per-volume lighting overlay the map owns and already replicates.
## Replication: a ServerMovement batch_extras provider sends [EventBatch.FACILITY_SCARE, {state, power}] to
## every viewer on change, and the full record on a rejoin (`full`, story match-flow/012). Missed scares are
## never replayed: nothing here is a catch_up event.
## Usage:
##   var fss := FacilityScareState.new()
##   server.start_round({TickOrder.SCARE_EVENTS + 1: fss, ...}, knobs)
##   sm.batch_extras.append(fss.entries)

## LOW, RISING, EMERGENCY share their values with ScareEntry.Phase (the RoundScript list a state draws from).
enum State { LOW, RISING, EMERGENCY, RESULTS }

var _state: State = State.LOW
var _power := false
## viewer -> [state, power] last sent.
var _sent: Dictionary[int, Array] = {}


## RoundServer entry.
func setup(_tick_runner: Node, bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
	bus.subscribe(&"RoundPhaseChanged", _on_phase)
	bus.subscribe(&"ObjectiveProgressChanged", _on_objective)
	bus.subscribe(&"RoundEnded", _on_ended)


## Event-driven; the step exists so the module sits in the Scare slot.
func server_tick(_tick: int) -> void:
	pass


## The current facility scare state.
func state() -> State:
	return _state


## True once both fuses restored power (Power Restored overlay); it stays for the round.
func power_restored() -> bool:
	return _power


## ServerMovement batch provider: the record for `viewer` when it changed since the last send to it, or
## always when `full` (a rejoin).
func entries(viewer: int, full: bool = false) -> Array:
	var rec := [_state, _power]
	if not full and _sent.get(viewer) == rec:
		return []
	_sent[viewer] = rec
	return [[EventBatch.FACILITY_SCARE, {"state": _state, "power": _power}]]


func _on_phase(e: ServerEvent) -> void:
	if _state == State.RESULTS:
		return
	match (e as EvRoundPhaseChanged).phase:
		MatchFlow.Phase.INFILTRATION:
			_state = State.LOW
		MatchFlow.Phase.INVESTIGATION:
			_state = State.RISING
		MatchFlow.Phase.EVACUATION:
			_state = State.EMERGENCY


func _on_objective(e: ServerEvent) -> void:
	var o := e as EvObjectiveProgressChanged
	if o.objective == SurvivorObjectives.TERMINAL_ID and o.state == SurvivorObjectives.TerminalState.POWERED:
		_power = true


func _on_ended(_e: ServerEvent) -> void:
	_state = State.RESULTS
