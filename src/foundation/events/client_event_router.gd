class_name ClientEventRouter extends RefCounted
## Client side of the event catalog (ADR-0005 §7): takes the server's projected per-peer batches
## (EventBatch, ADR-0004 §5-6) and hands each payload, in batch order, to the presentation handlers
## subscribed to its type. Clients never construct or emit a ServerEvent; payloads stay Dictionaries.
## Only packets from the server peer count; other packet kinds (handles, snapshots) are ignored.
## Usage (client, on the fixed-name round root):
##   var router := ClientEventRouter.new(multiplayer as SceneMultiplayer)
##   router.subscribe(&"ScareTriggered", hud.on_scare)   # hud.on_scare(tick: int, payload: Dictionary)
##   router.subscribe(EventBatch.SOUND, audio.on_sound)
## Handlers share one payload Dictionary per entry and must not mutate it.

const SERVER_PEER := 1
## Every catalog type() (systems-index.md event table). Kept as names here because the client may not
## construct the ev_*.gd classes to ask them; client_event_router_test.gd checks it against those.
const CATALOG: Array[StringName] = [
	&"RoundPhaseChanged", &"RoundEnded", &"SurvivorEscaped", &"SurvivorHit", &"SurvivorDowned",
	&"SurvivorRescued", &"SurvivorEliminated", &"MonsterStunned", &"PlayerShocked", &"FormChanged",
	&"ObjectiveProgressChanged", &"ScareTriggered", &"FlinchRequested", &"ViewOffsetChanged",
	&"AbilityUsed", &"BarricadeBroken", &"PlayerConnectionChanged",
]

## Batch entry types that are not catalog events (EventBatch).
const NON_CATALOG: Array[StringName] = [EventBatch.SOUND, EventBatch.BLEED_RING, EventBatch.CHARGES,
	EventBatch.HIDING, EventBatch.BARRICADE, EventBatch.CAMERA, EventBatch.LIGHTING,
	EventBatch.PING, EventBatch.PING_REJECTED, EventBatch.FACILITY_SCARE, EventBatch.CALLOUT, EventBatch.CALLOUT_AUDIO]

## Event batches that failed to decode.
var rejected: int = 0
## Entries dropped for a type outside the catalog (each type is logged once).
var dropped: int = 0

var _smp: SceneMultiplayer
## type -> Array of Callable, in subscribe order.
var _handlers: Dictionary[StringName, Array] = {}
var _warned: Dictionary[StringName, bool] = {}


## `smp`: listen on its peer_packet; null = call on_packet() by hand (tests).
func _init(smp: SceneMultiplayer = null) -> void:
	_smp = smp
	if _smp != null:
		_smp.peer_packet.connect(on_packet)


## Stops listening. Safe to call twice.
func close() -> void:
	if _smp != null and _smp.peer_packet.is_connected(on_packet):
		_smp.peer_packet.disconnect(on_packet)


## Adds `handler(tick: int, payload: Dictionary)` (a named method) for entries of `type`, a catalog
## name or one of NON_CATALOG. Returns false, and adds nothing, for any other name.
func subscribe(type: StringName, handler: Callable) -> bool:
	if type not in NON_CATALOG and type not in CATALOG:
		return false
	if not _handlers.has(type):
		_handlers[type] = []
	_handlers[type].append(handler)
	return true


## peer_packet handler: routes the server's event batches; anything else is ignored.
func on_packet(peer_id: int, bytes: PackedByteArray) -> void:
	if peer_id != SERVER_PEER or not EventBatch.is_message(bytes):
		return
	var b := EventBatch.decode(bytes)
	if b.is_empty():
		rejected += 1
		return
	for entry: Array in b.entries:
		var type: StringName = entry[0]
		if type not in NON_CATALOG and type not in CATALOG:
			dropped += 1
			if not _warned.has(type):
				_warned[type] = true
				push_warning("ClientEventRouter: dropped entry of unknown type %s" % type)
			continue
		for h: Callable in _handlers.get(type, []):
			if h.is_valid():
				h.call(b.tick, entry[1])
