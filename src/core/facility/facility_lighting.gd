class_name FacilityLighting extends RefCounted
## Per-volume lighting state, server side (facility-map story 009; research-facility.md Lighting States,
## Precedence, Edge Cases; ADR-0009 §1-4; systems-index rows "Lighting state per volume" and
## "`blackout_able` per lighting volume", owner Facility Map). Holds one facility base state (Low Power ->
## Power Restored -> Evacuation, forward only), and per map volume an overlay bitmask, a Blackout end tick
## and `blackout_able`. Handlers run at flush (ADR-0005 §3); server_tick only expires Blackouts. A client
## resolves the look (base, then overlays on their own fixtures, then dark) from presets: story 010, as is
## the replication record. Not here: the backup switch Interactable (ADR-0009 §2; its on_complete calls
## end_blackout) and Blackout target validation (Monster Abilities, through LightingView).
## Usage:
##   var lighting := FacilityLighting.new(map, objective_volume)
##   server.start_round({TickOrder.FACILITY_LIGHTING: lighting}, knobs)

enum Base { LOW_POWER, POWER_RESTORED, EVACUATION }

const OVERLAY_FUSE_INSTALLED := 1
const OVERLAY_TERMINAL_ACTIVATING := 2
const OVERLAY_EXIT_OPEN := 4

## Feature-layer values this Core module reads from event payloads, mirrored so Core never names a
## Feature class; lighting_state_test pins each to its source.
## MatchFlow.Phase.EVACUATION.
const PHASE_EVACUATION := 2
## MonsterAbilities.Ability.BLACKOUT.
const ABILITY_BLACKOUT := 2
## SurvivorObjectives objective id bases: fuse boxes FUSE_BOX_ID + index, the terminal TERMINAL_ID.
const FUSE_BOX_ID := 20
const TERMINAL_ID := 30
## SurvivorObjectives.FuseState.INSTALLED.
const FUSE_INSTALLED := 3
## SurvivorObjectives.TerminalState ACTIVATING, ACTIVATED, POWERED.
const TERMINAL_ACTIVATING := 2
const TERMINAL_ACTIVATED := 3
const TERMINAL_POWERED := 4

var _map: MapData
var _queries: MapQueries
var _objective_volume: Callable
var _bus: EventBus
var _duration_ticks: int
var _exit_volume: StringName = &""
var _base: Base = Base.LOW_POWER
## Volume id -> overlay bitmask / Blackout end tick (0 = none) / blackout_able.
var _overlays: Dictionary[StringName, int] = {}
var _dark_until: Dictionary[StringName, int] = {}
var _able: Dictionary[StringName, bool] = {}


## `objective_volume(objective: int) -> StringName`: the map volume holding an active objective point
## (a fuse box, FUSE_BOX_ID + index, or the terminal, TERMINAL_ID), &"" when unknown. Supplied by the
## round composer from Survivor Objectives' active points; invalid = no fixture overlays and no
## terminal-room rule.
func _init(map: MapData, objective_volume: Callable = Callable()) -> void:
	_map = map
	_queries = MapQueries.new(map)
	_objective_volume = objective_volume
	# The exit passage's inside room (C4 for E). Its zone box lies outside every volume. Inference: the
	# room is one lighting volume with the room's id (true of every room in the shipped map).
	for p in map.passages:
		if p.kind == MapPassage.EXIT:
			_exit_volume = p.a


## RoundServer entry: Reset (round start), subscriptions and the one view under both registry keys.
func setup(_tick_runner: Node, bus: EventBus, registry: StateRegistry, knobs: Knobs) -> void:
	_bus = bus
	_duration_ticks = knobs.ticks(knobs.ability.blackout_duration_s)
	_reset()
	bus.subscribe(&"RoundPhaseChanged", _on_phase_changed)
	bus.subscribe(&"ObjectiveProgressChanged", _on_objective_changed)
	bus.subscribe(&"AbilityUsed", _on_ability_used)
	bus.subscribe(&"RoundEnded", _on_round_ended)
	var view := LightingView.new(self)
	registry.register_view(StateKeys.LIGHTING_STATE, &"FacilityMap", view)
	registry.register_view(StateKeys.BLACKOUT_ABLE, &"FacilityMap", view)


## Expires every Blackout whose end tick has come. A Blackout set this tick (flush after Monster
## Abilities) ends at least one Blackout duration later.
func server_tick(tick: int) -> void:
	for v in _dark_until:
		if _dark_until[v] != 0 and tick >= _dark_until[v]:
			_dark_until[v] = 0


## The facility base state.
func base() -> Base:
	return _base


## Overlay bitmask of `volume`; 0 for an unknown id.
func overlays(volume: StringName) -> int:
	return _overlays.get(volume, 0)


## True while a Blackout darkens `volume`.
func is_dark(volume: StringName) -> bool:
	return _dark_until.get(volume, 0) != 0


## True when `volume` may be blacked out; false for an unknown id.
func blackout_able(volume: StringName) -> bool:
	return _able.get(volume, false)


## Ends any Blackout in `volume` now (Evacuation in the terminal room; the backup switch, ADR-0009 §2).
func end_blackout(volume: StringName) -> void:
	if _dark_until.has(volume):
		_dark_until[volume] = 0


func _reset() -> void:
	_base = Base.LOW_POWER
	for v in _map.volumes:
		_overlays[v.id] = 0
		_dark_until[v.id] = 0
		_able[v.id] = true


func _volume_of(objective: int) -> StringName:
	return _objective_volume.call(objective) if _objective_volume.is_valid() else &""


func _add_overlay(volume: StringName, bit: int) -> void:
	if _overlays.has(volume):
		_overlays[volume] |= bit


## Evacuation is the last base; the active terminal room stops being blackout_able and its Blackout
## ends at once (research-facility.md `blackout_able` paragraph). Any other Blackout runs out.
func _on_phase_changed(e: ServerEvent) -> void:
	if (e as EvRoundPhaseChanged).phase != PHASE_EVACUATION:
		return
	_base = Base.EVACUATION
	var terminal := _volume_of(TERMINAL_ID)
	if _able.has(terminal):
		_able[terminal] = false
		end_blackout(terminal)


## Precedence: the base only moves forward, so a POWERED after Evacuation changes nothing. The
## shapeshifter-only install alert (INSTALLING) carries no box and is ignored.
func _on_objective_changed(e: ServerEvent) -> void:
	var o := e as EvObjectiveProgressChanged
	if o.objective >= FUSE_BOX_ID and o.objective < TERMINAL_ID and o.state == FUSE_INSTALLED:
		_add_overlay(_volume_of(o.objective), OVERLAY_FUSE_INSTALLED)
	elif o.objective != TERMINAL_ID:
		return
	elif o.state == TERMINAL_POWERED:
		_base = maxi(_base, Base.POWER_RESTORED) as Base
	elif o.state == TERMINAL_ACTIVATING:
		_add_overlay(_volume_of(TERMINAL_ID), OVERLAY_TERMINAL_ACTIVATING)
	elif o.state == TERMINAL_ACTIVATED:
		_add_overlay(_exit_volume, OVERLAY_EXIT_OPEN)


## Blackout on the volume at the ability's target point. Monster Abilities validates first; a volume
## that is not blackout_able is still refused here, so the terminal-room rule holds on its own.
func _on_ability_used(e: ServerEvent) -> void:
	var a := e as EvAbilityUsed
	if a.ability != ABILITY_BLACKOUT:
		return
	var v := _queries.volume_at(a.target)
	if blackout_able(v):
		_dark_until[v] = _bus.tick + _duration_ticks


func _on_round_ended(_e: ServerEvent) -> void:
	_reset()
