class_name MonsterScares extends RefCounted
## Monster-source player-triggered scares, story scare-events/004 (design/gdd/scare-events.md rules 2, 4, 4a,
## 5; ADR-0005). A presentation layer over cues their own systems own: BarricadeBroken fires door_burst at the
## door, FormChanged into true form fires transformation_reveal at the monster, a Blackout AbilityUsed fires
## blackout at its target point. False Signal has no catalogue entry and fires nothing (rule 4a). Changes no
## state of its own beyond ScareEvents' gating records; never writes lighting (ADR-0009 §7).
## Usage (composer modules dict):
##   TickOrder.SCARE_EVENTS - 2: MonsterScares.new(scares, catalogue, map, monster, _live_players, _position)

const BURST := &"door_burst"
const REVEAL := &"transformation_reveal"
const BLACKOUT := &"blackout"

var _scares: ScareEvents
var _catalogue: ScareCatalogue
var _map: MapData
var _monster: int
var _live: Callable
var _position: Callable


## `live_players() -> Array[int]` players with a body in the world; `position_of(player) -> Vector3` feet.
func _init(scares: ScareEvents, catalogue: ScareCatalogue, map: MapData, monster: int, live_players: Callable,
		position_of: Callable) -> void:
	_scares = scares
	_catalogue = catalogue
	_map = map
	_monster = monster
	_live = live_players
	_position = position_of


## RoundServer entry.
func setup(_tick_runner: Node, bus: EventBus, _registry: StateRegistry, _knobs: Knobs) -> void:
	bus.subscribe(&"BarricadeBroken", _on_barricade_broken)
	bus.subscribe(&"FormChanged", _on_form_changed)
	bus.subscribe(&"AbilityUsed", _on_ability)


## Event-driven only; the step exists so the module sits in the Scare slot (after Pings).
func server_tick(_tick: int) -> void:
	pass


## Rule 19 recipients: every live player within the entry's audible_range_m of `origin`, the acting monster
## excluded. Inference: the actor is not "relevant" to a scare dressing up its own action (a Major would also
## flinch the monster toward its own door); the GDD does not say, a designer ruling settles it.
## ponytail: distance only; swap for scare-events story 003's shared relevance helper (adds line of sight).
func recipients(scare_id: StringName, origin: Vector3) -> Array[int]:
	var range_m := _catalogue.entry(scare_id).audible_range_m
	var out: Array[int] = []
	for id: int in _live.call():
		if id != _monster and (_position.call(id) as Vector3).distance_to(origin) <= range_m:
			out.append(id)
	return out


func _fire(scare_id: StringName, origin: Vector3) -> void:
	var to := recipients(scare_id, origin)
	if not to.is_empty():
		_scares.fire(scare_id, origin, to, ScareEntry.Source.MONSTER, _monster)


## A barricade's net id is its door's map interactable index (Doors registers first, RoundComposer).
func _on_barricade_broken(e: ServerEvent) -> void:
	var items := _map.interactables()
	var i := (e as EvBarricadeBroken).barricade
	var door := items[i] as MapPassage if i >= 0 and i < items.size() else null
	if door != null:
		_fire(BURST, door.position)


func _on_form_changed(e: ServerEvent) -> void:
	var f := e as EvFormChanged
	if f.form == BorrowedFace.TRUE_FORM and f.previous != BorrowedFace.TRUE_FORM:
		_fire(REVEAL, _position.call(f.player))


func _on_ability(e: ServerEvent) -> void:
	var a := e as EvAbilityUsed
	if a.ability == MonsterAbilities.Ability.BLACKOUT:
		_fire(BLACKOUT, a.target)
