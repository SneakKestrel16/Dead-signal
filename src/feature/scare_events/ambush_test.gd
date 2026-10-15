class_name AmbushTest extends RefCounted
## The ambush test (story scare-events/005; design/gdd/scare-events.md rule 5a, Formulas). Server only.
## Every tick (feature phase, inside TickRunner's physics step) it records, per survivor, the last tick that
## survivor had line of sight to the monster's chest: the shared SightTest from the survivor's chest, facing
## ignored (no cone, no range), the same chest-to-chest test as Monster Abilities rule 7. At a Lunge
## wind-up (AbilityUsed) each survivor within lunge_cue_radius_m passes when the monster stands in a
## blacked-out lighting volume or the survivor has not seen it for ambush_unseen_s; the ambush lunge scare
## goes to the passing survivors only (one ScareEvents.fire).
## A survivor who never saw the monster this round counts as unseen for ever (inference: the GDD does not say
## whether round start resets the clock; a designer call on early-round lunges would settle it).
## Inference: the radius is measured chest to chest; both chests sit at the same capsule height, so it equals
## the feet distance the Controller's wind-up gate uses.
## Usage:
##   var ambush := AmbushTest.new(scares)
##   ambush.set_sources(monster, survivors, body_points_of, clear_sight, queries.volume_at)
##   server.start_round({TickOrder.SCARE_EVENTS - 1: ambush, TickOrder.SCARE_EVENTS: scares}, knobs)

## Index of the chest in body_points_of ([head, chest, pelvis]).
const CHEST := 1
const SCARE_ID := &"ambush_lunge"

var _scares: ScareEvents
var _bus: EventBus
var _registry: StateRegistry
var _radius_m: float
var _unseen_ticks: int
var _monster := -1
var _survivors: Array[int] = []
var _points: Callable
var _clear: Callable
var _volume_at: Callable
## survivor -> last tick it saw the monster's chest (absent = never).
var _last_seen: Dictionary[int, int] = {}


func _init(scares: ScareEvents) -> void:
	_scares = scares


## `points(player) -> PackedVector3Array` [head, chest, pelvis], empty for no body in the world;
## `line_clear(from, to) -> bool` MapQueries.clear_sight (closed doors block); `volume_at(point) -> StringName`
## MapQueries.volume_at.
func set_sources(monster: int, survivors: Array[int], points: Callable, line_clear: Callable,
		volume_at: Callable) -> void:
	_monster = monster
	_survivors = survivors.duplicate()
	_points = points
	_clear = line_clear
	_volume_at = volume_at


## RoundServer entry.
func setup(_tick_runner: Node, bus: EventBus, registry: StateRegistry, knobs: Knobs) -> void:
	_bus = bus
	_registry = registry
	_radius_m = knobs.ability.lunge_cue_radius_m
	_unseen_ticks = knobs.ticks(knobs.scare.ambush_unseen_s)
	_last_seen = {}
	bus.subscribe(&"AbilityUsed", _on_ability)


## Updates every survivor's last-seen tick.
func server_tick(tick: int) -> void:
	for s in _survivors:
		if _sees(s):
			_last_seen[s] = tick


## True when `survivor` passes the ambush test now (rule 5a). `dark`: the monster's volume is blacked out.
func passes(survivor: int, dark: bool) -> bool:
	if _sees(survivor):
		_last_seen[survivor] = _bus.tick
	return dark or _bus.tick - _last_seen.get(survivor, _bus.tick - _unseen_ticks) >= _unseen_ticks


func _on_ability(e: ServerEvent) -> void:
	var a := e as EvAbilityUsed
	if a.ability != MonsterAbilities.Ability.LUNGE:
		return
	var m := _points.call(_monster) as PackedVector3Array
	if m.is_empty():
		return
	var lighting := _registry.view(StateKeys.LIGHTING_STATE, LightingView) as LightingView if _registry else null
	var dark := lighting != null and lighting.is_dark(_volume_at.call(a.position))
	var out: Array[int] = []
	for s in _survivors:
		var p := _points.call(s) as PackedVector3Array
		if not p.is_empty() and p[CHEST].distance_to(m[CHEST]) <= _radius_m and passes(s, dark):
			out.append(s)
	if not out.is_empty():
		_scares.fire(SCARE_ID, a.position, out, ScareEntry.Source.MONSTER, _monster)


func _sees(survivor: int) -> bool:
	var m := _points.call(_monster) as PackedVector3Array
	var p := _points.call(survivor) as PackedVector3Array
	if m.is_empty() or p.is_empty():
		return false
	return SightTest.sees(p[CHEST], 0.0, PackedVector3Array([m[CHEST]]), 360.0, INF, _clear)
