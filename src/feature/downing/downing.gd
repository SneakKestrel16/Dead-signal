class_name Downing extends RefCounted
## Downing, Rescue & Elimination: life state, down count and the takedown commit (Feature layer).
## Implements design/gdd/downing-and-rescue.md rules 2-5, Formulas "Takedown outcome" and the
## commit rows of Edge Cases; story downing-and-rescue/001; ADR-0005.
## Server only. The commit counts ticks of `net.sim_tick_hz`, never wall time. Order within a tick:
## MonsterStunned (Survivor Defense slot, 200) and SurvivorHit (Monster Abilities slot, 400) are
## handled in their slots' flushes, before server_tick runs in the DOWNING slot (500), so a stun
## on the completion tick cancels the commit before it can complete (Edge Cases: stun wins).
## Usage:
##   var d := Downing.new()
##   d.set_roster([2, 3, 4, 5], 1)   # survivor ids, monster id: BEFORE start_round
##   server.start_round({TickOrder.DOWNING: d}, knobs)
## Story 002 adds grace by extending `eligible(player)`.

enum LifeState { HEALTHY, SEIZED, DOWNED, ELIMINATED }

var _bus: EventBus
var _survivors: Array[int] = []
var _monster: int = -1
var _commit_ticks: int = 0
var _downs_to_eliminate: int = 0
var _bleedout_s: float = 0.0
## player id -> LifeState
var _life: Dictionary[int, int] = {}
## player id -> completed takedowns this round
var _downs_taken: Dictionary[int, int] = {}
## The survivor in the running commit, -1 when the monster is not Committing.
var _victim: int = -1
## Tick on which the running commit completes.
var _commit_end_tick: int = 0


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


## Injected by RoundServer. Reads knobs, resets every survivor to Healthy with 0 downs (rule 2),
## publishes the views and subscribes to SurvivorHit, MonsterStunned and PlayerConnectionChanged.
func setup(_tick_runner: TickRunner, bus: EventBus, registry: StateRegistry, knobs: Knobs) -> void:
	_bus = bus
	_commit_ticks = knobs.ticks(knobs.downing.takedown_commit_s)
	_downs_to_eliminate = knobs.downing.downs_to_eliminate
	_bleedout_s = knobs.downing.bleedout_s
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


## DOWNING slot: completes the running commit on its end tick (rule 4.5).
func server_tick(tick: int) -> void:
	if _victim >= 0 and tick >= _commit_end_tick:
		_complete_commit()


## LifeState of `player` (Healthy for an id not in the roster).
func life_state(player: int) -> LifeState:
	return _life.get(player, LifeState.HEALTHY) as LifeState


## Completed takedowns on `player` this round.
func downs_taken(player: int) -> int:
	return _downs_taken.get(player, 0)


## Rule 3: a survivor in the roster who is Healthy. Story 002 extends this with grace; hidden is
## Survivor Defense's and is checked by Monster Abilities before it emits SurvivorHit.
func eligible(player: int) -> bool:
	return _life.get(player, -1) == LifeState.HEALTHY


## True while the monster is Committing.
func committing() -> bool:
	return _victim >= 0


## The seized survivor, -1 when not Committing.
func victim() -> int:
	return _victim


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
	# Only the monster's disconnect cancels; a Seized victim's commit runs on (Edge Cases).
	if c.player == _monster and c.status == EvPlayerConnectionChanged.DISCONNECTED:
		_cancel_commit()


## Rule 4.4: the victim returns to Healthy with downs_taken unchanged. Story 002 starts
## post_release_grace_s here.
func _cancel_commit() -> void:
	if not committing():
		return
	_life[_victim] = LifeState.HEALTHY
	_victim = -1


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
		var dn := EvSurvivorDowned.new()
		dn.survivor = s
		dn.bleed_out_s = _bleedout_s
		_bus.emit(dn)
