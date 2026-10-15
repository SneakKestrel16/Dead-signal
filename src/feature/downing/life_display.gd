class_name LifeDisplay extends RefCounted
## Client display state of every survivor's life state, down count and bleed-out ring (story
## downing-and-rescue/007; design/gdd/downing-and-rescue.md UI Requirements; ADR-0004 §5). Client only,
## and decides nothing: it applies the server's projected SurvivorDowned / SurvivorRescued /
## SurvivorEliminated entries and EventBatch.BLEED_RING entries, routed by ClientEventRouter (which
## drops anything not from the server peer). It has no path back to the server.
## Not a StateRegistry view (those are getter-only `*_view.gd`): it holds received state and mutates.
## The roster has no Seized state: Seized is body presentation (ADR-0004 §2), so a Seized survivor reads
## Healthy here. The down count is not on the wire; it follows Downing's own increments: +1 on
## SurvivorDowned, +1 on SurvivorEliminated "Taken down", none on "Bled out". Batches are reliable and
## ordered, so the count is exact; a client that reconnects mid-round misses earlier changes until the
## server re-sends the life states (not yet: ServerMovement.catch_up has no Downing provider).
## The ring: SurvivorDowned's `bleed_out_s` (survivor clients only) starts it, each BLEED_RING entry
## resets remaining_s and rate, and advance() runs it at `rate` in between.
## Usage (client):
##   var life := LifeDisplay.new(router)
##   func _process(delta): life.advance(delta); hud.roster(life.life_state(s), life.downs_taken(s))

## Entries with a bad payload (wrong types, unknown reason, non-finite time) or a ring for a survivor
## not Downed here.
var rejected: int = 0

## survivor -> Downing.LifeState (absent = Healthy)
var _life: Dictionary[int, int] = {}
## survivor -> downs taken (absent = 0)
var _downs: Dictionary[int, int] = {}
## Downed survivor -> seconds left at `rate` (absent = no ring: not Downed, or the shapeshifter's client)
var _remaining: Dictionary[int, float] = {}
## Downed survivor -> ring rate, s of bleed-out per s (absent = no ring)
var _rate: Dictionary[int, float] = {}


## Subscribes to `router`'s life-state and ring entries.
func _init(router: ClientEventRouter) -> void:
	router.subscribe(&"SurvivorDowned", on_downed)
	router.subscribe(&"SurvivorRescued", on_rescued)
	router.subscribe(&"SurvivorEliminated", on_eliminated)
	router.subscribe(EventBatch.BLEED_RING, on_ring)


## Local time passing (per frame, seconds): every ring runs down at its rate.
func advance(delta_s: float) -> void:
	for s: int in _remaining:
		_remaining[s] = maxf(0.0, _remaining[s] - _rate[s] * delta_s)


## Downing.LifeState of `survivor` as shown on this client (never SEIZED).
func life_state(survivor: int) -> int:
	return _life.get(survivor, Downing.LifeState.HEALTHY)


## Takedowns on `survivor` this round as shown on this client.
func downs_taken(survivor: int) -> int:
	return _downs.get(survivor, 0)


## Bleed-out seconds left on `survivor`'s ring, -1 when there is no ring (not Downed, or this client
## never receives bleed-out state).
func bleed_remaining_s(survivor: int) -> float:
	return _remaining.get(survivor, -1.0)


## The ring's current rate (1 full, camp_slow_mult slowed, 0 paused by a rescue), -1 until the server
## sent one.
func bleed_rate(survivor: int) -> float:
	return _rate.get(survivor, -1.0) if _remaining.has(survivor) else -1.0


## ClientEventRouter handler for SurvivorDowned.
func on_downed(_tick: int, p: Dictionary) -> void:
	var s: Variant = p.get("survivor")
	var left: Variant = p.get("bleed_out_s", 0.0)
	if not (s is int and left is float and is_finite(left) and left >= 0.0):
		rejected += 1
		return
	_life[s] = Downing.LifeState.DOWNED
	_downs[s] = downs_taken(s) + 1
	if p.has("bleed_out_s"):
		_remaining[s] = left
		_rate.erase(s) # the first ring entry follows on the next tick
	else:
		_remaining.erase(s)
		_rate.erase(s)


## ClientEventRouter handler for SurvivorRescued.
func on_rescued(_tick: int, p: Dictionary) -> void:
	var s: Variant = p.get("survivor")
	if not s is int:
		rejected += 1
		return
	_life[s] = Downing.LifeState.HEALTHY
	_clear_ring(s)


## ClientEventRouter handler for SurvivorEliminated.
func on_eliminated(_tick: int, p: Dictionary) -> void:
	var s: Variant = p.get("survivor")
	var reason: Variant = p.get("reason")
	if not (s is int and reason is int and reason >= 0 and reason < EvSurvivorEliminated.REASON_TEXT.size()):
		rejected += 1
		return
	_life[s] = Downing.LifeState.ELIMINATED
	if reason == EvSurvivorEliminated.TAKEN_DOWN:
		_downs[s] = downs_taken(s) + 1
	_clear_ring(s)


## ClientEventRouter handler for EventBatch.BLEED_RING.
func on_ring(_tick: int, p: Dictionary) -> void:
	var s: Variant = p.get("survivor")
	var left: Variant = p.get("remaining_s")
	var rate: Variant = p.get("rate")
	if not (s is int and life_state(s) == Downing.LifeState.DOWNED and left is float and rate is float
			and is_finite(left) and is_finite(rate) and left >= 0.0 and rate >= 0.0):
		rejected += 1
		return
	_remaining[s] = left
	_rate[s] = rate


func _clear_ring(s: int) -> void:
	_remaining.erase(s)
	_rate.erase(s)
