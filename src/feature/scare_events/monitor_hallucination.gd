class_name MonitorHallucination extends RefCounted
## Server trigger for the impossible surveillance frame, story scare-events/010 (design/gdd/scare-events.md
## rules 2, 2a, 12, 20, 21; ADR-0004 §5). When a live player starts viewing the C1 monitor (Surveillance goes
## from OFF to a camera; facility-map story 011) while the facility scare state is in the catalogue entry's
## `phases`, `surveillance_image` goes to ScareEvents.fire() with that player as its sole recipient, Survivor
## source, at the monitor's point; fire() applies the gating (cooldowns, repeat block at the monitor,
## hallucination_max_per_client). Any player counts, the shapeshifter in any form included (rule 2a). The
## origin is the monitor, never a body, and the event carries no camera content (rule 21).
## Inference: the GDD names no phases or frequency ("RoundScript selects", proposed). The shipped entry lists
## Rising and Emergency (not the Low opening), and every view start in them is offered to the gating, which
## bounds it to hallucination_max_per_client per round; a designer ruling on when RoundScript selects settles it.
## Usage:
##   TickOrder.SCARE_EVENTS + 3: MonitorHallucination.new(scares, catalogue, cams, scare_state.state, _live_players)

const IMAGE := &"surveillance_image"

var _scares: ScareEvents
var _cams: Surveillance
var _phase: Callable
var _players: Callable
var _phases: PackedInt32Array
## Players viewing a feed last tick.
var _was: Dictionary[int, bool] = {}


## `phase() -> int` the facility scare state (FacilityScareState.state); `players() -> Array` live player ids.
func _init(scares: ScareEvents, catalogue: ScareCatalogue, cams: Surveillance, phase: Callable,
		players: Callable) -> void:
	_scares = scares
	_cams = cams
	_phase = phase
	_players = players
	_phases = catalogue.entry(IMAGE).phases


## RoundServer entry.
func setup(_tick_runner: Node, _bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
	_was.clear()


## Offers the image to every player whose feed turned on since last tick.
func server_tick(_tick: int) -> void:
	var now: Dictionary[int, bool] = {}
	for id: int in _players.call():
		if _cams.viewed_camera(id) == Surveillance.OFF:
			continue
		now[id] = true
		if not _was.has(id) and int(_phase.call()) in _phases:
			_scares.fire(IMAGE, _cams.point, [id], ScareEntry.Source.SURVIVOR, id)
	_was = now
