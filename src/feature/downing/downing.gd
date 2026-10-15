class_name Downing extends RefCounted
## Downing, Rescue & Elimination: life state, down count and the takedown commit (Feature layer).
## Implements design/gdd/downing-and-rescue.md rules 2-5, Formulas "Takedown outcome" and the
## commit rows of Edge Cases; story downing-and-rescue/001; ADR-0005. Story 002 adds grace (rules
## 4.4, 8) and the hidden check to eligibility (rule 3). Story 003 adds the bleed-out
## timer (rule 6, rule 10, Formulas "Bleed-out"), counted in ticks and advanced in server_tick.
## Server only. The commit counts ticks of `net.sim_tick_hz`, never wall time. Order within a tick:
## MonsterStunned (Survivor Defense slot, 200) and SurvivorHit (Monster Abilities slot, 400) are
## handled in their slots' flushes, before server_tick runs in the DOWNING slot (500), so a stun
## on the completion tick cancels the commit before it can complete (Edge Cases: stun wins).
## Usage:
##   var d := Downing.new()
##   d.set_roster([2, 3, 4, 5], 1)   # survivor ids, monster id: BEFORE start_round
##   d.set_positions(func(p: int) -> Vector3: return ...)   # for the camping slow
##   d.set_hidden(func(p: int) -> bool: return ...)          # Survivor Defense's hidden state
##   server.start_round({TickOrder.DOWNING: d}, knobs)
## Story 005 adds the movement restrictions: `set_modifiers(server_movement.modifiers_of)` lets
## Downing write its own `MOD_OWNER` modifier (rule 4.2, rule 7), and `action_locked` publishes the
## action restriction on the TAKEDOWN_ELIGIBILITY view. Crawl is the Controller's gait, chosen from
## the life state (first-person-controller.md gait order), not a modifier: a crawl slow on top of
## the crawl gait would apply crawl_speed_mult twice.

enum LifeState { HEALTHY, SEIZED, DOWNED, ELIMINATED }

## The MovementModifiers owner Downing adds and removes (first-person-controller.md rule 6).
const MOD_OWNER := &"downing"

var _bus: EventBus
var _survivors: Array[int] = []
var _monster: int = -1
var _commit_ticks: int = 0
var _downs_to_eliminate: int = 0
var _bleedout_s: float = 0.0
var _hz: int = 0
var _bleed_ticks: int = 0
var _camp_slow_radius_m: float = 0.0
var _camp_slow_mult: float = 0.0
var _release_grace_ticks: int = 0
var _rescue_grace_ticks: int = 0
## player id -> Vector3; invalid means no positions, so nothing slows bleed-out.
var _position_of: Callable
## player id -> bool, Survivor Defense's hidden state; invalid means nobody is hidden.
var _is_hidden: Callable
## Survivor -> first tick on which grace no longer applies (absent = no grace).
var _grace_end: Dictionary[int, int] = {}
## player id -> MovementModifiers (null: no body); invalid means Downing writes no modifiers.
var _modifiers_of: Callable
## player id -> LifeState
var _life: Dictionary[int, int] = {}
## player id -> completed takedowns this round
var _downs_taken: Dictionary[int, int] = {}
## The survivor in the running commit, -1 when the monster is not Committing.
var _victim: int = -1
## Tick on which the running commit completes.
var _commit_end_tick: int = 0
## Downed survivor -> bleed_elapsed in ticks (float: slowed ticks add camp_slow_mult).
var _bleed: Dictionary[int, float] = {}
## Downed survivors whose rescue hold is active (story 004 drives it through set_rescuing).
var _rescuing: Dictionary[int, bool] = {}
## Players with no body in the world: escaped, or disconnected until they reconnect.
var _escaped: Dictionary[int, bool] = {}
var _disconnected: Dictionary[int, bool] = {}


## Getter-only view for StateKeys.TAKEDOWN_ELIGIBILITY readers: life state, down count and
## eligibility per survivor. Holds the module weakly; after the module is freed it reads as
## Healthy, 0 downs, not eligible (fails closed).
class LifeView extends RefCounted:
	var _d: WeakRef

	func _init(d: Downing) -> void:
		_d = weakref(d)

	## LifeState of `player`.
	func life_state(player: int) -> int:
		var d := _d.get_ref() as Downing
		return d.life_state(player) if d != null else Downing.LifeState.HEALTHY

	## Completed takedowns on `player` this round.
	func downs_taken(player: int) -> int:
		var d := _d.get_ref() as Downing
		return d.downs_taken(player) if d != null else 0

	## Whether `player` is a valid takedown target (rule 3).
	func eligible(player: int) -> bool:
		var d := _d.get_ref() as Downing
		return d.eligible(player) if d != null else false

	## Whether `player` is barred from interacting, barricading, hiding, items, abilities and
	## transforming (rules 4.2 and 6). Fails closed: true after the module is freed.
	func action_locked(player: int) -> bool:
		var d := _d.get_ref() as Downing
		return d.action_locked(player) if d != null else true


## Getter-only view for StateKeys.COMMITTING_STATE readers. Holds the module weakly.
class CommitView extends RefCounted:
	var _d: WeakRef

	func _init(d: Downing) -> void:
		_d = weakref(d)

	## True while the monster is Committing.
	func committing() -> bool:
		var d := _d.get_ref() as Downing
		return d.committing() if d != null else false

	## The seized survivor, -1 when not Committing.
	func victim() -> int:
		var d := _d.get_ref() as Downing
		return d.victim() if d != null else -1


## Injects the round's roster. Call before RoundServer.start_round (setup resets state from it).
## `survivors`: survivor player ids; `monster`: the shapeshifter's player id.
func set_roster(survivors: Array[int], monster: int) -> void:
	_survivors = survivors.duplicate()
	_monster = monster


## Injects the position source for the camping slow: `source.call(player_id) -> Vector3`. Until
## Network Authority publishes StateKeys.PLAYER_POSITIONS_LIFE_STATES this is the only feed; unset,
## no player counts as near and bleed-out runs at full rate.
func set_positions(source: Callable) -> void:
	_position_of = source


## Injects Survivor Defense's hidden state: `source.call(player_id) -> bool`. Unset, nobody is hidden
## (rule 3: an absent owner reads as not hidden).
func set_hidden(source: Callable) -> void:
	_is_hidden = source


## Injects the per-player movement modifier sets: `source.call(player_id) -> MovementModifiers`,
## null for a player with no body (ServerMovement.modifiers_of in the composer). Unset, Downing
## writes no modifiers.
func set_modifiers(source: Callable) -> void:
	_modifiers_of = source


## Injected by RoundServer. Reads knobs, resets every survivor to Healthy with 0 downs (rule 2),
## publishes the views and subscribes to SurvivorHit, MonsterStunned, PlayerConnectionChanged and
## SurvivorEscaped.
func setup(_tick_runner: TickRunner, bus: EventBus, registry: StateRegistry, knobs: Knobs) -> void:
	_bus = bus
	_commit_ticks = knobs.ticks(knobs.downing.takedown_commit_s)
	_downs_to_eliminate = knobs.downing.downs_to_eliminate
	_bleedout_s = knobs.downing.bleedout_s
	_hz = knobs.net.sim_tick_hz
	_bleed_ticks = knobs.ticks(knobs.downing.bleedout_s)
	_camp_slow_radius_m = knobs.downing.camp_slow_radius_m
	_camp_slow_mult = knobs.downing.camp_slow_mult
	_release_grace_ticks = knobs.ticks(knobs.downing.post_release_grace_s)
	_rescue_grace_ticks = knobs.ticks(knobs.downing.post_rescue_grace_s)
	_grace_end = {}
	_bleed = {}
	_rescuing = {}
	_escaped = {}
	_disconnected = {}
	_life = {}
	_downs_taken = {}
	for s in _survivors:
		_life[s] = LifeState.HEALTHY
		_downs_taken[s] = 0
	_victim = -1
	registry.register_view(StateKeys.TAKEDOWN_ELIGIBILITY, &"Downing", LifeView.new(self))
	registry.register_view(StateKeys.COMMITTING_STATE, &"Downing", CommitView.new(self))
	bus.subscribe(&"SurvivorHit", _on_survivor_hit)
	bus.subscribe(&"MonsterStunned", _on_monster_stunned)
	bus.subscribe(&"PlayerConnectionChanged", _on_connection_changed)
	bus.subscribe(&"SurvivorEscaped", _on_escaped)


## DOWNING slot: advances every bleed-out timer one tick, eliminating on expiry (rule 6), then
## completes the running commit on its end tick (rule 4.5). Bleed runs first, so a survivor Downed
## this tick starts bleeding on the next and is Eliminated exactly `bleedout_s` after the down.
func server_tick(tick: int) -> void:
	var healthy := _healthy_survivors()
	for s: int in _bleed.keys():
		_bleed[s] = bleed_step(_bleed[s], 1.0, _rescuing.has(s), _nearest_distance_m(s), healthy,
			_camp_slow_radius_m, _camp_slow_mult)
		if _bleed[s] >= _bleed_ticks:
			_bleed_out(s)
	if _victim >= 0 and tick >= _commit_end_tick:
		_complete_commit()
	_apply_modifiers()


## Formulas "Bleed-out", one step: paused while rescued; `dt * camp_slow_mult` while the nearest
## other counted player is within `camp_slow_radius_m` and a survivor is Healthy; else `dt`.
## `elapsed` and `dt` share a unit (Downing uses ticks). Example:
## `Downing.bleed_step(10.0, 1.0, false, 9.0, 1, 10.0, 0.25)` -> 10.25.
static func bleed_step(elapsed: float, dt: float, rescuing: bool, nearest_player_distance_m: float,
		healthy_survivors: int, camp_slow_radius_m: float, camp_slow_mult: float) -> float:
	if rescuing:
		return elapsed
	if nearest_player_distance_m <= camp_slow_radius_m and healthy_survivors >= 1:
		return elapsed + dt * camp_slow_mult
	return elapsed + dt


## Pauses (`on` true) or resumes the bleed-out timer of Downed `player` during a rescue hold.
## Story 004's rescue hold drives this; nothing else should.
func set_rescuing(player: int, on: bool) -> void:
	if on:
		_rescuing[player] = true
	else:
		_rescuing.erase(player)
	_apply_modifiers()


## Seconds of bleed-out elapsed for `player` (0 when not Downed).
func bleed_elapsed_s(player: int) -> float:
	return _bleed.get(player, 0.0) / _hz


## LifeState of `player` (Healthy for an id not in the roster).
func life_state(player: int) -> LifeState:
	return _life.get(player, LifeState.HEALTHY) as LifeState


## Completed takedowns on `player` this round.
func downs_taken(player: int) -> int:
	return _downs_taken.get(player, 0)


## Rule 3: a survivor in the roster who is a valid takedown target on the current tick.
func eligible(player: int) -> bool:
	var hidden: bool = _is_hidden.is_valid() and _is_hidden.call(player)
	return is_eligible(_life.get(player, -1), hidden, _bus.tick, _grace_end.get(player, 0))


## Rule 3 as a pure function: Healthy (so not Seized in a commit), not hidden, and `tick` at or past
## `grace_end_tick`. Example: `Downing.is_eligible(LifeState.HEALTHY, false, 100, 100)` -> true.
static func is_eligible(state: int, hidden: bool, tick: int, grace_end_tick: int) -> bool:
	return state == LifeState.HEALTHY and not hidden and tick >= grace_end_tick


## Rule 8: Downed `player` stands up Healthy, `downs_taken` unchanged, with `post_rescue_grace_s`
## from the current tick. Story 004's rescue completion calls this; nothing else should. No-op
## unless Downed.
func stand_up(player: int) -> void:
	if life_state(player) != LifeState.DOWNED:
		return
	_bleed.erase(player)
	_rescuing.erase(player)
	_life[player] = LifeState.HEALTHY
	_grace_end[player] = _bus.tick + _rescue_grace_ticks


## True while the monster is Committing.
func committing() -> bool:
	return _victim >= 0


## The seized survivor, -1 when not Committing.
func victim() -> int:
	return _victim


## Rules 4.2 and 6: a Seized or Downed survivor, or the monster while Committing, may not interact
## with objectives, barricade, hide, use items, use abilities or transform. Survivor Defense,
## Survivor Objectives, Monster Abilities and Borrowed Face gate on it (Downing never calls them).
## Pings and Call for Help are not gated by it: a Downed survivor keeps them (rule 6).
func action_locked(player: int) -> bool:
	var st := life_state(player)
	return st == LifeState.SEIZED or st == LifeState.DOWNED or (player == _monster and committing())


## Writes Downing's one modifier per player from the current state: LOCK for the Seized victim
## (first-person-controller.md States: Locked), ROOT for the Committing monster (rule 4.2) and for
## a Downed survivor under a rescue hold (rule 7); none otherwise, so every end of those states
## removes it. The rescuer's root is the rescue hold's `roots_actor` (ADR-0008), not this modifier.
## Runs at the end of server_tick and on every state change made outside it.
func _apply_modifiers() -> void:
	if not _modifiers_of.is_valid():
		return
	for p: int in _survivors + [_monster]:
		var mods := _modifiers_of.call(p) as MovementModifiers
		if mods == null:
			continue
		if p == _victim:
			mods.add(MOD_OWNER, MovementModifiers.Kind.LOCK)
		elif (p == _monster and committing()) or (_rescuing.has(p) and life_state(p) == LifeState.DOWNED):
			mods.add(MOD_OWNER, MovementModifiers.Kind.ROOT)
		else:
			mods.remove(MOD_OWNER)


func _on_survivor_hit(e: ServerEvent) -> void:
	var hit := e as EvSurvivorHit
	# One monster, one commit: a hit during a commit is ignored, as is one on an ineligible survivor.
	if committing() or not eligible(hit.survivor):
		return
	_victim = hit.survivor
	_life[_victim] = LifeState.SEIZED
	_commit_end_tick = hit.tick + _commit_ticks


func _on_monster_stunned(e: ServerEvent) -> void:
	if (e as EvMonsterStunned).monster == _monster:
		_cancel_commit()


func _on_connection_changed(e: ServerEvent) -> void:
	var c := e as EvPlayerConnectionChanged
	# No body in the world while disconnected: stops counting for the camping slow (Edge Cases).
	if c.status == EvPlayerConnectionChanged.RECONNECTED:
		_disconnected.erase(c.player)
	else:
		_disconnected[c.player] = true
	# Only the monster's disconnect cancels; a Seized victim's commit runs on (Edge Cases).
	if c.player == _monster and c.status == EvPlayerConnectionChanged.DISCONNECTED:
		_cancel_commit()


func _on_escaped(e: ServerEvent) -> void:
	_escaped[(e as EvSurvivorEscaped).survivor] = true


## Formulas "Bleed-out" healthy_survivors: Healthy, not escaped, connected.
func _healthy_survivors() -> int:
	var n := 0
	for s in _survivors:
		if _life[s] == LifeState.HEALTHY and _present(s):
			n += 1
	return n


func _present(player: int) -> bool:
	return not _escaped.has(player) and not _disconnected.has(player)


## Formulas "Bleed-out" nearest_player_distance_m: from Downed `s` to the nearest other player in
## the world who is not Downed (survivor in any non-Downed living state, or the monster in any form).
## INF when there is none or no position source.
func _nearest_distance_m(s: int) -> float:
	var best := INF
	if not _position_of.is_valid():
		return best
	var at: Vector3 = _position_of.call(s)
	for p in _survivors + [_monster]:
		if p == s or not _present(p):
			continue
		var st := life_state(p)
		if st == LifeState.DOWNED or st == LifeState.ELIMINATED:
			continue
		best = minf(best, at.distance_to(_position_of.call(p)))
	return best


## Rule 6: bleed-out expired; Eliminated with reason "Bled out".
func _bleed_out(s: int) -> void:
	_bleed.erase(s)
	_rescuing.erase(s)
	_life[s] = LifeState.ELIMINATED
	var el := EvSurvivorEliminated.new()
	el.survivor = s
	el.reason = EvSurvivorEliminated.BLED_OUT
	_bus.emit(el)


## Rule 4.4: the victim returns to Healthy with downs_taken unchanged and `post_release_grace_s`
## from the cancelling event's tick.
func _cancel_commit() -> void:
	if not committing():
		return
	_life[_victim] = LifeState.HEALTHY
	_grace_end[_victim] = _bus.tick + _release_grace_ticks
	_victim = -1
	_apply_modifiers()


## Rule 4.5, Formulas "Takedown outcome".
func _complete_commit() -> void:
	var s := _victim
	_victim = -1
	_downs_taken[s] += 1
	if _downs_taken[s] >= _downs_to_eliminate:
		_life[s] = LifeState.ELIMINATED
		var el := EvSurvivorEliminated.new()
		el.survivor = s
		_bus.emit(el)
	else:
		_life[s] = LifeState.DOWNED
		_bleed[s] = 0.0
		var dn := EvSurvivorDowned.new()
		dn.survivor = s
		dn.bleed_out_s = _bleedout_s
		_bus.emit(dn)
