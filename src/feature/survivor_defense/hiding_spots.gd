class_name HidingSpots extends RefCounted
## Hiding spots: enter, exit, one occupant, monster search (design/gdd/survivor-defense.md rules 18-20,
## 22, 23, 28a, the "Hiding spot" state line and the hiding edge cases; story survivor-defense/006;
## ADR-0008 holds and locks; ADR-0004: occupancy is server state, published only as the hidden flag
## through SurvivorDefense's HIDDEN_ITEM_USE view). Server only.
## Each map hiding marker gets two HidingHolds on the shared HoldService: Hide (enter when empty, leave
## when you are the occupant; lock "hide_<n>", so one actor at a time) and Search (lock "search_<n>").
## Hidden state is SurvivorDefense's (set_hidden); every gate that reads it (taser fire and trace,
## Downing's lunge eligibility and rescue, Objectives) then refuses the hidden survivor, who keeps
## charges and flashlight (rule 23). While hidden the survivor is rooted (MOD_OWNER).
## A search completing while the spot is being entered is held until the entry completes, then ejects
## (edge case "Monster Searches the spot a survivor is entering"); an entry cancelled first spends it.
## A stun interrupts the search through SurvivorDefense.shock's holds.cancel (rule 15).
## Not here: hide noise and the long-hide cue (story 010), the peek view (011), catalog events (the
## catalog has no hide or search event), the Controller's flinch re-baseline (no hook exists yet).
## Usage:
##   var spots := HidingSpots.new(holds, map, healthy_survivor, is_monster, sd.set_hidden, movement.modifiers_of, place)
##   spots.setup(tick_runner, bus, registry, knobs)

## first-person-controller.md edge case "front is blocked": the farthest a blocked eject may move from the
## spot's front. A GDD rule, not a tuning value.
const EJECT_SEARCH_M := 1.0
## The MovementModifiers owner that roots a hidden survivor.
const MOD_OWNER := &"hiding"
## HoldService.cancel reason for an occupant's hold ended by an eject.
const CANCEL_EJECTED := &"ejected"

var _holds: HoldService
var _map: MapData
var _healthy: Callable
var _is_monster: Callable
var _set_hidden: Callable
var _modifiers_of: Callable
var _place: Callable
## Per spot: interaction point, eject point (null: no free point within EJECT_SEARCH_M, the exit waits),
## Hide and Search net ids.
var _points: Array[Vector3] = []
var _exits: Array = []
var _hide: Array[int] = []
var _search: Array[int] = []
## spot -> occupant; spot -> survivor entering; spots whose search completed during an entry.
var _occupant: Dictionary[int, int] = {}
var _entering: Dictionary[int, int] = {}
var _eject_due: Dictionary[int, bool] = {}
var _runner: TickRunner
## AD-194 occupancy replication: occupant -> spot last sent; this tick's changes (-1 = left); tick diffed.
var _hide_sent: Dictionary[int, int] = {}
var _hide_out: Dictionary[int, int] = {}
var _out_tick: int = -1


## `healthy(actor) -> bool`: a Healthy survivor (rule 19; Downing and the shock lock fold in here).
## `is_monster(actor) -> bool`: the shapeshifter, in any form (rule 22). `set_hidden(actor, on)`:
## SurvivorDefense.set_hidden. `modifiers_of(actor) -> MovementModifiers` (null or unset: no root).
## `place(actor, floor_position)`: moves an ejected survivor's body to the spot's front (unset: it stays).
func _init(holds: HoldService, map: MapData, healthy: Callable, is_monster: Callable, set_hidden: Callable,
		modifiers_of: Callable = Callable(), place: Callable = Callable()) -> void:
	_holds = holds
	_map = map
	_healthy = healthy
	_is_monster = is_monster
	_set_hidden = set_hidden
	_modifiers_of = modifiers_of
	_place = place


## RoundServer entry: registers Hide and Search on every hiding marker, all spots empty.
func setup(tick_runner: Node, _bus: EventBus, _registry: StateRegistry, knobs: Knobs) -> void:
	_runner = tick_runner as TickRunner
	_hide_sent = {}
	_hide_out = {}
	_out_tick = -1
	var rules := MapQueries.InteractRules.from_knobs(knobs)
	_points = []
	_exits = []
	_hide = []
	_search = []
	_occupant = {}
	_entering = {}
	_eject_due = {}
	for t: Resource in _map.interactables():
		var m := t as MapMarker
		if m == null or m.type != &"hiding":
			continue
		var spot := _points.size()
		_exits.append(_exit_point(m, knobs))
		_points.append(m.position + Vector3.UP * rules.point_height_m)
		for search: bool in [false, true]:
			var h := HidingHold.new()
			h.owner = weakref(self)
			h.spot = spot
			h.search = search
			h.point = _points[spot]
			h.range_m = rules.range_by_type[&"hiding"]
			h.duration_s = knobs.defense.search_duration_s if search else knobs.defense.hide_transition_s
			h.roots_actor = true
			h.lock_key = StringName("%s_%d" % ["search" if search else "hide", spot])
			(_search if search else _hide).append(_holds.register(h))


## Timed by HoldService: nothing to advance.
func server_tick(_tick: int) -> void:
	pass


## Interaction point of `spot`.
func point(spot: int) -> Vector3:
	return _points[spot]


## Net id of `spot`'s Hide (enter / leave) interactable.
func hide_id(spot: int) -> int:
	return _hide[spot]


## Net id of `spot`'s Search interactable.
func search_id(spot: int) -> int:
	return _search[spot]


## The survivor hidden in `spot`, -1 when empty.
func occupant(spot: int) -> int:
	return _occupant.get(spot, -1)


## ServerMovement.batch_extras provider (story 012, AD-194: occupancy to the occupant only, so no other
## viewer, survivor or monster, learns who hides where): [EventBatch.HIDING, {spot}] for `viewer` in the
## batch after it entered (spot) or left or was ejected (-1). Diffed once per tick for every viewer.
## Not yet: a viewer whose peer is gone that tick misses the change (no batch_extras catch-up on rejoin).
func hiding_entries(viewer: int) -> Array:
	if _runner == null:
		return []
	if _out_tick != _runner.current_tick():
		_out_tick = _runner.current_tick()
		var now: Dictionary[int, int] = {}
		for spot: int in _occupant:
			now[_occupant[spot]] = spot
		_hide_out = {}
		for actor: int in now:
			if _hide_sent.get(actor, -1) != now[actor]:
				_hide_out[actor] = now[actor]
		for actor: int in _hide_sent:
			if not now.has(actor):
				_hide_out[actor] = -1
		_hide_sent = now
	return [[EventBatch.HIDING, {"spot": _hide_out[viewer]}]] if _hide_out.has(viewer) else []


## Rules 18, 19: the occupant may leave; a Healthy survivor not hidden anywhere may enter an empty spot.
func can_hide(actor: int, spot: int) -> bool:
	if _occupant.has(spot):
		return _occupant[spot] == actor
	return _healthy.call(actor) and not _occupant.values().has(actor)


## Rule 22: the monster in any form; survivors cannot search.
func can_search(actor: int) -> bool:
	return _is_monster.call(actor)


## A Hide hold started (HidingHold only): an entry when `actor` is not the occupant.
func hide_started(actor: int, spot: int) -> void:
	if not _occupant.has(spot):
		_entering[spot] = actor


## A Hide hold cancelled (HidingHold only): progress resets, a search held for this entry is spent.
func hide_cancelled(actor: int, spot: int) -> void:
	if _entering.get(spot, -1) == actor:
		_entering.erase(spot)
		_eject_due.erase(spot)


## A Hide hold completed (HidingHold only): the occupant leaves, or `actor` enters and is hidden, then
## ejected if a search completed during the entry.
func hide_completed(actor: int, spot: int) -> void:
	if _occupant.get(spot, -1) == actor:
		_leave(spot)
		return
	_entering.erase(spot)
	_occupant[spot] = actor
	_set_hidden.call(actor, true)
	var mods := _mods(actor)
	if mods != null:
		mods.add(MOD_OWNER, MovementModifiers.Kind.ROOT)
	if _eject_due.erase(spot):
		_eject(spot)


## A Search completed (HidingHold only): ejects the occupant; on an entry, waits for it; empty: nothing.
func search_completed(spot: int) -> void:
	if _occupant.has(spot):
		_eject(spot)
	elif _entering.has(spot):
		_eject_due[spot] = true


## Rule 22: out in front of the spot (marker floor + hide_eject_offset_m along its yaw, AD-200), no hit,
## no down. Ends the occupant's own hold (a leave under way). No free point: the exit waits, so the
## survivor stays hidden and the search is spent.
func _eject(spot: int) -> void:
	if _exits[spot] == null:
		return
	var actor: int = _occupant[spot]
	_leave(spot)
	_holds.cancel(actor, CANCEL_EJECTED)
	if _place.is_valid():
		_place.call(actor, _exits[spot])


## The marker's front, or the nearest free point within EJECT_SEARCH_M of it, or null (controller GDD edge
## case). Free = inside the marker's own volume, one capsule radius clear of its walls (x, z).
## Inference: only the static map blocks; the map has no props or other bodies on the server, so the
## answer is fixed per round. A server-side body overlap check would make it per eject.
## ponytail: the "exit waits" case never clears without that body check; add a retry with it.
func _exit_point(m: MapMarker, knobs: Knobs) -> Variant:
	var facing := Basis(Vector3.UP, deg_to_rad(m.yaw_deg)) * Vector3.FORWARD
	var front := m.position + facing * knobs.defense.hide_eject_offset_m
	for v in _map.volumes:
		if v.id != m.volume:
			continue
		var r := knobs.controller.player_radius_m
		var free := Vector3(clampf(front.x, v.box.position.x + r, v.box.end.x - r), front.y,
				clampf(front.z, v.box.position.z + r, v.box.end.z - r))
		return free if free.distance_to(front) <= EJECT_SEARCH_M else null
	return null


func _leave(spot: int) -> void:
	var actor: int = _occupant[spot]
	_occupant.erase(spot)
	_set_hidden.call(actor, false)
	var mods := _mods(actor)
	if mods != null:
		mods.remove(MOD_OWNER)


func _mods(actor: int) -> MovementModifiers:
	return _modifiers_of.call(actor) if _modifiers_of.is_valid() else null
