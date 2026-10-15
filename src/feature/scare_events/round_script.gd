class_name RoundScript extends RefCounted
## Server RoundScript environment scares, story scare-events/006 (design/gdd/scare-events.md rules 2a, 6, 7;
## design/levels/research-facility.md Scare anchors). A RoundScript scare fires only at an authored scare
## anchor (map markers of type ANCHOR_TYPE, ids sd1-sd6 and sg1-sg3): when any player, monster included
## (rule 2a), enters the volume holding an anchor, every catalogue RoundScript entry naming that anchor whose
## phases hold the current facility scare state and whose zones hold the anchor's zone goes to
## ScareEvents.fire(), which applies gating (story 002). Nothing fires in Results. Presentation only: no
## door, light or other state is written (rule 7; ADR-0009 §7).
## Inference: "reaches an anchor" read as entering the anchor's lighting volume; the GDD gives no trigger
## radius. A trigger-radius knob in the Scare knobs would settle it.
## Recipients: the live players ScareRelevance finds relevant to the anchor (story 003); none, nothing fires.
## Usage:
##   var rs := RoundScript.new(scares, catalogue, fss, map, live_players, position_of, relevance)
##   server.start_round({TickOrder.SCARE_EVENTS + 2: rs, ...}, knobs)

## MapMarker.type of a scare anchor (MapData.MARKER_TYPES; the 9 anchors are in the shipped map file).
const ANCHOR_TYPE := &"scare_anchor"
## How far below a volume's floor a body still counts as in it, m (LightingReplication.BELOW_FLOOR_M):
## parked bodies wait 1000 m below the map and volume_at reads x and z only.
const BELOW_FLOOR_M := 1.0

var _scares: ScareEvents
var _state: FacilityScareState
var _queries: MapQueries
var _players: Callable
var _position: Callable
var _relevance: ScareRelevance
## volume id -> MapVolume.
var _volumes: Dictionary[StringName, MapVolume] = {}
## volume id -> [[anchor marker, ScareEntry], ...] for every RoundScript entry naming the anchor.
var _at: Dictionary[StringName, Array] = {}
## player -> volume it stood in last tick.
var _was: Dictionary[int, StringName] = {}


## `players() -> Array` of live player ids; `position(id) -> Vector3` their feet; `relevance` picks recipients.
func _init(scares: ScareEvents, catalogue: ScareCatalogue, state: FacilityScareState, map: MapData,
		players: Callable, position: Callable, relevance: ScareRelevance) -> void:
	_scares = scares
	_state = state
	_queries = MapQueries.new(map)
	_players = players
	_position = position
	_relevance = relevance
	for v in map.volumes:
		_volumes[v.id] = v
	for m in map.markers:
		if m.type != ANCHOR_TYPE:
			continue
		for e in catalogue.entries:
			if e.source == ScareEntry.Source.ROUND_SCRIPT and m.id in e.anchors:
				if not _at.has(m.volume):
					_at[m.volume] = []
				_at[m.volume].append([m, e])


## RoundServer entry.
func setup(_tick_runner: Node, _bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
	pass


## Fires the anchor scares of every volume a player entered this tick.
func server_tick(_tick: int) -> void:
	for id: int in _players.call():
		var v := _volume_of(id)
		if v == _was.get(id, &""):
			continue
		_was[id] = v
		# Results is no ScareEntry.Phase value (ScareEntry.errors), so no entry matches it.
		for pair: Array in _at.get(v, []):
			var m: MapMarker = pair[0]
			var e: ScareEntry = pair[1]
			if int(_state.state()) in e.phases and String(_volumes[v].zone) in e.zones:
				var to := _relevance.recipients(e, m.position, _players.call())
				if not to.is_empty():
					_scares.fire(e.scare_id, m.position, to, ScareEntry.Source.ROUND_SCRIPT)


func _volume_of(id: int) -> StringName:
	var at: Vector3 = _position.call(id)
	var v := _queries.volume_at(at)
	if v == &"" or at.y < _volumes[v].box.position.y - BELOW_FLOOR_M:
		return &""
	return v
