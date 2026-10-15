class_name HoldService extends RefCounted
## The one hold timer (ADR-0008; first-person-controller.md rules 11-16). Runs as the Holds step
## (TickOrder.HOLDS, inside TickRunner's physics phase) for each player in ADR-0007 §6's rotated
## order: stop, then Start on a rising edge (eligibility, strict range_m, line of sight, lock), then
## continue (eligible, range_m + hold_range_tolerance_m, line of sight; story 009), then advance. Owners
## register Interactables and get direct calls; HoldService emits no events.
## Fake holds (ADR-0008 §6; GDD rule 17): a shapeshifter Start on a `fakeable` interactable passes range
## and sight only, then holds with no lock, no progress, no owner call (eligible() included) and never
## completes; range or sight loss and release end it silently. A real Start accepted on the same
## interactable cancels it. hold_of() shows it like a real hold, so observers' `holding` bit matches (§8).
## The view direction is not checked while holding: a hold survives looking away (GDD rule 14).
## Collaborators are injected as Callables (ADR-0005 §6 dependency injection; BodyIndex of the ADR
## interface does not exist yet):
##   players() -> Array[int]                     player IDs in the round
##   frames(actor) -> Array[InputFrame]          frames consumed this tick, oldest first (the repeat when starved)
##   centre_of(actor) -> Vector3                 capsule centre
##   sight(actor, i: Interactable) -> bool       eye to point clear (MapQueries.clear_line on the server)
##   aim(actor) -> int                           map interactable index the server's own view ray picks
##                                               (MapQueries.interactable_on_ray with ViewState.server_dir), -1 if
##                                               none; a non-body Start's interact_target must match it (AD-217)
##   body_target(actor, handle) -> int           net id on the body the actor's handle names, or -1
##   is_shapeshifter(actor) -> bool              the actor's role; unset = nobody (no fake holds)
##   barred(actor) -> bool                       set_barred: the actor may not interact at all, fakes
##                                               included (borrowed-face.md rule 8: Transforming); unset = never
##   ids_at(index) -> Array                      set_ids_at: hold net ids at map interactable `index` (a hiding
##                                               spot carries Hide and Search); unset = [index] (doors register first)
## Usage:
##   var holds := HoldService.new(knobs, players, frames, centre_of, sight, aim)
##   holds.register(slot); holds.server_tick(tick)   # from the Holds step

const RANGE_EPS_M := 1e-6

## Optional observer `on_end(actor, reason: StringName)` (story hud-results/011, H9): every cancel with its
## reason, and a refused Start that got as far as range, sight or the lock: &"too_far", &"no_sight", &"in_use".
## Other refusals report nothing. HoldReasonFeed is the user; it decides what reaches a client.
var on_end: Callable

var _knobs: Knobs
var _players: Callable
var _frames: Callable
var _centre_of: Callable
var _sight: Callable
var _aim: Callable
var _body_target: Callable
var _is_shapeshifter: Callable
var _barred: Callable
var _ids_at: Callable
var _items: Array[Interactable] = []
## actor -> {"item": Interactable, "elapsed": int, "fake": bool}
var _holds: Dictionary[int, Dictionary] = {}
## lock_key -> actor
var _locks: Dictionary[StringName, int] = {}
## actor -> interact held on the last frame seen (rising edges only start holds)
var _down: Dictionary[int, bool] = {}


func _init(knobs: Knobs, players: Callable, frames: Callable, centre_of: Callable, sight: Callable,
		aim: Callable, body_target: Callable = Callable(), is_shapeshifter: Callable = Callable()) -> void:
	_knobs = knobs
	_players = players
	_frames = frames
	_centre_of = centre_of
	_sight = sight
	_aim = aim
	_body_target = body_target
	_is_shapeshifter = is_shapeshifter


## Injects `barred(actor) -> bool` (see the class comment): a barred actor's Start is rejected and its
## running hold, real or fake, cancels with &"ineligible" on the next Holds step.
func set_barred(barred: Callable) -> void:
	_barred = barred


## Injects `ids_at(index) -> Array` (see the class comment): a non-body Start on map index `index` takes
## the first net id there the actor may start (eligible, or a shapeshifter's fake).
func set_ids_at(ids_at: Callable) -> void:
	_ids_at = ids_at


## Registers `i` under the next net id (map interactables first, in map order) and returns it.
func register(i: Interactable) -> int:
	i.net_id = _items.size()
	_items.append(i)
	return i.net_id


## Cancels any hold on the interactable and frees its id slot (ids are never reused).
func unregister(net_id: int) -> void:
	if net_id < 0 or net_id >= _items.size() or _items[net_id] == null:
		return
	var item := _items[net_id]
	for actor: int in _holds.keys():
		# has(): an owner's on_cancel may already have cancelled a later actor (ADR-0008 §5).
		if _holds.has(actor) and _holds[actor].item == item:
			cancel(actor, &"unregistered")
	_items[net_id] = null


## Owner interrupt (ADR-0008 §5): ends `actor`'s hold, releases its lock, calls on_cancel. A fake hold
## just ends: it holds no lock and the owner never heard of it (§6).
func cancel(actor: int, reason: StringName) -> void:
	if not _holds.has(actor):
		return
	var h: Dictionary = _holds[actor]
	_holds.erase(actor)
	_ended(actor, reason)
	if h.fake:
		return
	var item: Interactable = h.item
	_release(item, actor)
	item.on_cancel(actor, h.elapsed / float(_knobs.net.sim_tick_hz), reason)


## {net_id, elapsed_ticks, fake, roots} while holding; {} when idle (the client bar cancels).
func hold_of(actor: int) -> Dictionary:
	if not _holds.has(actor):
		return {}
	var h: Dictionary = _holds[actor]
	var item: Interactable = h.item
	return {"net_id": item.net_id, "elapsed_ticks": h.elapsed, "fake": h.fake, "roots": item.roots_actor}


## The Holds step.
func server_tick(tick: int) -> void:
	var players: Array = _players.call()
	for actor: int in _holds.keys(): ## left the round (disconnect, elimination): free its lock
		if not players.has(actor):
			cancel(actor, &"left")
	for actor: int in _down.keys():
		if not players.has(actor):
			_down.erase(actor)
	for actor in rotated(players, tick):
		var frames: Array = _frames.call(actor)
		if frames.is_empty():
			continue
		var rising: InputFrame = null
		var was: bool = _down.get(actor, false)
		for f: InputFrame in frames:
			if f.interact and not was:
				rising = f ## the target is read on the rising edge only (ADR-0008 §3); the last press wins
			was = f.interact
		_down[actor] = was
		# A rising edge needs a release first, so the old hold ends with any new press, accepted or not;
		# the reason tells the owner which (rule 16: a new hold cancels the old).
		if _holds.has(actor) and (not was or rising != null):
			cancel(actor, &"released" if not was else &"replaced")
		if rising != null:
			_try_start(actor, rising)
			if not was:
				cancel(actor, &"released") ## Stop arrived with the Start: accepted, then cancelled at 0
		else:
			# Not on the Start tick: Start just checked all three, and an owner's on_start may change its
			# own eligible() (a drive marked "being held"; code review 2026-10-14).
			_continue(actor)
		_advance(actor)


## Player IDs ascending, rotated by one position per tick (ADR-0007 §6): who wins a contested lock.
static func rotated(ids: Array, tick: int) -> Array[int]:
	var sorted: Array[int] = []
	sorted.assign(ids)
	sorted.sort()
	if sorted.is_empty():
		return sorted
	var k := posmod(tick, sorted.size())
	return sorted.slice(k) + sorted.slice(0, k)


func _try_start(actor: int, f: InputFrame) -> void:
	if _is_barred(actor):
		return
	var item := _resolve(actor, f) ## eligible, or a fake (§6): a fake asks the owner nothing
	if item == null:
		return
	var fake := _fakes(actor, item)
	var centre: Vector3 = _centre_of.call(actor)
	if centre.distance_to(item.point) > item.range_m + RANGE_EPS_M:
		_ended(actor, &"too_far")
		return ## Start is strict range_m; tolerance is for continuation (story 009)
	if not _sight.call(actor, item):
		_ended(actor, &"no_sight")
		return
	if fake:
		# Inference: a fake ignores a held lock too (rule 25: "at any objective point"); the fake on a
		# free target is all the GDD's AC fixes. A designer ruling on faking beside a real holder settles it.
		_holds[actor] = {"item": item, "elapsed": 0, "fake": true}
		return
	if item.lock_key != &"" and _locks.has(item.lock_key):
		_ended(actor, &"in_use")
		return ## AC1: a held exclusive lock rejects every Start on its key, instant ones included
	for other: int in _holds.keys(): ## a real Start cancels fakes on the same interactable (rule 25)
		if _holds[other].fake and _holds[other].item == item:
			cancel(other, &"replaced")
	if item.duration_s <= 0.0:
		item.on_start(actor)
		item.on_complete(actor) ## instant: takes no lock, keeps no hold
		return
	if item.lock_key != &"":
		_locks[item.lock_key] = actor
	_holds[actor] = {"item": item, "elapsed": _knobs.ticks(item.start_progress_s()), "fake": false}
	item.on_start(actor)


func _resolve(actor: int, f: InputFrame) -> Interactable:
	if f.target_is_body:
		var body := _item(_body_target.call(actor, f.interact_target) if _body_target.is_valid() else -1)
		return body if _startable(actor, body) else null
	# AD-217: a non-body target is a map interactable index; clients never learn hold net ids.
	var idx := f.interact_target
	if idx < 0 or _aim.call(actor) != idx:
		return null ## GDD rule 10: the Start resolves against the server's ray, not the client's claim
	var ids: Array = _ids_at.call(idx) if _ids_at.is_valid() else [idx]
	for id: int in ids:
		var item := _item(id)
		# Inference: the first startable id wins, a fake included; no object yet carries both a fakeable
		# and a real hold for one actor. A designer ruling on such an object would settle the order.
		# SD-14: only the holds of the pressed input; an alt press on an object with none starts nothing.
		if item != null and item.alt == f.interact_alt and _startable(actor, item):
			return item
	return null


## A shapeshifter on a non-fakeable target is refused here, by its owner's eligible() (§6).
func _startable(actor: int, item: Interactable) -> bool:
	return item != null and (_fakes(actor, item) or item.eligible(actor))


func _fakes(actor: int, item: Interactable) -> bool:
	return item.fakeable and _is_shapeshifter.is_valid() and _is_shapeshifter.call(actor)


## The registered interactable with net id `id`, null if none (WorldProgress reads its point and duration).
func item(id: int) -> Interactable:
	return _item(id)


func _item(id: int) -> Interactable:
	return _items[id] if id >= 0 and id < _items.size() else null


## ADR-0008 §4: the hold ends this tick when the actor is no longer eligible (the owner's state changed:
## picked up, rescued, Downed), beyond range_m + hold_range_tolerance_m from the point (capsule centre),
## or without line of sight. Reasons: &"ineligible", &"range", &"sight".
func _continue(actor: int) -> void:
	if not _holds.has(actor):
		return
	var item: Interactable = _holds[actor].item
	if _is_barred(actor) or not _holds[actor].fake and not item.eligible(actor): ## a fake never asks the owner
		cancel(actor, &"ineligible")
		return
	var centre: Vector3 = _centre_of.call(actor)
	if centre.distance_to(item.point) > item.range_m + _knobs.controller.hold_range_tolerance_m + RANGE_EPS_M:
		cancel(actor, &"range")
		return
	if not _sight.call(actor, item):
		cancel(actor, &"sight")


func _ended(actor: int, reason: StringName) -> void:
	if on_end.is_valid():
		on_end.call(actor, reason)


func _is_barred(actor: int) -> bool:
	return _barred.is_valid() and _barred.call(actor)


func _advance(actor: int) -> void:
	if not _holds.has(actor):
		return
	var h: Dictionary = _holds[actor]
	if h.fake:
		return ## no progress, never completes
	h.elapsed += 1
	var item: Interactable = h.item
	if h.elapsed >= _knobs.ticks(item.duration_s):
		_holds.erase(actor)
		_release(item, actor)
		item.on_complete(actor)


func _release(item: Interactable, actor: int) -> void:
	if item.lock_key != &"" and _locks.get(item.lock_key, -1) == actor:
		_locks.erase(item.lock_key)
