class_name MonsterAbilities extends RefCounted
## Monster Abilities: the shapeshifter's Predatory Lunge, False Signal and Blackout (Feature layer).
## Story monster-abilities/001 implements the request path and the Lunge state machine:
## design/gdd/monster-abilities.md rules 1-4 and "States and Transitions"; ADR-0002 (client sends a
## request and an aim point only, the server validates and owns cooldown and state), ADR-0005 (tick
## order slot MONSTER_ABILITIES), ADR-0006 (AbilityKnobs). Wind-up and dash movement (story 002), the hit
## test (003), miss slow (004) and the False Signal and Blackout bodies (009-010) are not here yet.
## Server only. Timers count ticks of `net.sim_tick_hz`, never wall time.
## Collaborators are injected as Callables (ADR-0005 §6 dependency injection):
##   form() -> int            BorrowedFace.TRUE_FORM or the copied survivor (TransformView.get_form);
##                            unset = true form
##   transforming() -> bool   a transformation in progress (TransformView.get_transforming); unset = never
##   locked(player) -> bool   Stunned or under the shock lock (Survivor Defense rule 14,
##                            StateKeys.SHOCK_STUN_LOCK); unset = never locked
## Usage:
##   var ma := MonsterAbilities.new()
##   ma.set_monster(1)   # BEFORE start_round
##   ma.set_status_sources(view.get_form, view.get_transforming, locked)
##   ma.set_position_source(position_of)   # story 005: AbilityUsed position
##   server.start_round({TickOrder.MONSTER_ABILITIES: ma}, knobs)
##   smp.peer_packet -> ma.request_ability(net.player_id_of(peer), bytes)

## The abilities a request can name.
enum Ability { LUNGE, FALSE_SIGNAL, BLACKOUT }
## Lunge states of "States and Transitions", in GDD order.
enum Lunge { READY, WIND_UP, ACTIVE, TAKEDOWN_COMMIT, RESOLVED, COOLDOWN }

## Explicit transition table: state -> the states it may move to.
const TRANSITIONS: Dictionary[int, Array] = {
	Lunge.READY: [Lunge.WIND_UP],
	Lunge.WIND_UP: [Lunge.ACTIVE, Lunge.RESOLVED],
	Lunge.ACTIVE: [Lunge.TAKEDOWN_COMMIT, Lunge.RESOLVED],
	Lunge.TAKEDOWN_COMMIT: [Lunge.RESOLVED],
	Lunge.RESOLVED: [Lunge.COOLDOWN],
	Lunge.COOLDOWN: [Lunge.READY],
}
## Size cap of a request packet; anything larger is not one (untrusted client bytes).
const REQUEST_CAP_BYTES := 64
## Request packet dictionary keys: only an ability id and an aim point cross the wire.
const ABILITY_KEY := "ability"
const AIM_KEY := "aim"
const REQUEST_FIELDS: Array[String] = [ABILITY_KEY, AIM_KEY]

var _monster: int = -1
var _form: Callable
var _transforming: Callable
var _locked: Callable
var _windup_ticks: int = 0
var _dash_ticks: int = 0
var _lunge_cooldown_ticks: int = 0
var _lunge: Lunge = Lunge.READY
## Tick on which the running wind-up or dash ends.
var _phase_end_tick: int = 0
## Ability -> first tick it may be accepted again (rule 3: independent per ability). 0 = ready.
var _ready_tick: Dictionary[int, int] = {}
## The first decoded request since the last tick ({} = none): one request per tick.
var _pending: Dictionary = {}
## Callable(state: Lunge, tick: int) run on every Lunge transition (telemetry, tests); unset = nothing.
var on_lunge_state: Callable
## Story 005: position_of(player) -> Vector3, the monster's server position for AbilityUsed; unset = origin.
var _position_of: Callable
var _bus: EventBus


## Injects the shapeshifter's player id. Call before RoundServer.start_round.
func set_monster(monster: int) -> void:
	_monster = monster


## Injects the position source for AbilityUsed (story 005; ServerMovement's body position).
func set_position_source(position_of: Callable) -> void:
	_position_of = position_of


## The shapeshifter's player id (-1 before set_monster).
func monster() -> int:
	return _monster


## Injects the status collaborators (see the class comment).
func set_status_sources(form: Callable, transforming: Callable, locked: Callable = Callable()) -> void:
	_form = form
	_transforming = transforming
	_locked = locked


## The bytes the shapeshifter's client sends to request `ability` at `aim` (ignored by Lunge).
static func request_packet(ability: Ability, aim: Vector3 = Vector3.ZERO) -> PackedByteArray:
	return var_to_bytes({ABILITY_KEY: ability, AIM_KEY: aim})


## The request in untrusted `bytes` as {ability, aim}, or {} when they are not one. Only checks the
## shape; whether the ability may activate is decided in server_tick.
static func decode_request(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty() or bytes.size() > REQUEST_CAP_BYTES:
		return {}
	var d: Variant = bytes_to_var(bytes)
	if not (d is Dictionary and d.size() == REQUEST_FIELDS.size() and d.get(ABILITY_KEY) is int and d.get(AIM_KEY) is Vector3):
		return {}
	var aim: Vector3 = d[AIM_KEY]
	if not Ability.values().has(d[ABILITY_KEY]) or not aim.is_finite():
		return {}
	return {ABILITY_KEY: d[ABILITY_KEY], AIM_KEY: aim}


## Server entry for a client's ability request from `player` (the sender as the network layer
## identifies it, never a field of the bytes). Ignored unless it is the shapeshifter and the bytes
## decode; only the first request of a tick is kept, and it is validated at the MONSTER_ABILITIES step.
func request_ability(player: int, bytes: PackedByteArray) -> void:
	if player != _monster or not _pending.is_empty():
		return
	_pending = decode_request(bytes)


## Injected by RoundServer. Reads knobs and puts every ability Ready with no cooldown. Subscribes to
## SurvivorHit (Active -> Takedown Commit), the commit's end (SurvivorDowned, SurvivorEliminated) and
## MonsterStunned (interrupt). Publishes the Lunge state as StateKeys.LUNGE_STATE (story 005).
func setup(_tick_runner: TickRunner, bus: EventBus, registry: StateRegistry, knobs: Knobs) -> void:
	_bus = bus
	registry.register_view(StateKeys.LUNGE_STATE, &"MonsterAbilities", LungeView.new(self))
	_windup_ticks = knobs.ticks(knobs.ability.lunge_windup_s)
	_dash_ticks = knobs.ticks(knobs.ability.lunge_dash_s)
	_lunge_cooldown_ticks = knobs.ticks(knobs.ability.lunge_cooldown_s)
	_lunge = Lunge.READY
	_pending = {}
	_ready_tick = {}
	for a: int in Ability.values():
		_ready_tick[a] = 0
	bus.subscribe(&"SurvivorHit", _on_survivor_hit)
	bus.subscribe(&"SurvivorDowned", _on_commit_end)
	bus.subscribe(&"SurvivorEliminated", _on_commit_end)
	bus.subscribe(&"MonsterStunned", _on_monster_stunned)


## MONSTER_ABILITIES slot: timed Lunge transitions due this tick, then this tick's request. A lunge
## resolving or a cooldown ending this tick frees the request on the same tick.
func server_tick(tick: int) -> void:
	if _lunge == Lunge.WIND_UP and tick >= _phase_end_tick:
		_set_lunge(Lunge.ACTIVE, tick)
		_phase_end_tick = tick + _dash_ticks
	elif _lunge == Lunge.ACTIVE and tick >= _phase_end_tick:
		_resolve(tick) ## dash end with no hit
	elif _lunge == Lunge.COOLDOWN and tick >= _ready_tick[Ability.LUNGE]:
		_set_lunge(Lunge.READY, tick)
	var req := _pending
	_pending = {}
	if req.is_empty() or not can_activate(req[ABILITY_KEY], tick):
		return ## rule 1: a rejection has no effect and costs no cooldown
	if req[ABILITY_KEY] == Ability.LUNGE:
		_set_lunge(Lunge.WIND_UP, tick)
		_phase_end_tick = tick + _windup_ticks
		_emit_used(Ability.LUNGE, req[AIM_KEY])
	# False Signal and Blackout bodies (and their cooldown start) arrive in stories 009-010.


## Rules 2 and 4: whether `ability` may activate now. Lunge needs Ready and true form; no ability while
## Stunned, shock-locked, Transforming, or in Lunge wind-up, Active or takedown commit. Cooldowns are
## per ability (rule 3).
func can_activate(ability: Ability, tick: int) -> bool:
	if tick < _ready_tick[ability] or attacking():
		return false
	if _locked.is_valid() and _locked.call(_monster):
		return false
	if _transforming.is_valid() and _transforming.call():
		return false
	if ability == Ability.LUNGE:
		return _lunge == Lunge.READY and (not _form.is_valid() or _form.call() == BorrowedFace.TRUE_FORM)
	return true


## True in Lunge wind-up, Active or takedown commit (rule 2; Borrowed Face rule 7 reads it).
func attacking() -> bool:
	return _lunge == Lunge.WIND_UP or _lunge == Lunge.ACTIVE or _lunge == Lunge.TAKEDOWN_COMMIT


## Current Lunge state.
func lunge_state() -> Lunge:
	return _lunge


## First tick `ability` may be accepted again; 0 = no cooldown has run this round.
func ready_tick(ability: Ability) -> int:
	return _ready_tick[ability]


## Resolved, then immediately Cooldown; the cooldown runs from resolution (rule 9). Story 004 adds the
## miss slow and its tests.
func _resolve(tick: int) -> void:
	_set_lunge(Lunge.RESOLVED, tick)
	_ready_tick[Ability.LUNGE] = tick + _lunge_cooldown_ticks
	_set_lunge(Lunge.COOLDOWN, tick)


func _set_lunge(state: Lunge, tick: int) -> void:
	if not TRANSITIONS[_lunge].has(state):
		push_error("MonsterAbilities: illegal Lunge transition %d -> %d" % [_lunge, state])
		return
	_lunge = state
	if on_lunge_state.is_valid():
		on_lunge_state.call(state, tick)


## Rule 8: a hit ends the dash and starts Downing's takedown commit.
func _on_survivor_hit(e: ServerEvent) -> void:
	if _lunge == Lunge.ACTIVE:
		_set_lunge(Lunge.TAKEDOWN_COMMIT, e.tick)


## Rule 9: the commit completes with SurvivorDowned or SurvivorEliminated. Inference: one shapeshifter,
## so any such event during the commit is this commit's end (neither event names the monster); an
## elimination outside a commit (bleed-out) arrives while not in Takedown Commit and is ignored.
func _on_commit_end(e: ServerEvent) -> void:
	if _lunge == Lunge.TAKEDOWN_COMMIT:
		_resolve(e.tick)


## Rule 12 and "States and Transitions": a stun in wind-up or Active interrupts the lunge, and in the
## takedown commit cancels it (Downing cancels the commit on the same event); either way it resolves.
func _on_monster_stunned(e: ServerEvent) -> void:
	if attacking() and (e as EvMonsterStunned).monster == _monster:
		_resolve(e.tick)


## Rule 3a (story 005): one AbilityUsed per accepted activation, at Lunge wind-up start. Server-internal:
## its project() is empty (ADR-0004 §5). Inference: Lunge has no aimed target, so `target` carries the
## request's aim point; the GDD's "target point or zone" for Lunge (facing-based?) would settle it.
func _emit_used(ability: Ability, target: Vector3) -> void:
	var e := EvAbilityUsed.new()
	e.ability = ability
	e.position = _position_of.call(_monster) if _position_of.is_valid() else Vector3.ZERO
	e.target = target
	_bus.emit(e)
