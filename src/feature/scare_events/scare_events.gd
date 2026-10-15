class_name ScareEvents extends RefCounted
## Server Scare Events module, story scare-events/001 (design/gdd/scare-events.md rules 1-3, 8; ADR-0005).
## The only emitter of ScareTriggered (rule 3): there is no timer here, a scare fires only when an owning
## system calls fire(). Gating (story 002) and recipient selection (story 003) are not here yet: fire()
## sends exactly to the recipients it is given.
## Usage:
##   var scares := ScareEvents.new(ScareCatalogue.load_shipped())
##   server.start_round({TickOrder.SCARE_EVENTS: scares}, knobs)
##   scares.fire(&"door_burst", origin, [peer_a, peer_b], ScareEntry.Source.MONSTER, monster_player)

var _catalogue: ScareCatalogue
var _bus: EventBus


func _init(catalogue: ScareCatalogue) -> void:
	_catalogue = catalogue


## RoundServer entry.
func setup(_tick_runner: Node, bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
	_bus = bus


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
	for r: int in recipients:
		var e := EvScareTriggered.new()
		e.scare_id = scare_id
		e.scope = entry.scope
		e.source = source
		e.player = player
		e.origin = origin
		e.intensity = entry.intensity
		e.recipient = r
		_bus.emit(e)
	return true


func _refuse(why: String) -> bool:
	push_error("ScareEvents: %s" % why)
	return false
