class_name ScareEvents extends RefCounted
## Server Scare Events module, story scare-events/001 (design/gdd/scare-events.md rules 1-3, 8; ADR-0005).
## The only emitter of ScareTriggered (rule 3): there is no timer here, a scare fires only when an owning
## system calls fire(). Each recipient is gated by ScareGating (story 002); recipient selection (story 003) is
## not here yet: fire() gates exactly the recipients it is given.
## Usage:
##   var scares := ScareEvents.new(ScareCatalogue.load_shipped())
##   server.start_round({TickOrder.SCARE_EVENTS: scares}, knobs)
##   scares.fire(&"door_burst", origin, [peer_a, peer_b], ScareEntry.Source.MONSTER, monster_player)

var _catalogue: ScareCatalogue
var _bus: EventBus
var _registry: StateRegistry
var _gating: ScareGating


func _init(catalogue: ScareCatalogue) -> void:
	_catalogue = catalogue


## RoundServer entry.
func setup(_tick_runner: Node, bus: EventBus, registry: StateRegistry, knobs: Knobs) -> void:
	_bus = bus
	_registry = registry
	_gating = ScareGating.new(knobs.scare) # fresh records every round (story 002)


## Nothing runs on a timer (rule 3); the step exists so the module sits at the Scare slot.
func server_tick(_tick: int) -> void:
	pass


## Emits one ScareTriggered per recipient for catalogue entry `scare_id` at `origin`. `source` must equal the
## entry's source; Monster and Survivor sources must name `player` (the acting player id, server-only: the
## projection strips it). A SINGLE_CLIENT scare needs exactly one recipient (rule 20). Returns false (and
## push_errors) when refused, emitting nothing.
func fire(scare_id: StringName, origin: Vector3, recipients: Array, source: int, player: int = -1) -> bool:
	var entry := _catalogue.entry(scare_id)
	if entry == null:
		return _refuse("unknown scare_id %s" % scare_id)
	if source != entry.source:
		return _refuse("%s fired with source %d, catalogue says %d" % [scare_id, source, entry.source])
	if source != ScareEntry.Source.ROUND_SCRIPT and player < 0:
		return _refuse("%s: a Monster or Survivor source must name a player" % scare_id)
	if recipients.is_empty() or (entry.scope == ScareEntry.Scope.SINGLE_CLIENT and recipients.size() != 1):
		return _refuse("%s: bad recipient count %d for scope %d" % [scare_id, recipients.size(), entry.scope])
	# Story 002 gating at Match Flow's round time; MatchFlow.Phase (Infiltration/Investigation/Evacuation)
	# indexes the same Low/Rising/Emergency budgets as ScareEntry.Phase. No clock (module-only tests): t=0, Low.
	var clock: MatchFlow.ClockView = null
	if _registry != null and _registry.has_view(StateKeys.ROUND_CLOCK):
		clock = _registry.view(StateKeys.ROUND_CLOCK, MatchFlow.ClockView) as MatchFlow.ClockView
	var now_s := clock.elapsed_s() if clock != null else 0.0
	var phase := clock.phase() if clock != null else ScareEntry.Phase.LOW
	for r: int in recipients:
		var intensity := _gating.gate(r, entry, origin, now_s, phase)
		if intensity == ScareGating.BLOCKED:
			continue
		var e := EvScareTriggered.new()
		e.scare_id = scare_id
		e.scope = entry.scope
		e.source = source
		e.player = player
		e.origin = origin
		e.intensity = intensity
		e.recipient = r
		_bus.emit(e)
	return true


func _refuse(why: String) -> bool:
	push_error("ScareEvents: %s" % why)
	return false
